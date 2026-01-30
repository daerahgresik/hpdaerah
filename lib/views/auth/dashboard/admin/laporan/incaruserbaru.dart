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
  // ignore: unused_field
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

    // 2. Poll Active Rooms setiap 1 menit
    _pollingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshActiveRooms();
    });

    // 3. Listen to New Users (INSERT only)
    _usersSubscription = _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .listen(
          (List<Map<String, dynamic>> data) {
            _processUsers(data);
          },
          onError: (err) {
            _addLog("Error stream users: $err");
          },
        );

    // 4. Initial check for existing users
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
      final now = DateTime.now();

      final response = await _supabase
          .from('pengajian')
          .select()
          .eq('is_template', false)
          .or(
            'org_id.eq.$orgId,org_daerah_id.eq.$orgId,org_desa_id.eq.$orgId,org_kelompok_id.eq.$orgId',
          );

      final List<Pengajian> rooms = (response as List)
          .map((e) => Pengajian.fromJson(e))
          .where((p) {
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
    } catch (e) {
      _addLog("Error refresh rooms: $e");
    }
  }

  // Check last 50 users (Manual or Auto Poll)
  Future<void> _checkRecentUsers() async {
    _addLog("Scanning database (50 user terakhir)...");
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      await _processUsers(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _addLog("Error check recent users: $e");
    }
  }

  Future<void> _processUsers(List<Map<String, dynamic>> usersData) async {
    if (_activeRooms.isEmpty) {
      // Don't spam log if auto-polling
      return;
    }

    int matchCount = 0;

    for (var uData in usersData) {
      final uid = uData['id'];
      final uName = uData['nama'] ?? 'User';
      final String? orgDaerahId = uData['org_daerah_id'];
      final String? orgDesaId = uData['org_desa_id'];
      final String? orgKelompokId = uData['org_kelompok_id'];
      final String? gender = uData['gender'] ?? uData['jenis_kelamin']; 
      
      // Calculate Age Category dynamically
      String? ageCategory = uData['age_category'];
      if (ageCategory == null && uData['tanggal_lahir'] != null) {
        final dob = DateTime.tryParse(uData['tanggal_lahir'].toString());
        if (dob != null) {
            final now = DateTime.now();
            int age = now.year - dob.year;
            if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
                age--;
            }
            
            final status = (uData['status'] ?? '').toString().toLowerCase();
            
            if (status.contains('kawin') || status.contains('nikah') || age >= 35) {
                ageCategory = 'orangtua';
            } else if (age >= 17) {
                ageCategory = 'mudamudi remaja'; 
            } else if (age >= 13) {
                ageCategory = 'praremaja';
            } else {
                ageCategory = 'caberawit';
            }
        }
      }

      for (var room in _activeRooms) {
        final matchReason = _checkMatchReason(
          room,
          orgDaerahId,
          orgDesaId,
          orgKelompokId,
          gender,
          ageCategory,
        );

        if (matchReason == null) {
          // Null reason means MATCH!
          await _assignQR(room, uid, uName);
          matchCount++;
        }
      }
    }
    
    if (matchCount > 0) {
        _addLog("Processed ${usersData.length} users. $matchCount assigned.");
    } else {
        // Optional: Log nothing to keep clean, or "No matches found"
    }
  }

  /// Returns NULL if match, otherwise returns string reason for failure
  String? _checkMatchReason(
    Pengajian room,
    String? uDaerah,
    String? uDesa,
    String? uKelompok,
    String? uGender,
    String? uAgeCategory,
  ) {
    // 1. Cek Scope Organisasi
    if (room.orgDesaId != null && room.orgDesaId != uDesa) {
      return "Beda Desa";
    }
    if (room.orgKelompokId != null && room.orgKelompokId != uKelompok) {
      return "Beda Kelompok";
    }

    // 2. Cek Target Audience
    final target = (room.targetAudience ?? 'Semua').toLowerCase();
    if (target == 'semua') return null; // Match All

    final ageCat = (uAgeCategory ?? '').toLowerCase().replaceAll(RegExp(r'[-_]'), '');
    final gen = (uGender ?? '').toLowerCase(); 
    final tgt = target.replaceAll(RegExp(r'[-_]'), '');

    // Age Match (substring check)
    if (ageCat.contains(tgt)) return null;

    // Gender Match
    if (tgt == 'lakilaki' || tgt == 'pria') {
      if (gen.startsWith('l')) return null;
    }
    if (tgt == 'perempuan' || tgt == 'wanita') {
      if (gen.startsWith('p')) return null;
    }

    return "Target mismatch";
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

      if (existing != null) return;

      // Buat QR
      final uniqueCode = const Uuid().v4().substring(0, 8).toUpperCase();

      await _supabase.from('pengajian_qr').insert({
        'pengajian_id': room.id,
        'user_id': userId,
        'unique_code': uniqueCode,
        'is_used': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      _addLog("✅ QR OK: $userName -> ${room.title}");
    } catch (e) {
      _addLog("❌ Fail QR ($userName): $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Auto QR Scanner"),
        backgroundColor: const Color(0xFF1A5F2D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Force Scan Recent Users",
            onPressed: () {
                _checkRecentUsers();
                _refreshActiveRooms();
            },
          ),
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
                            ? "Auto-scan database & log aktif..."
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.meeting_room, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      "Target Rooms: ${_activeRooms.length}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _refreshActiveRooms, 
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text("Refresh Rooms"),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Logs List
          Expanded(
            child: _logs.isEmpty 
              ? Center(
                  child: Text(
                    "Menunggu aktivitas...", 
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isError = log.contains("Fail") || log.contains("Error") || log.contains("❌");
                    final isSuccess = log.contains("QR OK") || log.contains("✅");
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: isError ? Colors.red : (isSuccess ? Colors.green[700] : Colors.black87),
                          fontWeight: isSuccess ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
          ),
          
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[100],
            child: const Text(
               "Tips: Tekan tombol Refresh di pojok kanan atas untuk scan ulang 50 user terakhir.",
               style: TextStyle(fontSize: 10, color: Colors.grey),
               textAlign: TextAlign.center,
            ),
          )
        ],
      ),
    );
  }
}
