import 'package:flutter/material.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/pengajian_search_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/pengajian_level_selector.dart';

class PengajianDashboardPage extends StatefulWidget {
  final String orgId;

  const PengajianDashboardPage({super.key, required this.orgId});

  @override
  State<PengajianDashboardPage> createState() => _PengajianDashboardPageState();
}

class _PengajianDashboardPageState extends State<PengajianDashboardPage> {
  final _pengajianService = PengajianService();
  bool _showCreateRoom = false;
  bool _showActiveRoom = false;

  @override
  Widget build(BuildContext context) {
    if (widget.orgId.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Error Configuration:\nAkun Anda tidak terhubung dengan Organisasi.\n\n(adminOrgid is null)",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent, // Mengikuti layout admin
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manajemen Pengajian',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilih aksi yang ingin dilakukan',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // HORIZONTAL MENU ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildMenuCard(
                    context,
                    title: 'Buat Room',
                    icon: _showCreateRoom
                        ? Icons.keyboard_arrow_up
                        : Icons.add_circle_outline_rounded,
                    color: const Color(0xFF1A5F2D),
                    onTap: () {
                      setState(() {
                        _showCreateRoom = !_showCreateRoom;
                        _showActiveRoom = false;
                      });
                    },
                    isActive: _showCreateRoom,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildMenuCard(
                    context,
                    title: 'Room Aktif',
                    icon: _showActiveRoom
                        ? Icons.keyboard_arrow_up
                        : Icons.podcasts_rounded,
                    color: Colors.orange,
                    onTap: () {
                      setState(() {
                        _showActiveRoom = !_showActiveRoom;
                        _showCreateRoom = false;
                      });
                    },
                    isActive: _showActiveRoom,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildMenuCard(
                    context,
                    title: 'Cari Room',
                    icon: Icons.search_rounded,
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PengajianSearchPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // INLINE LEVEL SELECTOR (CREATE ROOM)
            if (_showCreateRoom) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    "Pilih Template / Tingkat",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _showCreateRoom = false),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    tooltip: "Tutup",
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PengajianLevelSelector(orgId: widget.orgId),
              const SizedBox(height: 48), // Bottom padding
            ],

            // INLINE ACTIVE ROOM LIST
            if (_showActiveRoom) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    "Daftar Room Aktif",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _showActiveRoom = false),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    tooltip: "Tutup",
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildActiveRoomSection(context),
              const SizedBox(height: 48),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRoomSection(BuildContext context) {
    return StreamBuilder<List<Pengajian>>(
      stream: _pengajianService.streamActivePengajian(widget.orgId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final list = snapshot.data ?? [];

        if (list.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 48,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  "Belum ada pengajian aktif",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: list.map((item) {
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1A5F2D).withOpacity(0.1),
                  child: const Icon(Icons.mosque, color: Color(0xFF1A5F2D)),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    if (item.location != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location!,
                              style: TextStyle(color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${item.startedAt.day}/${item.startedAt.month}/${item.startedAt.year} • ${item.startedAt.hour}:${item.startedAt.minute.toString().padLeft(2, '0')}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: "Hapus Room",
                  onPressed: () => _confirmDeleteRoom(context, item),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _confirmDeleteRoom(BuildContext context, Pengajian item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Room Ini?"),
        content: Text(
          "Pengajian '${item.title}' akan dihapus dan tidak bisa diakses lagi.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _pengajianService.deletePengajian(item.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Room berhasil dihapus")),
          );
          setState(() {}); // Force refresh UI/Stream
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Gagal menghapus: $e")));
        }
      }
    }
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Material(
      color: isActive ? color.withOpacity(0.1) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: isActive ? 0 : 4,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: isActive
              ? BoxDecoration(
                  border: Border.all(color: color, width: 2),
                  borderRadius: BorderRadius.circular(20),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
