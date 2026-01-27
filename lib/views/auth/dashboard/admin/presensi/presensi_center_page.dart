import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:hpdaerah/services/presensi_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresensiCenterPage extends StatefulWidget {
  final UserModel user;
  const PresensiCenterPage({super.key, required this.user});

  @override
  State<PresensiCenterPage> createState() => _PresensiCenterPageState();
}

class _PresensiCenterPageState extends State<PresensiCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: const Text(
          'Presensi Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Manual', icon: Icon(Icons.edit_note_rounded, size: 20)),
            Tab(
              text: 'Izin',
              icon: Icon(Icons.assignment_late_outlined, size: 20),
            ),
            Tab(text: 'Rekap', icon: Icon(Icons.insights_rounded, size: 20)),
          ],
        ),
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 16),
        child: TabBarView(
          controller: _tabController,
          children: [
            _ManualAttendanceTab(user: widget.user),
            _IzinRequestsTab(user: widget.user),
            _SmartRekapTab(user: widget.user),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 1: MANUAL ATTENDANCE - Only Active Rooms
// ============================================================================
class _ManualAttendanceTab extends StatefulWidget {
  final UserModel user;
  const _ManualAttendanceTab({required this.user});

  @override
  State<_ManualAttendanceTab> createState() => _ManualAttendanceTabState();
}

class _ManualAttendanceTabState extends State<_ManualAttendanceTab> {
  final _pengajianService = PengajianService();
  final _presensiService = PresensiService();
  late Stream<List<Pengajian>> _activeRoomsStream;
  String? _selectedRoomId;
  List<Map<String, dynamic>> _attendanceData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final orgId = widget.user.adminOrgId ?? '';
    _activeRoomsStream = _pengajianService.streamActivePengajian(
      widget.user,
      orgId,
    );
  }

  Future<void> _loadAttendanceForRoom(String roomId) async {
    setState(() => _isLoading = true);
    try {
      final data = await _presensiService.getDetailedAttendanceList(roomId);
      setState(() {
        _attendanceData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error loading attendance: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Active Rooms Selector
        StreamBuilder<List<Pengajian>>(
          stream: _activeRoomsStream,
          builder: (context, snapshot) {
            final rooms = snapshot.data ?? [];

            if (rooms.isEmpty) {
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 40, color: Colors.orange[300]),
                    const SizedBox(height: 8),
                    const Text(
                      "Tidak ada room aktif saat ini",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Text(
                      "Buat room pengajian terlebih dahulu",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.wifi_tethering,
                          color: Colors.green,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Room Aktif (${rooms.length})",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRoomId,
                    hint: const Text("Pilih room untuk presensi manual"),
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
                    items: rooms.map((room) {
                      final time =
                          "${room.startedAt.hour.toString().padLeft(2, '0')}:${room.startedAt.minute.toString().padLeft(2, '0')}";
                      return DropdownMenuItem(
                        value: room.id,
                        child: Text(
                          "${room.title} ($time)",
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRoomId = val);
                        _loadAttendanceForRoom(val);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),

        // Attendance List
        Expanded(
          child: _selectedRoomId == null
              ? const Center(
                  child: Text("Pilih room aktif untuk melihat daftar hadir"),
                )
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildAttendanceList(),
        ),
      ],
    );
  }

  Widget _buildAttendanceList() {
    if (_attendanceData.isEmpty) {
      return const Center(child: Text("Tidak ada data kehadiran"));
    }

    final belum = _attendanceData
        .where((u) => u['status'] == 'belum_absen')
        .toList();
    final hadir = _attendanceData.where((u) => u['status'] == 'hadir').toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (belum.isNotEmpty) ...[
          _buildSectionHeader("Belum Absen (${belum.length})", Colors.orange),
          ...belum.map((u) => _buildUserTile(u, showManualButton: true)),
        ],
        if (hadir.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader("Sudah Hadir (${hadir.length})", Colors.green),
          ...hadir.map((u) => _buildUserTile(u)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          Container(width: 4, height: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(
    Map<String, dynamic> user, {
    bool showManualButton = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[200],
          backgroundImage: user['foto_profil'] != null
              ? NetworkImage(user['foto_profil'])
              : null,
          child: user['foto_profil'] == null ? const Icon(Icons.person) : null,
        ),
        title: Text(
          user['nama'] ?? '-',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          user['kelompok_name'] ?? user['desa_name'] ?? '-',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: showManualButton
            ? ElevatedButton.icon(
                onPressed: () => _markAsHadir(user),
                icon: const Icon(Icons.check, size: 16),
                label: const Text("Hadir"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F2D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              )
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Future<void> _markAsHadir(Map<String, dynamic> user) async {
    if (_selectedRoomId == null) return;
    try {
      await _presensiService.recordManualAttendance(
        pengajianId: _selectedRoomId!,
        userId: user['user_id'],
        status: 'hadir',
      );
      _loadAttendanceForRoom(_selectedRoomId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${user['nama']} ditandai hadir")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ============================================================================
// TAB 2: IZIN REQUESTS - All permission requests grouped by room
// ============================================================================
class _IzinRequestsTab extends StatefulWidget {
  final UserModel user;
  const _IzinRequestsTab({required this.user});

  @override
  State<_IzinRequestsTab> createState() => _IzinRequestsTabState();
}

class _IzinRequestsTabState extends State<_IzinRequestsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _izinRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIzinRequests();
  }

  Future<void> _loadIzinRequests() async {
    try {
      final orgId = widget.user.adminOrgId ?? '';

      final response = await _supabase
          .from('presensi')
          .select('''
            id, status, keterangan, foto_izin, created_at,
            user:user_id(id, nama, foto_profil, org_daerah_id, org_desa_id),
            pengajian:pengajian_id(id, title, org_id, org_daerah_id)
          ''')
          .eq('status', 'izin')
          .order('created_at', ascending: false)
          .limit(50);

      final List<dynamic> data = response as List<dynamic>;

      // Filter by admin hierarchy
      final filtered = data.where((r) {
        final pengajian = r['pengajian'];
        if (pengajian == null) return false;

        if (widget.user.adminLevel == 0) return true;
        if (widget.user.adminLevel == 1) {
          return pengajian['org_daerah_id'] == orgId ||
              pengajian['org_id'] == orgId;
        }
        return pengajian['org_id'] == orgId;
      }).toList();

      setState(() {
        _izinRequests = filtered
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading izin: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_izinRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
              "Tidak ada pengajuan izin",
              style: TextStyle(fontSize: 16),
            ),
            Text(
              "Semua anggota hadir!",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Group by pengajian
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final req in _izinRequests) {
      final pengajian = req['pengajian'];
      final key = pengajian?['title'] ?? 'Unknown';
      grouped.putIfAbsent(key, () => []).add(req);
    }

    return RefreshIndicator(
      onRefresh: _loadIzinRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: grouped.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${entry.value.length} izin",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...entry.value.map((req) => _buildIzinTile(req)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIzinTile(Map<String, dynamic> req) {
    final user = req['user'];
    final nama = user?['nama'] ?? '-';
    final foto = user?['foto_profil'];
    final keterangan = req['keterangan'] ?? '-';
    final bukti = req['foto_izin'];

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: foto != null ? NetworkImage(foto) : null,
        child: foto == null ? const Icon(Icons.person) : null,
      ),
      title: Text(nama, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(keterangan, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: bukti != null
          ? IconButton(
              icon: const Icon(Icons.image, color: Colors.blue),
              onPressed: () => _showBukti(bukti),
            )
          : null,
    );
  }

  void _showBukti(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Bukti Izin",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 3: SMART REKAP - Advanced Statistics & Insights
// ============================================================================
class _SmartRekapTab extends StatefulWidget {
  final UserModel user;
  const _SmartRekapTab({required this.user});

  @override
  State<_SmartRekapTab> createState() => _SmartRekapTabState();
}

class _SmartRekapTabState extends State<_SmartRekapTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  int _totalPengajian = 0;
  int _totalHadir = 0;
  int _totalIzin = 0;
  int _totalAlpha = 0;
  List<Map<String, dynamic>> _topAttendees = [];
  List<Map<String, dynamic>> _recentPengajian = [];

  @override
  void initState() {
    super.initState();
    _loadRekapData();
  }

  Future<void> _loadRekapData() async {
    final orgId = widget.user.adminOrgId ?? '';

    try {
      // 1. Get total pengajian in hierarchy
      final pengajianResp = await _supabase
          .from('pengajian')
          .select('id, title, started_at, ended_at')
          .eq('is_template', false)
          .or('org_id.eq.$orgId,org_daerah_id.eq.$orgId,org_desa_id.eq.$orgId')
          .order('started_at', ascending: false)
          .limit(10);

      final pengajianList = pengajianResp as List;
      _totalPengajian = pengajianList.length;
      _recentPengajian = pengajianList
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // 2. Get presensi stats
      if (pengajianList.isNotEmpty) {
        final pengajianIds = pengajianList
            .map((p) => p['id'].toString())
            .toList();

        final presensiResp = await _supabase
            .from('presensi')
            .select('status, user_id')
            .filter('pengajian_id', 'in', pengajianIds);

        final presensiList = presensiResp as List;

        _totalHadir = presensiList.where((p) => p['status'] == 'hadir').length;
        _totalIzin = presensiList.where((p) => p['status'] == 'izin').length;
        _totalAlpha = presensiList
            .where((p) => p['status'] == 'tidak_hadir')
            .length;

        // 3. Get top attendees
        final attendanceCount = <String, int>{};
        for (final p in presensiList) {
          if (p['status'] == 'hadir') {
            final uid = p['user_id'].toString();
            attendanceCount[uid] = (attendanceCount[uid] ?? 0) + 1;
          }
        }

        // Get top 5 user IDs
        final sortedUsers = attendanceCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topUserIds = sortedUsers.take(5).map((e) => e.key).toList();

        if (topUserIds.isNotEmpty) {
          final usersResp = await _supabase
              .from('users')
              .select('id, nama, foto_profil')
              .filter('id', 'in', topUserIds);

          final usersList = usersResp as List;
          _topAttendees = topUserIds.map((uid) {
            final user = usersList.firstWhere(
              (u) => u['id'] == uid,
              orElse: () => {},
            );
            return {
              'nama': user['nama'] ?? 'Unknown',
              'foto': user['foto_profil'],
              'count': attendanceCount[uid] ?? 0,
            };
          }).toList();
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading rekap: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalPresensi = _totalHadir + _totalIzin + _totalAlpha;
    final attendanceRate = totalPresensi > 0
        ? (_totalHadir / totalPresensi * 100).toStringAsFixed(1)
        : '0';

    return RefreshIndicator(
      onRefresh: _loadRekapData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1A5F2D), const Color(0xFF2E7D42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tingkat Kehadiran",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "$attendanceRate%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        "dari $_totalPengajian pengajian",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Stats Row
          Row(
            children: [
              _buildQuickStat("Hadir", _totalHadir, Colors.green),
              const SizedBox(width: 8),
              _buildQuickStat("Izin", _totalIzin, Colors.orange),
              const SizedBox(width: 8),
              _buildQuickStat("Alpha", _totalAlpha, Colors.red),
            ],
          ),
          const SizedBox(height: 24),

          // Top Attendees
          if (_topAttendees.isNotEmpty) ...[
            const Text(
              "🏆 Anggota Paling Rajin",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...List.generate(_topAttendees.length, (index) {
              final user = _topAttendees[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: index == 0 ? Colors.amber : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: index == 0 ? Colors.amber : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: index == 0 ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: user['foto'] != null
                          ? NetworkImage(user['foto'])
                          : null,
                      child: user['foto'] == null
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user['nama'],
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${user['count']}x hadir",
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 24),

          // Recent Pengajian
          if (_recentPengajian.isNotEmpty) ...[
            const Text(
              "📅 Pengajian Terakhir",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._recentPengajian.take(5).map((p) {
              final date = DateTime.parse(p['started_at']).toLocal();
              final isClosed =
                  p['ended_at'] != null &&
                  DateTime.parse(p['ended_at']).isBefore(DateTime.now());

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isClosed ? Colors.grey : Colors.green,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            "${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isClosed ? Icons.check_circle : Icons.play_circle,
                      color: isClosed ? Colors.grey : Colors.green,
                      size: 20,
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              "$value",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
