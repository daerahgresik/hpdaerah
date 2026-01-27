import 'package:flutter/material.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/presensi_service.dart';

class ManualPresenceSheet extends StatefulWidget {
  final Pengajian pengajian;
  const ManualPresenceSheet({super.key, required this.pengajian});

  @override
  State<ManualPresenceSheet> createState() => _ManualPresenceSheetState();
}

class _ManualPresenceSheetState extends State<ManualPresenceSheet> {
  final _presensiService = PresensiService();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Presensi Manual",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        widget.pengajian.title,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _presensiService.streamDetailedAttendance(
                widget.pengajian.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A5F2D)),
                  );
                }

                final allData = snapshot.data ?? [];

                // Statistics for Header
                final hadir = allData
                    .where((e) => e['status'] == 'hadir')
                    .length;
                final total = allData.length;

                final filteredData = allData.where((item) {
                  final nama = item['nama'].toString().toLowerCase();
                  final username = item['username'].toString().toLowerCase();
                  return nama.contains(_searchQuery.toLowerCase()) ||
                      username.contains(_searchQuery.toLowerCase());
                }).toList();

                return Column(
                  children: [
                    // Stats Mini Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1A5F2D,
                          ).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFF1A5F2D,
                            ).withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              color: Color(0xFF1A5F2D),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Presentase Kehadiran",
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "$hadir / $total",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A5F2D),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Search Field
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: "Cari jamaah...",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    // List
                    Expanded(
                      child: filteredData.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: filteredData.length,
                              itemBuilder: (context, index) {
                                final item = filteredData[index];
                                return _buildUserTile(item);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> item) {
    final status = item['status'] as String;
    Color statusColor = Colors.grey;
    String statusLabel = "Belum Presensi";

    if (status == 'hadir') {
      statusColor = Colors.green;
      statusLabel = "Hadir";
    } else if (status == 'izin') {
      statusColor = Colors.orange;
      statusLabel = "Izin";
    } else if (status == 'tidak_hadir') {
      statusColor = Colors.red;
      statusLabel = "Alpha";
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.grey[200],
          backgroundImage: item['foto_profil'] != null
              ? NetworkImage(item['foto_profil'])
              : null,
          child: item['foto_profil'] == null
              ? const Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        title: Text(
          item['nama'] ?? '-',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          item['kelompok'] ?? item['desa'] ?? '-',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: status == 'hadir',
              onChanged: (val) {
                _updateStatus(item, val ? 'hadir' : 'tidak_hadir');
              },
              activeColor: Colors.green,
            ),
          ],
        ),
        onTap: () =>
            _updateStatus(item, status == 'hadir' ? 'tidak_hadir' : 'hadir'),
      ),
    );
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String status) async {
    try {
      await _presensiService.recordPresence(
        pengajianId: widget.pengajian.id,
        userId: item['user_id'],
        status: status,
        method: 'manual_admin',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "Tidak ditemukan",
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
