import 'package:flutter/material.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/presensi_service.dart';

class RekapPengajianPage extends StatefulWidget {
  final Pengajian pengajian;

  const RekapPengajianPage({super.key, required this.pengajian});

  @override
  State<RekapPengajianPage> createState() => _RekapPengajianPageState();
}

class _RekapPengajianPageState extends State<RekapPengajianPage> {
  final _presensiService = PresensiService();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rekap Kehadiran"),
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _presensiService.streamDetailedAttendance(widget.pengajian),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final allData = snapshot.data!;
          final filteredData = allData.where((item) {
            final nama = item['nama'].toString().toLowerCase();
            final username = item['username'].toString().toLowerCase();
            return nama.contains(_searchQuery.toLowerCase()) ||
                username.contains(_searchQuery.toLowerCase());
          }).toList();

          // Statistics
          final total = allData.length;
          final hadir = allData.where((e) => e['status'] == 'hadir').length;
          final izin = allData.where((e) => e['status'] == 'izin').length;
          final alpha = allData
              .where(
                (e) =>
                    e['status'] == 'tidak_hadir' ||
                    e['status'] == 'belum_absen',
              )
              .length;

          return Column(
            children: [
              // 1. STATS OVERVIEW
              _buildStatsHeader(hadir, izin, alpha, total),

              // 2. MATERI INFO (Jika ada)
              if (widget.pengajian.materiIsi != null ||
                  (widget.pengajian.materiGuru?.isNotEmpty ?? false))
                _buildMateriHeader(),

              // 3. SEARCH BAR
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Cari nama atau username...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // 3. LIST
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredData.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
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
    );
  }

  Widget _buildStatsHeader(int hadir, int izin, int alpha, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1A5F2D).withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Hadir", hadir, Colors.green),
          _buildStatItem("Izin", izin, Colors.orange),
          _buildStatItem("Alpha", alpha, Colors.red),
          _buildStatItem("Total", total, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildMateriHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book, color: Color(0xFF1A5F2D), size: 18),
              SizedBox(width: 8),
              Text(
                "Ringkasan Materi",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1A5F2D),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (widget.pengajian.materiGuru != null &&
              widget.pengajian.materiGuru!.isNotEmpty) ...[
            const Text(
              "Guru / Narasumber:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.pengajian.materiGuru!.join(", "),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.pengajian.materiIsi != null) ...[
            const Text(
              "Kesimpulan:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.pengajian.materiIsi!,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> item) {
    final status = item['status'] as String;
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    String statusLabel = "Belum Absen";

    if (status == 'hadir') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusLabel = "Hadir";
    } else if (status == 'izin') {
      statusColor = Colors.orange;
      statusIcon = Icons.info_outline;
      statusLabel = "Izin";
    } else if (status == 'tidak_hadir') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusLabel = "Alpha";
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        backgroundImage: item['foto_profil'] != null
            ? NetworkImage(item['foto_profil'])
            : null,
        child: item['foto_profil'] == null ? const Icon(Icons.person) : null,
      ),
      title: Text(
        item['nama'] ?? '-',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['kelompok'] ?? item['desa'] ?? '-',
            style: const TextStyle(fontSize: 12),
          ),
          if (item['recorded_at'] != null)
            Text(
              "Jam: ${_formatDateTime(item['recorded_at'])}",
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onTap: () {
        if (status == 'izin' && item['foto_izin'] != null) {
          _showIzinDetail(item);
        } else if (status != 'hadir') {
          _showManualPresenceDialog(item);
        } else {
          _showManualPresenceDialog(
            item,
          ); // Allow changing even if already present
        }
      },
    );
  }

  void _showIzinDetail(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Detail Izin: ${item['nama']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item['foto_izin'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(item['foto_izin']),
              ),
            const SizedBox(height: 12),
            Text(
              item['keterangan'] ?? "Tidak ada keterangan",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  void _showManualPresenceDialog(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Presensi Manual: ${item['nama']}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Atur status kehadiran untuk anggota ini secara manual.",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(item, 'hadir'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text("HADIR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(item, 'tidak_hadir'),
                    icon: const Icon(Icons.cancel),
                    label: const Text("ALPHA"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
                label: const Text("BATAL"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String status) async {
    Navigator.pop(context); // Close sheet
    try {
      await _presensiService.recordPresence(
        pengajianId: widget.pengajian.id,
        userId: item['user_id'],
        status: status,
        method: 'manual_admin',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Status ${item['nama']} diperbarui ke $status"),
            backgroundColor: status == 'hadir' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "-";
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Tidak ada data peserta ditemukan"),
        ],
      ),
    );
  }
}
