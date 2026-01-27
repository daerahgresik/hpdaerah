import 'package:flutter/material.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RiwayatPengajian extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const RiwayatPengajian({super.key, required this.user, required this.orgId});

  @override
  State<RiwayatPengajian> createState() => _RiwayatPengajianState();
}

class _RiwayatPengajianState extends State<RiwayatPengajian> {
  late Future<List<Pengajian>> _riwayatFuture;

  @override
  void initState() {
    super.initState();
    _riwayatFuture = _fetchRiwayat();
  }

  Future<List<Pengajian>> _fetchRiwayat() async {
    try {
      final client = Supabase.instance.client;
      // Fetch pengajian that have ENDED (ended_at is mostly not null and in the past)
      // and filter by hierarchy similar to active rooms

      // Simple logic: fetch where created_by me OR org_id in hierarchy
      // For now, let's fetch based on org_id logic

      final response = await client
          .from('pengajian')
          .select()
          .not('ended_at', 'is', null) // Must have ended
          .eq('is_template', false)
          .order('started_at', ascending: false)
          .limit(20); // Limit to recent 20 for performance

      final list = List<Map<String, dynamic>>.from(response);
      return list.map((json) => Pengajian.fromJson(json)).where((p) {
        // Filter again for extra safety on hierarchy
        // (User only sees what happened in their jurisdiction)
        final admin = widget.user;
        final myOrgId = admin.adminOrgId;

        if (admin.adminLevel == 0) return true;
        if (p.createdBy == admin.id) return true;

        if (myOrgId != null) {
          if (p.orgId == myOrgId ||
              p.orgDaerahId == myOrgId ||
              p.orgDesaId == myOrgId ||
              p.orgKelompokId == myOrgId) {
            return true;
          }
        }
        return false;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching riwayat: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Riwayat Pengajian",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() {
                _riwayatFuture = _fetchRiwayat();
              }),
              icon: const Icon(Icons.refresh, color: Colors.grey),
              tooltip: "Refresh",
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Pengajian>>(
          future: _riwayatFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final data = snapshot.data ?? [];
            if (data.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      "Belum ada riwayat pengajian",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = data[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_edu,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${_formatDate(item.startedAt)} • ${item.location ?? '-'}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Selesai",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year}";
  }
}
