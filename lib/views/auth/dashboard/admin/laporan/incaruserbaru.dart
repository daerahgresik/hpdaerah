import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/services/pengajian_service.dart';
import 'package:uuid/uuid.dart';

class IncarUserBaruPage extends StatefulWidget {
  final UserModel user;

  const IncarUserBaruPage({super.key, required this.user});

  @override
  State<IncarUserBaruPage> createState() => _IncarUserBaruPageState();
}

class _IncarUserBaruPageState extends State<IncarUserBaruPage> {
  final _supabase = Supabase.instance.client;
  final _pengajianService = PengajianService();

  bool _isMonitoring = false;
  final List<String> _logs = [];
  StreamSubscription? _usersSubscription;
  Timer? _pollingTimer;

  // Cache rooms aktif agar tidak query berulang kali
  List<Pengajian> _activeRooms = [];

  @override
  void initState() {
    super.initState();
    // Default start monitoring jika dihalaman ini
    _startMonitoring();
  }

  @override
  void dispose() {
    _stopMonitoring();
    super.dispose();
  }

  void _addLog(String log) {
    if (!mounted) return;
    setState(() {
      _logs.insert(
        0,
        "[${DateTime.now().toLocal().toString().split('.')[0]}] $log",
      );
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  void _startMonitoring() {
    if (_isMonitoring) return;
    setState(() => _isMonitoring = true);
    _addLog("Memulai monitoring user baru...");

    // 1. Initial Load Active Rooms
    _refreshActiveRooms();

    // 2. Poll Active Rooms setiap 1 menit (jika ada room baru)
    _pollingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshActiveRooms();
    });

    // 3. Listen to New Users (INSERT only)
    _usersSubscription = _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .listen(
          (List<Map<String, dynamic>> data) {
            // Stream mengembalikan snapshot list row yang berubah/ada.
            // Untuk simplifikasi, kita proses semua row yang masuk di event ini.
            // Namun stream supabase flutter defaultnya memberikan entire list atau row terpilih.
            // Agar efisien, kita anggap 'users' stream mungkin berat kalau user banyak.
            // Strategi "Incar User Baru": Kita lebih baik pake polling atau filter created_at baru?
            // Tapi request user adalah "selalu cek database".
            // Kita akan proses setiap user yang muncul di stream ini.
            // Jika Data banyak, ini bisa berat. Kita asumsikan stream di filter?
            // Sayangnya supa stream filter terbatas.

            // ALTERNATIF: Kita polling 'users' yang created_at nya baru-baru ini?
            // Atau kita tangani event ini.
            // Mari kita proses data yang masuk.
            _processUsers(data);
          },
          onError: (err) {
            _addLog("Error stream users: $err");
          },
        );

    // 4. Initial check for existing users (siapa tau ada yg terlewat saat offline)
    _checkRecentUsers();
  }

  void _stopMonitoring() {
    _usersSubscription?.cancel();
    _pollingTimer?.cancel();
    setState(() => _isMonitoring = false);
    _addLog("Monitoring berhenti.");
  }

  Future<void> _refreshActiveRooms() async {
    try {
      final orgId = widget.user.adminOrgId ?? '';
      // Gunakan stream/future active rooms dari service yg sudah ada, tapi disini kita butuh List.
      // Kita fetch manual saja "Active" logic.
      final now = DateTime.now();
      // Logic room aktif: started_at <= now <= ended_at (atau ended_at null)
      // Atau upcoming (started_at > now tapi dekat?)
      // User bilang: "target dari room yg akan aktif maupun yg sedang aktif"

      final response = await _supabase
          .from('pengajian')
          .select()
          .eq('is_template', false)
          .or(
            'org_id.eq.$orgId,org_daerah_id.eq.$orgId,org_desa_id.eq.$orgId,org_kelompok_id.eq.$orgId',
          );
      // Note: RLS should handle permission, but filter helps efficiency.

      final List<Pengajian> rooms = (response as List)
          .map((e) => Pengajian.fromJson(e))
          .where((p) {
            // Filter Time
            // "Akan aktif": misal 2 jam kedepan?
            // "Sedang aktif": started < now && (ended == null || ended > now)
            final isOngoing =
                p.startedAt.isBefore(now) &&
                (p.endedAt == null || p.endedAt!.isAfter(now));
            final isUpcoming =
                p.startedAt.isAfter(now) &&
                p.startedAt.difference(now).inHours <=
                    12; // 12 jam kedepan dianggap 'akan aktif'
            return isOngoing || isUpcoming;
          })
          .toList();

      setState(() {
        _activeRooms = rooms;
      });
      // _addLog("Refreshed Active Rooms: ${_activeRooms.length}");
    } catch (e) {
      _addLog("Error refresh rooms: $e");
    }
  }

  Future<void> _processUsers(List<Map<String, dynamic>> usersData) async {
    if (_activeRooms.isEmpty) return;

    int processedCount = 0;

    for (var uData in usersData) {
      // Convert to Model (partial)
      final uid = uData['id'];
      final String? orgDaerahId = uData['org_daerah_id'];
      final String? orgDesaId = uData['org_desa_id'];
      final String? orgKelompokId = uData['org_kelompok_id'];
      final String? gender = uData['gender']; // L / P
      final String? ageCategory =
          uData['age_category']; // caberawit, praremaja, remaja, muda_mudi, orangtua?
      // Note: check user_model fields consistency

      for (var room in _activeRooms) {
        // Cek Target Match
        if (_isTargetMatch(
          room,
          orgDaerahId,
          orgDesaId,
          orgKelompokId,
          gender,
          ageCategory,
        )) {
          // Cek apakah sudah punya QR?
          await _assignQR(room, uid, uData['nama'] ?? 'User');
          processedCount++;
        }
      }
    }
  }

  // Manual polling fallback
  Future<void> _checkRecentUsers() async {
    // Ambil user yang created_at nya 10 menit terakhir?
    // Atau ambil user yang belum punya QR di room aktif? (Lebih aman tapi berat query)
    // Kita coba ambil 20 user terakhir daftar.
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      _processUsers(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _addLog("Error check recent users: $e");
    }
  }

  bool _isTargetMatch(
    Pengajian room,
    String? uDaerah,
    String? uDesa,
    String? uKelompok,
    String? uGender,
    String? uAge,
  ) {
    // 1. Cek Scope Organisasi
    // Jika room level Desa, user harus satu desa.
    if (room.orgDesaId != null && room.orgDesaId != uDesa) return false;
    if (room.orgKelompokId != null && room.orgKelompokId != uKelompok) {
      return false;
    }
    // Jika room level Daerah, user harus satu daerah (usually yes if in same app db scope)

    // 2. Cek Target Audience (String?)
    // Format targetAudience ex: "Muda-mudi", "Praremaja", "Laki-laki", "Semua"
    final target = (room.targetAudience ?? 'Semua').toLowerCase();

    if (target == 'semua') return true;

    // Normalize user data
    final age = (uAge ?? '')
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '');
    final gen = (uGender ?? '').toLowerCase(); // L / P or Laki-laki
    final tgt = target.replaceAll('-', '').replaceAll('_', '');

    // Simple contains logic
    // ex: Target="muda mudi", User="mudamudi" -> match
    if (age.contains(tgt)) return true;

    // Gender match?
    if (tgt == 'lakilaki' || tgt == 'pria') {
      if (gen.startsWith('l')) return true;
    }
    if (tgt == 'perempuan' || tgt == 'wanita') {
      if (gen.startsWith('p')) return true;
    }

    return false;
  }

  Future<void> _assignQR(Pengajian room, String userId, String userName) async {
    try {
      // Cek Existensi (Double check)
      final existing = await _supabase
          .from('pengajian_qr')
          .select('id')
          .eq('pengajian_id', room.id)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Sudah ada, skip
        return;
      }

      // Buat QR
      final uniqueCode = const Uuid().v4().substring(0, 8).toUpperCase();

      await _supabase.from('pengajian_qr').insert({
        'pengajian_id': room.id,
        'user_id': userId,
        'unique_code': uniqueCode,
        'is_used': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      _addLog("QR Generated: $userName -> ${room.title}");
    } catch (e) {
      _addLog("Failed assign QR ($userName): $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple UI
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Auto QR Scanner"),
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
        actions: [
          Switch(
            value: _isMonitoring,
            onChanged: (val) {
              if (val) {
                _startMonitoring();
              } else {
                _stopMonitoring();
              }
            },
            activeColor: Colors.greenAccent,
            activeTrackColor: Colors.green[700],
            inactiveThumbColor: Colors.red,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Box
          Container(
            padding: const EdgeInsets.all(16),
            color: _isMonitoring ? Colors.green[50] : Colors.red[50],
            child: Row(
              children: [
                Icon(
                  _isMonitoring ? Icons.radar : Icons.radar_outlined,
                  color: _isMonitoring ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isMonitoring ? "SYSTEM ACTIVE" : "SYSTEM PAUSED",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isMonitoring
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
                      ),
                      Text(
                        _isMonitoring
                            ? "Memonitor database untuk user baru..."
                            : "Monitoring dimatikan.",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_isMonitoring)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Active Rooms Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.meeting_room, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  "Target Rooms: ${_activeRooms.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(),

          // Logs List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
