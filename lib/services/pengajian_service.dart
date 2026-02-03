import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/models/user_model.dart';

import 'package:hpdaerah/services/pengajian_qr_service.dart';

class PengajianService {
  final SupabaseClient _client = Supabase.instance.client;
  final _qrService = PengajianQrService();

  /// Check if there's an overlapping room at the same org level
  Future<Map<String, dynamic>?> checkOverlappingRoom({
    required String orgId,
    required DateTime startedAt,
    required DateTime endedAt,
    String? targetAudience,
  }) async {
    try {
      // Convert input times to UTC for safe DB comparison
      final startedAtUtc = startedAt.toUtc();
      final endedAtUtc = endedAt.toUtc();
      final nowUtc = DateTime.now().toUtc();

      // Query hierarchical overlap: find ANY room that involves this orgId
      // to prevent double booking at any level in the same hierarchy.
      final response = await _client
          .from('pengajian')
          .select('id, title, started_at, ended_at, target_audience')
          .eq('is_template', false)
          .or(
            'org_id.eq.$orgId,org_daerah_id.eq.$orgId,org_desa_id.eq.$orgId,org_kelompok_id.eq.$orgId',
          );

      final List<dynamic> rooms = response as List<dynamic>;

      for (final room in rooms) {
        final roomStartedAtStr = room['started_at'] as String?;
        if (roomStartedAtStr == null) continue;

        // Supabase returns UTC strings, ensure we treat them as such
        final roomStartedAt = DateTime.parse(roomStartedAtStr).toUtc();

        // Duration fallback: 4 hours if ended_at is null (safety margin)
        final roomEndedAt = room['ended_at'] != null
            ? DateTime.parse(room['ended_at']).toUtc()
            : roomStartedAt.add(const Duration(hours: 4));

        // Skip if room ended more than 1 minute ago (ignore grace periods for overlap)
        if (roomEndedAt.isBefore(nowUtc.subtract(const Duration(minutes: 1)))) {
          continue;
        }

        // Overlap Logic (UTC vs UTC):
        final bool overlaps =
            startedAtUtc.isBefore(roomEndedAt) &&
            endedAtUtc.isAfter(roomStartedAt);

        if (overlaps) {
          final existingTarget = room['target_audience']?.toString() ?? 'Semua';
          final newTarget = targetAudience ?? 'Semua';

          if (existingTarget == newTarget) {
            final localEndedAt = roomEndedAt.toLocal();
            String waitMessage =
                "hingga ${localEndedAt.hour.toString().padLeft(2, '0')}:${localEndedAt.minute.toString().padLeft(2, '0')}";
            return {
              'title': room['title'] ?? 'Room Lain',
              'ended_at': localEndedAt,
              'wait_message': waitMessage,
            };
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error checking overlap: $e");
      return null;
    }
  }

  /// Check if a room code is currently in use by an active room
  Future<bool> _isRoomCodeActive(String roomCode) async {
    try {
      final response = await _client
          .from('pengajian')
          .select('id')
          .eq('room_code', roomCode)
          .eq('is_template', false)
          .isFilter('ended_at', null)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint("Error checking room code: $e");
      return false;
    }
  }

  /// Generate a unique 6-digit room code
  Future<String> _generateUniqueRoomCode() async {
    const maxAttempts = 10;
    for (int i = 0; i < maxAttempts; i++) {
      final code = List.generate(6, (_) => Random().nextInt(10)).join();
      final isActive = await _isRoomCodeActive(code);
      if (!isActive) {
        return code;
      }
      debugPrint(
        "Room code $code already in use, retrying... (${i + 1}/$maxAttempts)",
      );
    }
    // Fallback: use timestamp-based code if all attempts fail
    final timestamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    return timestamp.toString().padLeft(6, '0');
  }

  Future<void> createPengajian(Pengajian pengajian) async {
    try {
      // 0. Strict Overlap Check
      // Walaupun endedAt null (default durasi), kita tetap validasi
      final validationEndedAt =
          pengajian.endedAt ??
          pengajian.startedAt.add(const Duration(hours: 3));

      final overlap = await checkOverlappingRoom(
        orgId: pengajian.orgId,
        startedAt: pengajian.startedAt,
        endedAt: validationEndedAt,
        targetAudience: pengajian.targetAudience,
      );

      if (overlap != null) {
        throw Exception(
          "Kamu tidak bisa membuat room karena ada room aktif: '${overlap['title']}'.\n"
          "Silakan tunggu hingga room tersebut selesai (${overlap['wait_message']}) atau pilih target peserta yang berbeda.",
        );
      }

      // 1. Generate UNIQUE Room Code if empty
      String roomCode = pengajian.roomCode ?? '';
      if (roomCode.isEmpty) {
        roomCode = await _generateUniqueRoomCode();
      } else {
        // Validate provided room code is not already in use
        final isCodeActive = await _isRoomCodeActive(roomCode);
        if (isCodeActive) {
          throw Exception(
            "Kode room '$roomCode' sudah digunakan oleh room lain yang masih aktif. "
            "Silakan gunakan kode lain atau biarkan sistem generate otomatis.",
          );
        }
      }

      final data = {
        'org_id': pengajian.orgId,
        'title': pengajian.title,
        'location': pengajian.location,
        'description': pengajian.description,
        'target_audience': pengajian.targetAudience,
        'room_code': roomCode,
        'started_at': pengajian.startedAt.toUtc().toIso8601String(),
        'ended_at': pengajian.endedAt?.toUtc().toIso8601String(),
        'created_by': _client.auth.currentUser?.id,
        'is_template': false,
        'org_daerah_id': pengajian.orgDaerahId,
        'org_desa_id': pengajian.orgDesaId,
        'org_kelompok_id': pengajian.orgKelompokId,
        'materi_guru': pengajian.materiGuru,
        'materi_isi': pengajian.materiIsi,
      };

      if (pengajian.id.isNotEmpty) {
        data['id'] = pengajian.id;
      }

      final response = await _client
          .from('pengajian')
          .insert(data)
          .select()
          .single();

      final newPengajianId = response['id'] as String;
      debugPrint("Created Room with Code: $roomCode");

      // 2. Determine target organization based on level
      // If room level is Daerah (0), use orgDaerahId, etc.
      // This ensures "tingkat daerah maka targetnya di sesuaikan" requirement is met.
      String effectiveTargetOrgId = pengajian.orgId;
      if (pengajian.level == 0 && pengajian.orgDaerahId != null) {
        effectiveTargetOrgId = pengajian.orgDaerahId!;
      } else if (pengajian.level == 1 && pengajian.orgDesaId != null) {
        effectiveTargetOrgId = pengajian.orgDesaId!;
      } else if (pengajian.level == 2 && pengajian.orgKelompokId != null) {
        effectiveTargetOrgId = pengajian.orgKelompokId!;
      }

      final creatorId = _client.auth.currentUser?.id;

      await _qrService.generateQrForTargetUsers(
        pengajianId: newPengajianId,
        targetOrgId: effectiveTargetOrgId,
        targetAudience: pengajian.targetAudience,
        creatorId: creatorId,
      );
    } catch (e) {
      debugPrint("Error Create Pengajian: $e");
      rethrow;
    }
  }

  Future<void> updatePengajian(Pengajian pengajian) async {
    try {
      if (pengajian.id.isEmpty) {
        throw Exception("Pengajian ID is required for update");
      }

      final data = {
        'title': pengajian.title,
        'location': pengajian.location,
        'description': pengajian.description,
        'target_audience': pengajian.targetAudience,
        'target_kriteria_id': pengajian.targetKriteriaId,
        'room_code': pengajian.roomCode,
        'started_at': pengajian.startedAt.toUtc().toIso8601String(),
        'ended_at': pengajian.endedAt?.toUtc().toIso8601String(),
        'materi_guru': pengajian.materiGuru,
        'materi_isi': pengajian.materiIsi,
      };

      await _client.from('pengajian').update(data).eq('id', pengajian.id);
      debugPrint("Success Update Pengajian: ${pengajian.id}");
    } catch (e) {
      debugPrint("Error Update Pengajian: $e");
      rethrow;
    }
  }

  Future<Pengajian?> findPengajianByCode(String code) async {
    try {
      final response = await _client
          .from('pengajian')
          .select()
          .eq('room_code', code)
          .maybeSingle();

      if (response == null) return null;

      // Handle type safety for Web
      final data = Map<String, dynamic>.from(response as Map);
      final pengajian = Pengajian.fromJson(data);

      // Check if room is active
      // 1. Must not be a template
      if (pengajian.isTemplate) return null;

      // 2. Must not be ended in the past
      if (pengajian.endedAt != null) {
        if (pengajian.endedAt!.isBefore(DateTime.now())) {
          return null;
        }
      }

      return pengajian;
    } catch (e) {
      debugPrint("Error findPengajianByCode: $e");
      return null;
    }
  }

  Future<void> joinPengajian({
    required String pengajianId,
    required String targetOrgId,
    String? targetAudience,
  }) async {
    try {
      final creatorId = _client.auth.currentUser?.id;
      // Create QR records for members of this new joining org
      await _qrService.generateQrForTargetUsers(
        pengajianId: pengajianId,
        targetOrgId: targetOrgId,
        targetAudience: targetAudience,
        creatorId: creatorId,
      );
    } catch (e) {
      rethrow;
    }
  }

  // CREATE TEMPLATE
  Future<void> createTemplate(Pengajian template) async {
    try {
      if (template.orgId.isEmpty) {
        throw Exception("Org ID is empty");
      }
      final data = {
        'org_id': template.orgId,
        'title': template.title, // Judul Default
        'description': template.description, // Deskripsi Default
        'location': template.location, // Lokasi Default
        'target_audience': template.targetAudience, // FIX: Save Target Audience
        'is_template': true,
        'template_name': template.templateName,
        'level': template.level, // 0, 1, 2
        'created_by': _client.auth.currentUser?.id,
        'started_at': DateTime.now()
            .toIso8601String(), // Dummy date required by NOT NULL? Check schema.
        // schema: started_at default now(). OK.
      };

      await _client.from('pengajian').insert(data);
      debugPrint("Success Create Template: ${template.templateName}");
    } catch (e) {
      debugPrint("Error Create Template: $e");
      rethrow;
    }
  }

  // UPDATE TEMPLATE
  Future<void> updateTemplate(Pengajian template) async {
    try {
      if (template.id.isEmpty) {
        throw Exception("Template ID is required for update");
      }

      final data = {
        'title': template.title,
        'description': template.description,
        'location': template.location,
        'target_audience': template.targetAudience,
        'template_name': template.templateName,
      };

      await _client.from('pengajian').update(data).eq('id', template.id);
      debugPrint("Success Update Template: ${template.templateName}");
    } catch (e) {
      debugPrint("Error Update Template: $e");
      rethrow;
    }
  }

  // CLOSE ROOM (Tutup Pengajian - Selesai)
  // Tidak menghapus data, tapi menandai selesai & absen Alpha
  Future<void> closePengajian(String id) async {
    try {
      // 1. Ambil semua user yang belum presensi/izin di pengajian ini
      final unusedQRs = await _client
          .from('pengajian_qr')
          .select('user_id')
          .eq('pengajian_id', id)
          .eq('is_used', false);

      final List<dynamic> usersToMark = unusedQRs;

      // 2. Insert record 'tidak_hadir' ke tabel presensi untuk mereka
      if (usersToMark.isNotEmpty) {
        final absenceRecords = usersToMark
            .map(
              (q) => {
                'pengajian_id': id,
                'user_id': q['user_id'],
                'status': 'tidak_hadir',
                'method': 'auto',
              },
            )
            .toList();

        await _client.from('presensi').upsert(absenceRecords);

        // 3. Tandai semua QR as used agar hilang dari tab 'Aktif' user
        await _client
            .from('pengajian_qr')
            .update({'is_used': true})
            .eq('pengajian_id', id)
            .eq('is_used', false);
      }

      // 4. Update pengajian set ended_at to NOW
      await _client
          .from('pengajian')
          .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);

      debugPrint('Pengajian $id closed (Finished)');
    } catch (e) {
      debugPrint("Error close pengajian: $e");
      rethrow;
    }
  }

  // HARD DELETE (Hapus Permanen)
  Future<void> deletePengajian(String id) async {
    try {
      // HARD DELETE PROPER
      // 1. Hapus data presensi terkait
      await _client.from('presensi').delete().eq('pengajian_id', id);

      // 2. Hapus data QR terkait
      await _client.from('pengajian_qr').delete().eq('pengajian_id', id);

      // 3. Hapus Room Pengajian
      await _client.from('pengajian').delete().eq('id', id);

      debugPrint("Success Hard Delete Pengajian: $id");
    } catch (e) {
      debugPrint("Error Hard Delete: $e");
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      // Templates should be hard-deleted to keep the database and UI clean
      await _client.from('pengajian').delete().eq('id', id);
      debugPrint("Success Delete Template: $id");
    } catch (e) {
      debugPrint("Error Delete Template: $e");
      rethrow;
    }
  }

  // GET TEMPLATES
  Stream<List<Pengajian>> streamTemplates(String orgId) {
    return _client.from('pengajian').stream(primaryKey: ['id']).map((data) {
      // Explicit cast for Web/JS interop safety
      final typedData = (data as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final templates = typedData
          .where(
            (json) =>
                json['org_id'] == orgId &&
                json['is_template'] == true &&
                json['ended_at'] == null,
          )
          .map((json) => Pengajian.fromJson(json))
          .toList();

      // Sort client-side
      templates.sort(
        (a, b) => (a.templateName ?? '').compareTo(b.templateName ?? ''),
      );

      return templates;
    });
  }

  // Fetch Active Pengajian
  // Criteria:
  // 1. Same Territory (Hierarchy Aware)
  // 2. Not a template
  // 3. Status Active: ended_at is NULL
  Stream<List<Pengajian>> streamActivePengajian(
    UserModel admin,
    String selectedOrgId,
  ) {
    // Determine the most specific filter we can apply at the DB level
    // to avoid the 50-room limit cutting off our own rooms.
    var query = _client
        .from('pengajian')
        .stream(primaryKey: ['id'])
        .eq('is_template', false);

    return query.order('started_at', ascending: false).limit(100).map((data) {
      try {
        final list = List.from(data as Iterable);
        final currentUserId = _client.auth.currentUser?.id;

        // Diagnostic log
        debugPrint(
          "Stream Sync: Received ${list.length} rooms from DB. AdminPos: ${admin.adminLevelName}, TargetOrg: $selectedOrgId, MyID: $currentUserId",
        );

        final typedData = list
            .map((e) {
              try {
                return Map<String, dynamic>.from(e as Map);
              } catch (e) {
                return null;
              }
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        final filtered = typedData
            .where((json) {
              final createdBy = json['created_by'];

              // 1. Status Check
              final endedAtStr = json['ended_at'] as String?;
              final startedAtStr = json['started_at'] as String?;
              if (startedAtStr == null) return false;

              DateTime now = DateTime.now();

              // Rule: Show if it hasn't ended yet (+ 15 mins grace period)
              bool hasEnded = false;
              if (endedAtStr != null) {
                try {
                  final endedAt = DateTime.parse(endedAtStr).toLocal();
                  // Extend life for 15 minutes after actual end time
                  if (endedAt.add(const Duration(minutes: 15)).isBefore(now)) {
                    hasEnded = true;
                  }
                } catch (_) {}
              }

              // Also show finished rooms if they started TODAY (for recap convenience)
              bool isToday = false;
              try {
                final startedAt = DateTime.parse(startedAtStr).toLocal();
                isToday =
                    startedAt.year == now.year &&
                    startedAt.month == now.month &&
                    startedAt.day == now.day;
              } catch (_) {}

              // KEEP in list if:
              // A. It hasn't ended yet (Scheduled or Running)
              // B. OR It ended today (Convenience for admin)
              if (hasEnded && !isToday) return false;

              // 2. Hierarchical & Permission Visibility
              final jsonOrgId = json['org_id'];
              final jsonDaerahId = json['org_daerah_id'];
              final jsonDesaId = json['org_desa_id'];
              final jsonKelompokId = json['org_kelompok_id'];

              // Rule A: Super Admin (Internal level 0)
              if (admin.adminLevel == 0) return true;

              // Rule B: Creator always sees their own
              if (currentUserId != null && createdBy == currentUserId) {
                return true;
              }

              // Rule C: Territory Match (Current User's Territory)
              final myOrgId = admin.adminOrgId;
              if (myOrgId != null) {
                if (admin.adminLevel == 1 &&
                    (jsonOrgId == myOrgId || jsonDaerahId == myOrgId)) {
                  return true;
                }
                if (admin.adminLevel == 2 &&
                    (jsonOrgId == myOrgId || jsonDesaId == myOrgId)) {
                  return true;
                }
                if (admin.adminLevel == 3 &&
                    (jsonOrgId == myOrgId || jsonKelompokId == myOrgId)) {
                  return true;
                }
              }

              // Rule D: Filter by Selected Org (For Super Admin or specific context)
              if (selectedOrgId.isNotEmpty) {
                if (jsonOrgId == selectedOrgId ||
                    jsonDaerahId == selectedOrgId ||
                    jsonDesaId == selectedOrgId ||
                    jsonKelompokId == selectedOrgId) {
                  return true;
                }
              }

              return false;
            })
            .map((json) {
              try {
                return Pengajian.fromJson(json);
              } catch (e) {
                return null;
              }
            })
            .whereType<Pengajian>()
            .toList();

        // Sort: Active ones first, then by date
        filtered.sort((a, b) {
          if (a.endedAt == null && b.endedAt != null) return -1;
          if (a.endedAt != null && b.endedAt == null) return 1;
          return b.startedAt.compareTo(a.startedAt); // Newest first
        });

        debugPrint(
          "Stream Sync: Final filtered list has ${filtered.length} rooms",
        );
        return filtered;
      } catch (e) {
        debugPrint("Critical error in streamActivePengajian mapper: $e");
        return <Pengajian>[];
      }
    });
  }
}
