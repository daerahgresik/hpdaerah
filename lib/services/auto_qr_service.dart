import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:uuid/uuid.dart';

class AutoQrService {
  // Singleton Pattern
  static final AutoQrService instance = AutoQrService._();
  AutoQrService._();

  final _supabase = Supabase.instance.client;

  // State
  bool _isActive = false;
  bool get isActive => _isActive;

  // Logs (Observable)
  final ValueNotifier<List<String>> logsNotifier = ValueNotifier([]);

  Timer? _engineTimer;
  RealtimeChannel? _usersChannel;
  RealtimeChannel? _roomsChannel;
  List<Pengajian> _cachedActiveRooms = [];

  void _log(String message) {
    final newLogs = List<String>.from(logsNotifier.value);
    newLogs.add(
      "> [${DateTime.now().toLocal().toString().split('.')[0]}] $message",
    );
    if (newLogs.length > 200) newLogs.removeAt(0); // Batasi 200 log biar ringan
    logsNotifier.value = newLogs;
  }

  // --- PUBLIC CONTROLS ---

  void start() {
    if (_isActive) return;
    _isActive = true;
    _log("🟢 SERVICE STARTED: Background Auto QR v3.2");
    _runEngineCycle(); // Run immediately

    // Loop every 15 seconds (sedikit diperlambat biar aman di background)
    _engineTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _runEngineCycle();
    });

    _setupRealtimeListeners();
  }

  void stop() {
    _isActive = false;
    _engineTimer?.cancel();
    _usersChannel?.unsubscribe();
    _roomsChannel?.unsubscribe();
    _log("🔴 SERVICE STOPPED");
  }

  void toggle() {
    if (_isActive) {
      stop();
    } else {
      start();
    }
  }

  // --- INTERNAL LOGIC (SAMA PERSIS DENGAN V3.2) ---

  void _setupRealtimeListeners() {
    // Listen Only, trigger engine cycle
    _usersChannel = _supabase.channel('bg_users');
    _usersChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            if (_isActive) {
              _log("⚡ BG EVENT: New User.");
              _runEngineCycle();
            }
          },
        )
        .subscribe();

    _roomsChannel = _supabase.channel('bg_rooms');
    _roomsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pengajian',
          callback: (payload) {
            if (_isActive) {
              _updateActiveRoomsCache();
            }
          },
        )
        .subscribe();
  }

  Future<void> _runEngineCycle() async {
    if (!_isActive) return;

    await _updateActiveRoomsCache();

    if (_cachedActiveRooms.isEmpty) {
      // _log("⚠️ IDLE: No rooms."); // Reduce spam
      return;
    }

    _log("🔄 BG CYCLE: Checking ${_cachedActiveRooms.length} rooms...");

    for (var room in _cachedActiveRooms) {
      if (!_isActive) break;
      await _processRoom(room);
    }
  }

  Future<void> _updateActiveRoomsCache() async {
    try {
      final response = await _supabase
          .from('pengajian')
          .select()
          .eq('is_template', false);

      final allRooms = (response as List)
          .map((e) => Pengajian.fromJson(e))
          .toList();
      final now = DateTime.now();

      _cachedActiveRooms = allRooms.where((p) {
        final isEnded = p.endedAt != null && p.endedAt!.isBefore(now);
        final isTooFar = p.startedAt.difference(now).inDays > 7;
        return !isEnded && !isTooFar;
      }).toList();
    } catch (e) {
      _log("❌ ERROR Fetch Rooms: $e");
    }
  }

  Future<void> _processRoom(Pengajian room) async {
    try {
      if (room.orgDaerahId == null &&
          room.orgDesaId == null &&
          room.orgKelompokId == null) {
        return;
      }

      // 1. CEK PRESENSI (Blacklist)
      final presensiResponse = await _supabase
          .from('presensi')
          .select('user_id')
          .eq('pengajian_id', room.id)
          .or('status.eq.hadir,status.eq.izin');

      final Set<String> completedUserIds = (presensiResponse as List)
          .map((e) => e['user_id'].toString())
          .toSet();

      // 2. CEK QR EXISTING
      final qrResponse = await _supabase
          .from('pengajian_qr')
          .select('user_id, qr_code')
          .eq('pengajian_id', room.id);

      final Map<String, String> existingQrMap = {
        for (var e in (qrResponse as List))
          e['user_id'].toString(): e['qr_code'].toString(),
      };

      dynamic baseQuery = _supabase.from('users').select();

      int actionCount = 0;
      int pageSize = 50;
      bool keepScanning = true;
      int offset = 0;

      while (keepScanning && _isActive) {
        final response = await baseQuery
            .order('created_at', ascending: false)
            .range(offset, offset + pageSize - 1);

        final List<dynamic> batch = response as List<dynamic>;

        if (batch.isEmpty) {
          keepScanning = false;
          break;
        }

        for (var u in batch) {
          final uid = u['id'].toString();
          final uName = u['nama'] ?? 'No Name';

          if (completedUserIds.contains(uid)) continue; // SKIP SUDAH HADIR

          if (existingQrMap.containsKey(uid)) {
            final currentCode = existingQrMap[uid]!;
            if (currentCode.startsWith('PGJ-')) continue; // SKIP SUDAH VALID
          }

          // SCOPE CHECK
          bool scopeMatch = false;
          if (room.orgKelompokId != null) {
            if (u['org_kelompok_id'] == room.orgKelompokId) scopeMatch = true;
          } else if (room.orgDesaId != null) {
            if (u['org_desa_id'] == room.orgDesaId) scopeMatch = true;
          } else if (room.orgDaerahId != null) {
            if (u['org_daerah_id'] == room.orgDaerahId) scopeMatch = true;
          }

          if (!scopeMatch) continue;

          // TARGET CHECK
          final ageCat = _calculateAgeCategory(u);
          final gender = u['gender'] ?? u['jenis_kelamin'] ?? '';
          final mismatch = _checkTargetMismatch(room, gender, ageCat);

          if (mismatch != null) continue;

          // ACTION
          if (existingQrMap.containsKey(uid)) {
            await _repairQR(room, uid, uName);
            actionCount++;
          } else {
            await _assignQR(room, uid, uName);
            actionCount++;
          }
        }

        if (actionCount > 0) {
          keepScanning = false;
          _log("✅ ACTION: $actionCount processed for ${room.title}");
        } else {
          offset += pageSize;
          if (offset >= 300) keepScanning = false;
        }
      }
    } catch (e) {
      _log("❌ ERROR Processing: $e");
    }
  }

  // --- HELPERS (Same as V3.2) ---

  String? _calculateAgeCategory(Map<String, dynamic> uData) {
    if (uData['tanggal_lahir'] != null) {
      final dateStr = uData['tanggal_lahir'].toString();
      DateTime? dob = DateTime.tryParse(dateStr);
      if (dob == null && dateStr.contains('/')) {
        try {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            final d = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final y = int.parse(parts[2]);
            dob = DateTime(y, m, d);
          }
        } catch (e) {
          // Silently ignore parse errors
        }
      }

      if (dob != null) {
        final now = DateTime.now();
        int age = now.year - dob.year;
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          age--;
        }

        if (age >= 40) return 'orangtua';
        if (age >= 17) return 'mudamudi';
        if (age >= 13) return 'praremaja';
        return 'caberawit';
      }
    }
    if (uData['age_category'] != null) return uData['age_category'];
    return 'generik';
  }

  String? _checkTargetMismatch(
    Pengajian room,
    String uGender,
    String? uAgeCategory,
  ) {
    final target = (room.targetAudience ?? 'Semua').toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final userAge = (uAgeCategory ?? '').toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final gen = uGender.toLowerCase().trim();

    if (target == 'semua' || target == 'umum') return null;

    if (target.contains('pria') || target.contains('laki')) {
      bool isMale = gen.contains('pria') || gen.contains('laki');
      if (!isMale) return "Mismatch";
    } else if (target.contains('wanita') ||
        target.contains('perempuan') ||
        target.contains('ibu')) {
      bool isFemale = gen.contains('wanita') || gen.contains('perempuan');
      if (!isFemale) return "Mismatch";
    }

    if (userAge == 'generik') return null;
    if (!userAge.contains(target) && !target.contains(userAge)) {
      return "Mismatch";
    }
    return null;
  }

  Future<void> _assignQR(Pengajian room, String userId, String userName) async {
    try {
      final rawUuid = const Uuid().v4();
      final uniqueCode =
          "PGJ-${rawUuid.substring(0, 8)}-${rawUuid.substring(9, 13)}"
              .toUpperCase();

      await _supabase.from('pengajian_qr').insert({
        'pengajian_id': room.id,
        'user_id': userId,
        'qr_code': uniqueCode,
        'is_used': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      _log("   + Assigned QR to $userName ($uniqueCode)");
    } catch (e) {
      // _log("   ! Error: $e");
    }
  }

  Future<void> _repairQR(Pengajian room, String userId, String userName) async {
    try {
      final rawUuid = const Uuid().v4();
      final uniqueCode =
          "PGJ-${rawUuid.substring(0, 8)}-${rawUuid.substring(9, 13)}"
              .toUpperCase();

      await _supabase
          .from('pengajian_qr')
          .update({'qr_code': uniqueCode})
          .match({'pengajian_id': room.id, 'user_id': userId});
      _log("   🛠️ Repaired QR for $userName ($uniqueCode)");
    } catch (e) {
      // Silently ignore repair errors
    }
  }
}
