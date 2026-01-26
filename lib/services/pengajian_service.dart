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
  }) async {
    try {
      // Find any active room at the same org that overlaps with the requested time
      final response = await _client
          .from('pengajian')
          .select('id, title, started_at, ended_at')
          .eq('org_id', orgId)
          .eq('is_template', false);

      final List<dynamic> rooms = response as List<dynamic>;

      for (final room in rooms) {
        final roomEndedAtStr = room['ended_at'] as String?;
        final roomStartedAtStr = room['started_at'] as String?;

        if (roomEndedAtStr == null || roomStartedAtStr == null) continue;

        final roomEndedAt = DateTime.parse(roomEndedAtStr);
        final roomStartedAt = DateTime.parse(roomStartedAtStr);

        // Skip rooms that have already ended (in the past)
        if (roomEndedAt.isBefore(DateTime.now())) continue;

        // Check for overlap:
        // New room overlaps if: newStart < existingEnd AND newEnd > existingStart
        final bool overlaps =
            startedAt.isBefore(roomEndedAt) && endedAt.isAfter(roomStartedAt);

        if (overlaps) {
          // Calculate wait time
          final waitDuration = roomEndedAt.difference(DateTime.now());
          final waitMinutes = waitDuration.inMinutes;
          final waitHours = waitDuration.inHours;

          String waitMessage;
          if (waitHours > 0) {
            final remainingMinutes = waitMinutes % 60;
            waitMessage =
                "$waitHours jam ${remainingMinutes > 0 ? '$remainingMinutes menit' : ''}";
          } else {
            waitMessage = "$waitMinutes menit";
          }

          return {
            'title': room['title'] ?? 'Room',
            'ended_at': roomEndedAt,
            'wait_message': waitMessage,
          };
        }
      }

      return null; // No overlap found
    } catch (e) {
      debugPrint("Error checking overlap: $e");
      return null;
    }
  }

  Future<void> createPengajian(Pengajian pengajian) async {
    try {
      // 0. Check for overlapping rooms at the same org level
      if (pengajian.endedAt != null) {
        final overlap = await checkOverlappingRoom(
          orgId: pengajian.orgId,
          startedAt: pengajian.startedAt,
          endedAt: pengajian.endedAt!,
        );

        if (overlap != null) {
          throw Exception(
            "Room '${overlap['title']}' sudah ada di waktu yang sama. "
            "Silakan tunggu ${overlap['wait_message']} lagi untuk membuat room baru.",
          );
        }
      }

      // 1. Generate Room Code if empty
      String roomCode = pengajian.roomCode ?? '';
      if (roomCode.isEmpty) {
        roomCode = List.generate(6, (_) => Random().nextInt(10)).join();
      }

      final data = {
        'org_id': pengajian.orgId,
        'title': pengajian.title,
        'location': pengajian.location,
        'description': pengajian.description,
        'target_audience': pengajian.targetAudience,
        'room_code': roomCode,
        'started_at': pengajian.startedAt.toIso8601String(),
        'ended_at': pengajian.endedAt?.toIso8601String(),
        'created_by': _client.auth.currentUser?.id,
        'is_template': false,
        'org_daerah_id': pengajian.orgDaerahId,
        'org_desa_id': pengajian.orgDesaId,
        'org_kelompok_id': pengajian.orgKelompokId,
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

      // 2. Initial targeting for the creator's org
      await _qrService.generateQrForTargetUsers(
        pengajianId: newPengajianId,
        targetOrgId: pengajian.orgId,
        targetAudience: pengajian.targetAudience,
      );
    } catch (e) {
      debugPrint("Error Create Pengajian: $e");
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
      // Create QR records for members of this new joining org
      await _qrService.generateQrForTargetUsers(
        pengajianId: pengajianId,
        targetOrgId: targetOrgId,
        targetAudience: targetAudience,
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

  Future<void> deletePengajian(String id) async {
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

        await _client.from('presensi').insert(absenceRecords);

        // 3. Tandai semua QR as used agar hilang dari tab 'Aktif' user
        await _client
            .from('pengajian_qr')
            .update({'is_used': true})
            .eq('pengajian_id', id)
            .eq('is_used', false);
      }

      // 4. Update pengajian set ended_at to a fixed past date
      // This ensures it definitely disappears from 'Active Room' lists
      // regardless of client timezones or small clock drifts.
      await _client
          .from('pengajian')
          .update({'ended_at': DateTime.utc(1970).toIso8601String()})
          .eq('id', id);

      debugPrint(
        'Pengajian $id closed and missing participants marked as Alpha',
      );
    } catch (e) {
      debugPrint("Error delete pengajian: $e");
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
    return _client
        .from('pengajian')
        .stream(primaryKey: ['id'])
        .order('started_at')
        .map((data) {
          final list = List.from(data as Iterable);
          final typedData = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          final currentUserId = _client.auth.currentUser?.id;

          return typedData
              .where((json) {
                // 1. Template Check
                if (json['is_template'] == true) return false;

                // 2. End Status Check
                final endedAtStr = json['ended_at'] as String?;
                if (endedAtStr != null) {
                  try {
                    final endedAt = DateTime.parse(endedAtStr).toUtc();
                    final nowUtc = DateTime.now().toUtc();
                    // If room has an end date, hide it if that date has passed
                    if (endedAt.isBefore(nowUtc)) {
                      return false;
                    }
                  } catch (_) {
                    return false;
                  }
                }

                // 3. Hierarchical Visibility Logic
                final jsonOrgId = json['org_id'];
                final createdBy = json['created_by'];
                final jsonDaerahId = json['org_daerah_id'];
                final jsonDesaId = json['org_desa_id'];
                final jsonKelompokId = json['org_kelompok_id'];

                // Rule A: Super Admin sees everything
                if (admin.adminLevel == 0) {
                  return true;
                }

                // Rule B: Territory Match (The Core Fix for Admin Daerah)
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

                // Rule C: Selected Org View
                if (selectedOrgId.isNotEmpty) {
                  if (jsonOrgId == selectedOrgId ||
                      jsonDaerahId == selectedOrgId ||
                      jsonDesaId == selectedOrgId ||
                      jsonKelompokId == selectedOrgId) {
                    return true;
                  }
                }

                // Rule D: Creator always sees their own
                if (currentUserId != null && createdBy == currentUserId) {
                  return true;
                }

                return false;
              })
              .map((json) => Pengajian.fromJson(json))
              .toList();
        });
  }
}
