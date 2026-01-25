import 'package:flutter/material.dart';
import 'package:hpdaerah/models/presensi_model.dart';
import 'package:hpdaerah/services/presensi_service.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DaftarHadirPage extends StatefulWidget {
  const DaftarHadirPage({super.key});

  @override
  State<DaftarHadirPage> createState() => _DaftarHadirPageState();
}

class _DaftarHadirPageState extends State<DaftarHadirPage> {
  final _presensiService = PresensiService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pengajianList = [];
  String? _selectedPengajianId;

  @override
  void initState() {
    super.initState();
    _fetchPengajianList();
  }

  Future<void> _fetchPengajianList() async {
    try {
      // Ambil pengajian yang aktif atau baru selesai (misal 30 hari terakhir)
      final response = await _supabase
          .from('pengajian')
          .select('id, title, started_at')
          .order('started_at', ascending: false)
          .limit(20);

      setState(() {
        _pengajianList = List<Map<String, dynamic>>.from(response);
        if (_pengajianList.isNotEmpty) {
          _selectedPengajianId = _pengajianList.first['id'];
        }
      });
    } catch (e) {
      debugPrint("Error fetching pengajian list: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // FILTER PENGAJIAN
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pilih Pengajian:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (_pengajianList.isEmpty)
                const Text("Belum ada data pengajian.")
              else
                DropdownButtonFormField<String>(
                  value: _selectedPengajianId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: _pengajianList.map((p) {
                    final date = DateTime.parse(p['started_at']).toLocal();
                    final dateStr =
                        "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                    return DropdownMenuItem<String>(
                      value: p['id'],
                      child: Text(
                        "${p['title']} ($dateStr)",
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedPengajianId = val;
                    });
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // DAFTAR PESERTA
        Expanded(
          child: _selectedPengajianId == null
              ? const Center(child: Text("Pilih pengajian terlebih dahulu"))
              : StreamBuilder<List<Presensi>>(
                  stream: _presensiService.streamAttendanceList(
                    _selectedPengajianId!,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }

                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Belum ada peserta hadir",
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }

                    // Kita perlu fetch data user detail untuk setiap presensi
                    // Agar bisa menampilkan Nama & Status
                    // Idealnya di PresensiService stream sudah join, tapi untuk cepat kita fetch user detail here or use FutureBuilder inside item
                    // Atau lebih baik Modify Presensi Model & Query to include user metadata.
                    // For now, let's assume we fetch user data individually or modify query.
                    // To keep it simple and reactive: Let's create a UserTile widget that fetches user info.

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final presensi = list[index];
                        return _PresensiUserTile(presensi: presensi);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PresensiUserTile extends StatelessWidget {
  final Presensi presensi;

  const _PresensiUserTile({required this.presensi});

  Future<UserModel?> _fetchUser() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', presensi.userId)
          .maybeSingle();
      if (response != null) return UserModel.fromJson(response);
    } catch (e) {
      debugPrint("Error fetch user: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _fetchUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
              backgroundImage: user?.fotoProfil != null
                  ? NetworkImage(user!.fotoProfil!)
                  : null,
              child: user?.fotoProfil == null
                  ? const Icon(Icons.person, color: Color(0xFF1A5F2D))
                  : null,
            ),
            title: isLoading
                ? Container(height: 14, width: 100, color: Colors.grey[200])
                : Text(
                    user?.nama ?? "User Tidak Dikenal",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isLoading)
                  Text(
                    "${user?.statusWarga ?? '-'} • ${user?.asal ?? '-'}",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      (presensi.method == 'qr')
                          ? Icons.qr_code
                          : Icons.edit_note,
                      size: 12,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Absen via ${(presensi.method ?? '-').toUpperCase()} • ${presensi.createdAt?.hour ?? '00'}:${(presensi.createdAt?.minute ?? 0).toString().padLeft(2, '0')}",
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: const Text(
                "HADIR",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
