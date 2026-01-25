import 'package:flutter/material.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:hpdaerah/services/presensi_service.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/pengajian_search_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/pengajian_level_selector.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/pengajian_detail_page.dart';
import 'package:permission_handler/permission_handler.dart';

class PengajianDashboardPage extends StatefulWidget {
  final UserModel user;
  final String orgId;

  const PengajianDashboardPage({
    super.key,
    required this.user,
    required this.orgId,
  });

  @override
  State<PengajianDashboardPage> createState() => _PengajianDashboardPageState();
}

class _PengajianDashboardPageState extends State<PengajianDashboardPage> {
  final _pengajianService = PengajianService();
  final _presensiService = PresensiService();
  bool _showCreateRoom = false;
  bool _showActiveRoom = false;

  String? _selectedOrgId;
  List<Map<String, dynamic>> _daerahList = [];
  bool _isFetchingDaerah = false;

  @override
  void initState() {
    super.initState();
    // Initialize _selectedOrgId. If it's a Super Admin and orgId is empty,
    // keep it null to avoid Dropdown assertion errors.
    if (widget.user.adminLevel == 0 && widget.orgId.isEmpty) {
      _selectedOrgId = null;
      _fetchDaerahList();
    } else {
      _selectedOrgId = widget.orgId;
    }
  }

  Future<void> _fetchDaerahList() async {
    setState(() => _isFetchingDaerah = true);
    try {
      final response = await Supabase.instance.client
          .from('organizations')
          .select()
          .eq('level', 0)
          .order('name');

      setState(() {
        _daerahList = List<Map<String, dynamic>>.from(response);
        // Automatically select the first daerah if none is selected
        if (_daerahList.isNotEmpty &&
            (_selectedOrgId == null || _selectedOrgId!.isEmpty)) {
          _selectedOrgId = _daerahList.first['id'];
        }
        _isFetchingDaerah = false;
      });
    } catch (e) {
      debugPrint("Error Fetching Daerah: $e");
      if (mounted) setState(() => _isFetchingDaerah = false);
    }
  }

  void _openScanner(Pengajian pengajian) async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerPage(
            pengajian: pengajian,
            onResult: (username) async {
              await _handleScanResult(pengajian, username);
            },
          ),
        ),
      );
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Izin kamera ditolak permanen. Buka pengaturan?",
            ),
            action: SnackBarAction(
              label: "Buka",
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        _showStatusSnackBar(
          "Izin kamera diperlukan untuk scan.",
          isError: true,
        );
      }
    }
  }

  Future<void> _handleScanResult(Pengajian pengajian, String username) async {
    try {
      final user = await _presensiService.findUserByUsername(username);
      if (user == null) {
        if (mounted) {
          _showStatusSnackBar("User tidak ditemukan: $username", isError: true);
        }
        return;
      }

      await _presensiService.recordPresence(
        pengajianId: pengajian.id,
        userId: user.id!,
        method: 'qr',
      );

      if (mounted) _showStatusSnackBar("Berhasil: ${user.nama} telah hadir");
    } catch (e) {
      if (mounted) _showStatusSnackBar("Gagal: $e", isError: true);
    }
  }

  void _showStatusSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show error if NOT super admin AND orgId is empty
    if (widget.user.adminLevel != 0 && widget.orgId.isEmpty) {
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

            // SUPER ADMIN DROPDOWN
            if (widget.user.adminLevel == 0) ...[
              _buildDaerahSelector(),
              const SizedBox(height: 20),
            ],

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
              PengajianLevelSelector(
                orgId: _selectedOrgId ?? widget.orgId,
                adminLevel: widget.user.adminLevel ?? 0,
              ),
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
      stream: _pengajianService.streamActivePengajian(
        _selectedOrgId ?? widget.orgId,
      ),
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
                  backgroundColor: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 14,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Target: ${item.targetAudience ?? 'Semua'}",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ATTENDANCE COUNT BADGE
                    FutureBuilder<Map<String, int>>(
                      future: _presensiService.getAttendanceSummary(
                        item.id,
                        item.orgId,
                      ),
                      builder: (context, snapshot) {
                        final stats = snapshot.data ?? {'hadir': 0, 'izin': 0};
                        final totalCheckin =
                            (stats['hadir'] ?? 0) + (stats['izin'] ?? 0);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A5F2D).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF1A5F2D).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_pin_circle_outlined,
                                size: 16,
                                color: Color(0xFF1A5F2D),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$totalCheckin Orang Hadir/Izin",
                                style: const TextStyle(
                                  color: Color(0xFF1A5F2D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tombol Scan
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFF1A5F2D),
                      ),
                      tooltip: "Scan Kehadiran",
                      onPressed: () => _openScanner(item),
                    ),
                    // Tombol Hapus
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: "Hapus Room",
                      onPressed: () => _confirmDeleteRoom(context, item),
                    ),
                  ],
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
      color: isActive ? color.withValues(alpha: 0.1) : Colors.white,
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
                  color: isActive ? Colors.white : color.withValues(alpha: 0.1),
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

  Widget _buildDaerahSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A5F2D).withValues(alpha: 0.2)),
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
          Row(
            children: const [
              Icon(
                Icons.location_city_rounded,
                color: Color(0xFF1A5F2D),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "Pilih Daerah Pengelolaan",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isFetchingDaerah)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String>(
              value: (_selectedOrgId != null && _selectedOrgId!.isNotEmpty)
                  ? _selectedOrgId
                  : null,
              isExpanded: true,
              hint: const Text("Pilih Daerah"),
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
              items: _daerahList.map((d) {
                return DropdownMenuItem<String>(
                  value: d['id'],
                  child: Text(d['name'] ?? 'Unknown Daerah'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedOrgId = val;
                });
              },
            ),
          const SizedBox(height: 4),
          const Text(
            "* Super Admin dapat mengelola pengajian di setiap daerah",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
