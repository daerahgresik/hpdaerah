import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:hpdaerah/services/presensi_service.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/pengajian_level_selector.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/pengajian_detail_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/riwayatpengajian.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/khataman/khataman_page.dart';
import 'package:hpdaerah/views/auth/dashboard/admin/pengajian/manual_presence_sheet.dart';

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
  bool _showHistoryRoom = false; // New Menu State
  bool _showKhataman = false;
  bool _showSearchRoom = false; // Still needed for logic inside Active Room

  // For Search Room logic
  final _searchCodeCtrl = TextEditingController();
  Pengajian? _foundPengajian;
  bool _isSearching = false;

  late Stream<List<Pengajian>> _activeRoomStream;
  String? _lastStreamOrgId;

  final FocusNode _searchFocus = FocusNode();

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
    _updateActiveStream();
  }

  void _updateActiveStream() {
    final targetOrgId = _selectedOrgId ?? widget.orgId;
    if (_lastStreamOrgId == targetOrgId) return;

    _lastStreamOrgId = targetOrgId;
    _activeRoomStream = _pengajianService.streamActivePengajian(
      widget.user,
      targetOrgId,
    );
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

      if (!mounted) return;

      // VERIFIKASI IDENTITAS
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Verifikasi Identitas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
                backgroundImage: user.fotoProfil != null
                    ? NetworkImage(user.fotoProfil!)
                    : null,
                child: user.fotoProfil == null
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                user.nama,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              _buildDetailInfo('Kelompok', user.orgKelompokName),
              _buildDetailInfo('Desa', user.orgDesaName),
              _buildDetailInfo('Daerah', user.orgDaerahName),
              const SizedBox(height: 20),
              const Text(
                'Apakah data di atas sesuai dengan orang di depan Anda?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'TOLAK (Bukan Dia)',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5F2D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Hadir'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _presensiService.recordPresence(
          pengajianId: pengajian.id,
          userId: user.id!,
          method: 'qr',
          status: 'hadir',
        );
        if (mounted) _showStatusSnackBar("Berhasil: ${user.nama} telah hadir");
      } else if (confirmed == false) {
        // Mark as Rejected / Tidak Hadir
        await _presensiService.recordPresence(
          pengajianId: pengajian.id,
          userId: user.id!,
          method: 'qr',
          status: 'tidak_hadir', // Dinyatakan tidak hadir karena penolakan
        );
        if (mounted) {
          _showStatusSnackBar(
            "Identitas ditolak. Status: Tidak Hadir.",
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) _showStatusSnackBar("Gagal: $e", isError: true);
    }
  }

  Widget _buildDetailInfo(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value ?? '-', style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
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

            // HORIZONTAL MENU ROW (4 Items)
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
                        final newState = !_showCreateRoom;
                        _showCreateRoom = newState;
                        if (newState) {
                          _showActiveRoom = false;
                          _showHistoryRoom = false;
                          _showSearchRoom = false;
                        }
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
                        final newState = !_showActiveRoom;
                        _showActiveRoom = newState;
                        if (newState) {
                          _showCreateRoom = false;
                          _showHistoryRoom = false;
                          _showSearchRoom = false;
                        }
                      });
                    },
                    isActive: _showActiveRoom,
                  ),
                ),
                const SizedBox(width: 4),
                // RIWAYAT MENU
                Expanded(
                  child: _buildMenuCard(
                    context,
                    title: 'Riwayat',
                    icon: _showHistoryRoom
                        ? Icons.keyboard_arrow_up
                        : Icons.history_edu,
                    color: Colors.purple,
                    onTap: () {
                      setState(() {
                        final newState = !_showHistoryRoom;
                        _showHistoryRoom = newState;
                        if (newState) {
                          _showCreateRoom = false;
                          _showActiveRoom = false;
                          _showSearchRoom = false;
                        }
                      });
                    },
                    isActive: _showHistoryRoom,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildMenuCard(
                    context,
                    title: 'Khataman',
                    icon: _showKhataman
                        ? Icons.keyboard_arrow_up
                        : Icons.auto_stories_rounded,
                    color: Colors.amber.shade700,
                    onTap: () {
                      setState(() {
                        final newState = !_showKhataman;
                        _showKhataman = newState;
                        if (newState) {
                          _showCreateRoom = false;
                          _showActiveRoom = false;
                          _showHistoryRoom = false;
                          _showSearchRoom = false;
                        }
                      });
                    },
                    isActive: _showKhataman,
                  ),
                ),
              ],
            ),

            // INLINE LEVEL SELECTOR (CREATE ROOM)
            if (_showCreateRoom) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: const Text(
                      "Pilih Template / Tingkat",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                user: widget.user,
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

            // INLINE HISTORY ROOM (NEW)
            if (_showHistoryRoom) ...[
              const SizedBox(height: 24),
              RiwayatPengajian(
                user: widget.user,
                orgId: _selectedOrgId ?? widget.orgId,
              ),
            ],

            if (_showKhataman) ...[
              const SizedBox(height: 24),
              const KhatamanPage(),
            ],

            // DEFAULT: Show Insight Dashboard when no menu is selected
            if (!_showCreateRoom &&
                !_showActiveRoom &&
                !_showSearchRoom &&
                !_showHistoryRoom &&
                !_showKhataman) ...[
              const SizedBox(height: 24),
              _buildInsightDashboard(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightDashboard(BuildContext context) {
    final orgId = _selectedOrgId ?? widget.orgId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Color(0xFF1A5F2D),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Insight Pengajian",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  "Statistik wilayah yang Anda kelola",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Stats Cards
        StreamBuilder<List<Pengajian>>(
          stream: _activeRoomStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Error memuat data: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }
            final activeRooms = snapshot.data ?? [];
            final activeCount = activeRooms.length;

            return Column(
              children: [
                // Row 1: Active & Total Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.wifi_tethering,
                        label: "Room Aktif",
                        value: "$activeCount",
                        color: Colors.green,
                        subtitle: "Sedang berjalan",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<int>(
                        future: _getTotalPengajianCount(orgId),
                        builder: (context, snap) {
                          return _buildStatCard(
                            icon: Icons.history,
                            label: "Total Pengajian",
                            value: "${snap.data ?? 0}",
                            color: Colors.blue,
                            subtitle: "Sepanjang waktu",
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2: Attendance Stats
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<Map<String, int>>(
                        future: _getOverallAttendanceStats(orgId),
                        builder: (context, snap) {
                          final hadir = snap.data?['hadir'] ?? 0;
                          final izin = snap.data?['izin'] ?? 0;
                          final alpha = snap.data?['alpha'] ?? 0;
                          final total = hadir + izin;
                          return _buildStatCard(
                            icon: Icons.how_to_reg,
                            label: "Total Kehadiran",
                            value: "$total",
                            color: Colors.teal,
                            subtitle: "$hadir hadir, $izin izin, $alpha alpha",
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<int>(
                        future: _getTemplateCount(orgId),
                        builder: (context, snap) {
                          return _buildStatCard(
                            icon: Icons.flash_on,
                            label: "Menu Cepat",
                            value: "${snap.data ?? 0}",
                            color: Colors.amber.shade700,
                            subtitle: "Template tersedia",
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 3: Total Users in Hierarchy
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<int>(
                        future: _getTotalUsersInHierarchy(orgId),
                        builder: (context, snap) {
                          return _buildStatCard(
                            icon: Icons.people_alt_rounded,
                            label: "Total Anggota",
                            value: "${snap.data ?? 0}",
                            color: Colors.deepPurple,
                            subtitle: "Di wilayah Anda",
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: SizedBox(),
                    ), // Placeholder for balance
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // Recent Activity Section
        const Text(
          "Aktivitas Terkini",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildRecentActivityList(),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList() {
    return StreamBuilder<List<Pengajian>>(
      stream: _activeRoomStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rooms = snapshot.data ?? [];
        if (rooms.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text(
                  "Belum ada pengajian aktif",
                  style: TextStyle(color: Colors.grey[500]),
                ),
                const SizedBox(height: 4),
                Text(
                  "Klik 'Buat Room' untuk memulai",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Column(
          children: rooms.take(3).map((room) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${room.startedAt.hour.toString().padLeft(2, '0')}:${room.startedAt.minute.toString().padLeft(2, '0')} • ${room.location ?? 'Lokasi belum diset'}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (room.roomCode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        room.roomCode!,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<int> _getTotalPengajianCount(String orgId) async {
    try {
      final client = Supabase.instance.client;
      // Query pengajian where any of the hierarchy columns match this org
      // This covers: orgId is the direct org, OR it's the daerah, OR it's the desa
      final response = await client
          .from('pengajian')
          .select('id')
          .eq('is_template', false)
          .or(
            'org_id.eq.$orgId,org_daerah_id.eq.$orgId,org_desa_id.eq.$orgId,org_kelompok_id.eq.$orgId',
          );
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, int>> _getOverallAttendanceStats(String orgId) async {
    try {
      final client = Supabase.instance.client;

      // First get all pengajian IDs that belong to this hierarchy
      final pengajianResponse = await client
          .from('pengajian')
          .select('id')
          .eq('is_template', false)
          .or(
            'org_id.eq.$orgId,org_daerah_id.eq.$orgId,org_desa_id.eq.$orgId,org_kelompok_id.eq.$orgId',
          );

      final pengajianIds = (pengajianResponse as List)
          .map((p) => p['id'].toString())
          .toList();

      if (pengajianIds.isEmpty) return {'hadir': 0, 'izin': 0, 'alpha': 0};

      // Then get presensi for those pengajian
      final presensiResponse = await client
          .from('presensi')
          .select('status')
          .filter('pengajian_id', 'in', pengajianIds);

      final data = presensiResponse as List;
      int hadir = 0;
      int izin = 0;
      int alpha = 0;
      for (final r in data) {
        if (r['status'] == 'hadir') hadir++;
        if (r['status'] == 'izin') izin++;
        if (r['status'] == 'tidak_hadir') alpha++;
      }
      return {'hadir': hadir, 'izin': izin, 'alpha': alpha};
    } catch (e) {
      debugPrint('Error getting attendance stats: $e');
      return {'hadir': 0, 'izin': 0, 'alpha': 0};
    }
  }

  Future<int> _getTemplateCount(String orgId) async {
    try {
      final client = Supabase.instance.client;
      // Templates can be at any level in the hierarchy
      final response = await client
          .from('pengajian')
          .select('id')
          .eq('is_template', true)
          .or(
            'org_id.eq.$orgId,org_daerah_id.eq.$orgId,org_desa_id.eq.$orgId,org_kelompok_id.eq.$orgId',
          );
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTotalUsersInHierarchy(String orgId) async {
    try {
      final client = Supabase.instance.client;
      // Get all users where any of their org hierarchy columns match
      final response = await client
          .from('users')
          .select('id')
          .or(
            'org_daerah_id.eq.$orgId,org_desa_id.eq.$orgId,org_kelompok_id.eq.$orgId',
          );
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildActiveRoomSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Room yang sedang berjalan",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showSearchRoom = !_showSearchRoom;
                  if (_showSearchRoom) {
                    _showActiveRoom = true;
                    _showKhataman = false;
                    _showHistoryRoom = false;
                    _showCreateRoom = false;
                    _searchFocus.requestFocus();
                  }
                });
              },
              icon: Icon(
                _showSearchRoom ? Icons.close : Icons.search,
                size: 16,
              ),
              label: Text(
                _showSearchRoom ? "Tutup" : "Cari Room Bersama",
                style: const TextStyle(fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                foregroundColor: Colors.blue,
                elevation: 0,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),

        // SEARCH UI (Toggled from above)
        if (_showSearchRoom) ...[
          const SizedBox(height: 16),
          _buildSearchRoomSection(context),
          const SizedBox(height: 12),
        ],

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(),
        ),

        StreamBuilder<List<Pengajian>>(
          stream: _activeRoomStream,
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                      // Leading Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A5F2D).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mosque,
                          color: Color(0xFF1A5F2D),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Builder(
                                        builder: (context) {
                                          final now = DateTime.now();
                                          final start = item.startedAt
                                              .toLocal();
                                          final end = item.endedAt?.toLocal();

                                          String label;
                                          Color color;

                                          if (end != null && now.isAfter(end)) {
                                            label = "SELESAI";
                                            color = Colors.grey;
                                          } else if (now.isBefore(start)) {
                                            final diff = start.difference(now);
                                            final prefix = diff.inHours > 0
                                                ? "${diff.inHours} JAM"
                                                : "${diff.inMinutes + 1} MENIT";
                                            label =
                                                "AKAN DATANG ($prefix LAGI)";
                                            color = Colors.orange;
                                          } else {
                                            final diff = end != null
                                                ? end.difference(now).inMinutes
                                                : 0;
                                            label =
                                                "SEDANG BERLANGSUNG${diff > 0 ? ' • SISA ${diff}m' : ''}";
                                            color = const Color(0xFF1A5F2D);
                                          }

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: color.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.roomCode != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      item.roomCode!,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                  "${item.startedAt.hour.toString().padLeft(2, '0')}:${item.startedAt.minute.toString().padLeft(2, '0')} - ${item.endedAt != null ? "${item.endedAt!.hour.toString().padLeft(2, '0')}:${item.endedAt!.minute.toString().padLeft(2, '0')}" : 'Selesai'}",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (item.location != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item.location!,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Stats & Action
                            Row(
                              children: [
                                FutureBuilder<Map<String, int>>(
                                  future: _presensiService.getAttendanceSummary(
                                    item.id,
                                    item.orgId,
                                  ),
                                  builder: (context, snapshot) {
                                    final total =
                                        (snapshot.data?['hadir'] ?? 0) +
                                        (snapshot.data?['izin'] ?? 0);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF1A5F2D,
                                        ).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "$total Masuk",
                                        style: const TextStyle(
                                          color: Color(0xFF1A5F2D),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const Spacer(),
                                if (item.roomCode != null)
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: item.roomCode!),
                                      );
                                      _showStatusSnackBar("Kode Room disalin!");
                                    },
                                    child: const Text(
                                      "Salin Kode",
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Trailing Buttons
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // People / Manual Attendance
                          IconButton(
                            icon: const Icon(
                              Icons.people_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) =>
                                    ManualPresenceSheet(pengajian: item),
                              );
                            },
                            tooltip: "Presensi Manual",
                            visualDensity: VisualDensity.compact,
                          ),
                          // Scanner
                          IconButton(
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              color: Color(0xFF1A5F2D),
                              size: 20,
                            ),
                            onPressed: () => _openScanner(item),
                            tooltip: "Scan QR",
                            visualDensity: VisualDensity.compact,
                          ),
                          // Finish (Selesai)
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.orange,
                              size: 20,
                            ),
                            onPressed: () => _confirmCloseRoom(context, item),
                            tooltip: "Selesaikan Pengajian",
                            visualDensity: VisualDensity.compact,
                          ),
                          // Delete (Hapus)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _confirmDeleteRoom(context, item),
                            tooltip: "Hapus Permanen",
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // CLOSE (Selesai Normal)
  Future<void> _confirmCloseRoom(BuildContext context, Pengajian item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Selesaikan Pengajian?"),
        content: Text(
          "Pengajian '${item.title}' akan ditandai SELESAI.\n"
          "Anggota yang belum absen akan otomatis dicatat sebagai TIDAK HADIR (Alpha).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Selesaikan"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _pengajianService.closePengajian(item.id);
        if (context.mounted) {
          _showStatusSnackBar("Room '${item.title}' telah selesai");
          _updateActiveStream(); // Refresh UI
        }
      } catch (e) {
        if (context.mounted) _showStatusSnackBar("Gagal: $e", isError: true);
      }
    }
  }

  // DELETE (Hapus Permanen - Fix Duplikat)
  Future<void> _confirmDeleteRoom(BuildContext context, Pengajian item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Room Permanen?"),
        content: Text(
          "PERINGATAN: Room '${item.title}' akan DIHAPUS PERMANEN beserta seluruh data presensinya.\n\n"
          "Gunakan ini jika Anda salah membuat room atau ingin menghapus room duplikat.",
          style: const TextStyle(color: Colors.red),
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
            child: const Text("HAPUS SEKARANG"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _pengajianService.deletePengajian(item.id);
        if (context.mounted) {
          _showStatusSnackBar("Room berhasil dihapus permanen");
          _updateActiveStream(); // Refresh UI
        }
      } catch (e) {
        if (context.mounted)
          _showStatusSnackBar("Gagal menghapus: $e", isError: true);
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
        border: Border.all(
          color: const Color(0xFF1A5F2D).withValues(alpha: 0.2),
        ),
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
              initialValue:
                  (_selectedOrgId != null && _selectedOrgId!.isNotEmpty)
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

  Future<void> _searchRoom() async {
    final code = _searchCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundPengajian = null;
    });

    try {
      final res = await _pengajianService.findPengajianByCode(code);
      setState(() {
        _foundPengajian = res;
        _isSearching = false;
      });
      if (res == null) {
        _showStatusSnackBar(
          "Room tidak ditemukan atau sudah ditutup",
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      _showStatusSnackBar("Error: $e", isError: true);
    }
  }

  Future<void> _joinTargetedRoom() async {
    if (_foundPengajian == null) return;
    final orgId = _selectedOrgId ?? widget.orgId;
    if (orgId.isEmpty) {
      _showStatusSnackBar("Pilih organisasi terlebih dahulu", isError: true);
      return;
    }

    // Show confirmation dialog with target audience selector
    final options = ['Semua', 'Muda - mudi', 'Praremaja', 'Caberawit'];
    String selectedTarget = _foundPengajian!.targetAudience ?? 'Semua';
    if (!options.contains(selectedTarget)) selectedTarget = 'Semua';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Konfirmasi Gabung Room"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Anda akan mendaftarkan anggota dari:",
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                Text(
                  widget.user.orgKelompokName ??
                      widget.user.orgDesaName ??
                      widget.user.orgDaerahName ??
                      "Organisasi Anda",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Ke dalam room pengajian bersama:",
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _foundPengajian!.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_foundPengajian!.location != null)
                        Text("📍 ${_foundPengajian!.location}"),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Bawa Anggota Tingkat / Kategori:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedTarget,
                  items: options
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (val) =>
                      setStateDialog(() => selectedTarget = val ?? 'Semua'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "* QR Code akan dikirim ke anggota baru yang belum terdaftar di room ini.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Batal"),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.group_add, size: 18),
                label: const Text("Konfirmasi & Daftarkan"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F2D),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    try {
      await _pengajianService.joinPengajian(
        pengajianId: _foundPengajian!.id,
        targetOrgId: orgId,
        targetAudience: selectedTarget,
      );
      _showStatusSnackBar(
        "Berhasil! Anggota baru Anda sekarang terdaftar di room ini.",
      );
      setState(() {
        _showSearchRoom = false;
        _foundPengajian = null;
        _searchCodeCtrl.clear();
      });
    } catch (e) {
      _showStatusSnackBar("Gagal bergabung: $e", isError: true);
    }
  }

  Widget _buildSearchRoomSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              const Text(
                "Cari & Join Pengajian Bersama",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Masukkan kode room dari penyelenggara untuk membawa anggota Anda mendaftar ke sana.",
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          const Text(
            "Kode Room",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCodeCtrl,
                  focusNode: _searchFocus,
                  textCapitalization: TextCapitalization.characters,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Masukkan Kode 6 Digit",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                    filled: true,
                    fillColor: Colors.grey[50],
                    isDense: true,
                  ),
                  onSubmitted: (_) => _searchRoom(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSearching ? null : _searchRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Cari"),
              ),
            ],
          ),
          if (_foundPengajian != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _foundPengajian!.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "📍 ${_foundPengajian!.location ?? '-'}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _joinTargetedRoom,
                      icon: const Icon(Icons.group_add_rounded),
                      label: const Text("GABUNG (Targetkan Anggota Saya)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "* Klik tombol di atas untuk mendaftarkan seluruh anggota di lingkup organisasi Anda ke pengajian ini.",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
