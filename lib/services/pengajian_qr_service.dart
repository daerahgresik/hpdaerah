import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/pengajian_qr_model.dart';
import 'package:hpdaerah/models/target_kriteria_model.dart';

/// Service untuk mengelola QR Code Pengajian
/// - Generate QR untuk semua user target saat pengajian dibuat
/// - Validate QR saat scan
/// - Mark QR as used setelah presensi
class PengajianQrService {
  final SupabaseClient _client = Supabase.instance.client;
  final Random _random = Random.secure();

  /// Generate unique QR code string
  String _generateUniqueQrCode(String pengajianId, String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = List.generate(
      8,
      (_) => _random.nextInt(36).toRadixString(36),
    ).join();
    // Format: PGJ-[pengajianIdPrefix]-[userIdPrefix]-[timestamp]-[random]
    final pengajianPrefix = pengajianId.substring(0, 8);
    final userPrefix = userId.substring(0, 8);
    return 'PGJ-$pengajianPrefix-$userPrefix-$timestamp-$randomPart'
        .toUpperCase();
  }

  /// Generate QR codes untuk semua user dalam organisasi target
  /// Dipanggil saat admin membuat pengajian baru
  Future<int> generateQrForTargetUsers({
    required String pengajianId,
    required String targetOrgId,
    String? targetAudience,
    String? targetKriteriaId,
    String? creatorId, // New: always include creator
  }) async {
    try {
      // 1. Ambil semua user yang terdaftar di organisasi target
      final targetUsers = await _getTargetUsers(
        targetOrgId,
        targetAudience: targetAudience,
        targetKriteriaId: targetKriteriaId,
      );

      // 2. Prepare final list of target user IDs
      final List<String> finalTargetUserIds = targetUsers
          .map((e) => e.toString())
          .toList();

      // ALWAYS ensure the room creator (the admin) gets a QR code
      if (creatorId != null && !finalTargetUserIds.contains(creatorId)) {
        finalTargetUserIds.add(creatorId);
      }

      if (finalTargetUserIds.isEmpty) {
        debugPrint('No target users found for QR generation.');
        return 0;
      }

      // 3. Filter out users who already have a QR code for this pengajian
      final existingResponse = await _client
          .from('pengajian_qr')
          .select('user_id')
          .eq('pengajian_id', pengajianId);

      final List<dynamic> existingData = existingResponse as List<dynamic>;
      final existingUserIds = existingData
          .map((e) => e['user_id'].toString())
          .toSet();

      final newTargetUsers = finalTargetUserIds
          .where((uid) => !existingUserIds.contains(uid))
          .toList();

      if (newTargetUsers.isEmpty) {
        debugPrint('All target users already have QR codes.');
        return 0;
      }

      // 3. Generate QR untuk setiap user baru
      final qrRecords = <Map<String, dynamic>>[];
      for (final userId in newTargetUsers) {
        final qrCode = _generateUniqueQrCode(pengajianId, userId);
        qrRecords.add({
          'pengajian_id': pengajianId,
          'user_id': userId,
          'qr_code': qrCode,
          'is_used': false,
        });
      }

      // 4. Batch insert ke database
      await _client.from('pengajian_qr').insert(qrRecords);

      debugPrint(
        'Generated ${qrRecords.length} new QR codes for pengajian: $pengajianId',
      );
      return qrRecords.length;
    } catch (e) {
      debugPrint('Error generating QR codes: $e');
      rethrow;
    }
  }

  Future<List<String>> _getTargetUsers(
    String orgId, {
    String? targetAudience,
    String? targetKriteriaId,
  }) async {
    try {
      // 1. Get Absolute Hierarchy Scope
      final scopeResponse = await _client
          .from('users')
          .select('''
            id, is_admin, current_org_id, 
            tanggal_lahir, jenis_kelamin, asal, keperluan, status
          ''')
          .or(
            'org_daerah_id.eq.$orgId,org_desa_id.eq.$orgId,org_kelompok_id.eq.$orgId',
          );

      final List<dynamic> usersInScope = scopeResponse as List<dynamic>;
      if (usersInScope.isEmpty) return [];

      // 2. CHECK FOR DYNAMIC TARGET KRITERIA
      if (targetKriteriaId != null) {
        final kriteriaRes = await _client
            .from('target_kriteria')
            .select()
            .eq('id', targetKriteriaId)
            .maybeSingle();

        if (kriteriaRes != null) {
          final k = TargetKriteria.fromJson(kriteriaRes);
          final List<String> filteredIds = [];
          final now = DateTime.now();

          for (final u in usersInScope) {
            // Age Check
            if (u['tanggal_lahir'] != null) {
              final birthDate = DateTime.parse(u['tanggal_lahir']);
              int age = now.year - birthDate.year;
              if (now.month < birthDate.month ||
                  (now.month == birthDate.month && now.day < birthDate.day)) {
                age--;
              }
              if (age < k.minUmur || age > k.maxUmur) continue;
            } else if (k.minUmur > 0) {
              // User has no birthdate but target requires min age
              continue;
            }

            // Gender Check
            if (k.jenisKelamin != 'Semua' &&
                u['jenis_kelamin'] != k.jenisKelamin) {
              continue;
            }

            // Status Check
            if (k.statusWarga != 'Semua' && u['asal'] != k.statusWarga) {
              continue;
            }

            // Keperluan Check
            if (k.keperluan != 'Semua' && u['keperluan'] != k.keperluan) {
              continue;
            }

            // Marriage Status Check
            if (k.statusPernikahan != 'Semua' &&
                u['status'] != k.statusPernikahan) {
              continue;
            }

            filteredIds.add(u['id'].toString());
          }
          return filteredIds;
        }
      }

      // 3. Fallback to Legacy Audience Targeting Logic
      String? targetCategory;
      if (targetAudience != null && targetAudience != 'Semua') {
        if (targetAudience == 'Muda - mudi') targetCategory = 'remaja';
        if (targetAudience == 'Praremaja') targetCategory = 'praremaja';
        if (targetAudience == 'Caberawit') targetCategory = 'caberawit';
      }

      // If "Semua", everyone in hierarchy gets the QR
      if (targetCategory == null) {
        return usersInScope.map((u) => u['id'].toString()).toList();
      }

      // 4. For Legacy Targeted Rooms: Youth
      final allChildOrgIds = await _getAllChildOrgIds(orgId);
      allChildOrgIds.add(orgId);

      final categoryOrgsResponse = await _client
          .from('organizations')
          .select('id')
          .filter('id', 'in', allChildOrgIds)
          .eq('age_category', targetCategory);

      final List<dynamic> catOrgs = categoryOrgsResponse as List<dynamic>;
      final List<String> validOrgIdsForCategory = catOrgs
          .map((o) => o['id'].toString())
          .toList();

      final List<String> targetUserIds = [];
      for (final u in usersInScope) {
        final String? userOrg = u['current_org_id']?.toString();
        if (userOrg != null && validOrgIdsForCategory.contains(userOrg)) {
          targetUserIds.add(u['id'].toString());
        }
      }

      return targetUserIds;
    } catch (e) {
      debugPrint('Error getting target users: $e');
      return [];
    }
  }

  /// Rekursif ambil semua child org IDs
  Future<List<String>> _getAllChildOrgIds(String parentId) async {
    final result = <String>[];

    try {
      final children = await _client
          .from('organizations')
          .select('id')
          .eq('parent_id', parentId);

      for (final child in children) {
        final childId = child['id'].toString();
        result.add(childId);
        // Rekursif ke bawah
        final grandChildren = await _getAllChildOrgIds(childId);
        result.addAll(grandChildren);
      }
    } catch (e) {
      debugPrint('Error getting child orgs: $e');
    }

    return result;
  }

  /// Stream QR Code aktif untuk user tertentu (dengan info pengajian)
  /// Menampilkan QR yang belum digunakan dari pengajian yang masih aktif
  Stream<List<PengajianQr>> streamActiveQrForUser(String userId) {
    // ignore: close_sinks
    final controller = StreamController<List<PengajianQr>>();

    Future<void> refresh() async {
      try {
        // 1. Initial Fetch of raw QR data
        final response = await _client
            .from('pengajian_qr')
            .select()
            .eq('user_id', userId);

        final data = List<Map<String, dynamic>>.from(response as List);

        if (data.isEmpty) {
          if (!controller.isClosed) controller.add([]);
          return;
        }

        // 2. Get unique pengajian IDs
        final pengajianIds = data
            .map((e) => e['pengajian_id'] as String)
            .toSet()
            .toList();

        // 3. Batch fetch pengajian details
        final pengajianRes = await _client
            .from('pengajian')
            .select()
            .filter('id', 'in', pengajianIds);

        final pengajianMap = {
          for (var p in List<Map<String, dynamic>>.from(pengajianRes as List))
            p['id'] as String: p,
        };

        // 4. Batch fetch presence
        final presensiRes = await _client
            .from('presensi')
            .select('pengajian_id, status')
            .eq('user_id', userId)
            .filter('pengajian_id', 'in', pengajianIds);

        final presensiMap = {
          for (var pr in List<Map<String, dynamic>>.from(presensiRes as List))
            pr['pengajian_id'] as String: pr['status'] as String,
        };

        final results = <PengajianQr>[];
        final now = DateTime.now();

        for (final qrData in data) {
          final pId = qrData['pengajian_id'] as String;
          final pData = pengajianMap[pId];

          if (pData != null) {
            final endedAtStr = pData['ended_at'] as String?;
            bool isActive = true;
            if (endedAtStr != null) {
              final endedAt = DateTime.parse(endedAtStr).toLocal();
              // Show for 1 more hour after it ends, or just strictly
              // Using strict here as per logic
              if (now.isAfter(endedAt)) {
                isActive = false;
              }
            }

            if (isActive) {
              final enrichedData = {
                ...qrData,
                'pengajian': pData,
                'presensi_status': presensiMap[pId],
              };
              results.add(PengajianQr.fromJson(enrichedData));
            }
          }
        }

        // Sort by creation date descending
        results.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });

        if (!controller.isClosed) controller.add(results);
      } catch (e) {
        debugPrint("Error in streamActiveQrForUser: $e");
        // Don't send error to stream to avoid breaking UI, just log it
      }
    }

    // Set up Realtime Channel with unique ID
    final channelId = 'qr_subscription_$userId';

    // Subscribe to changes
    final channel = _client.channel(channelId);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pengajian_qr',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint("Realtime Update QR: ${payload.eventType}");
            // Add small delay to ensure DB propagation
            Future.delayed(const Duration(milliseconds: 500), refresh);
          },
        )
        .subscribe();

    // Separate subscription for presensi to avoid chaining issues if any
    final presensiChannelId = 'presensi_subscription_$userId';
    final presensiChannel = _client.channel(presensiChannelId);

    presensiChannel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'presensi',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint("Realtime Update Presensi: ${payload.eventType}");
            Future.delayed(const Duration(milliseconds: 500), refresh);
          },
        )
        .subscribe();

    refresh(); // First fetch

    controller.onCancel = () {
      _client.removeChannel(channel);
      _client.removeChannel(presensiChannel);
      controller.close();
    };

    return controller.stream;
  }

  /// Fetch QR Code untuk user (one-time, bukan stream)
  Future<List<PengajianQr>> getActiveQrForUser(String userId) async {
    try {
      final qrList = await _client
          .from('pengajian_qr')
          .select(
            '*, pengajian!inner(title, location, started_at, ended_at, description, target_audience)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final results = <PengajianQr>[];
      final now = DateTime.now();

      for (final qrData in qrList) {
        final pengajian = qrData['pengajian'] as Map<String, dynamic>?;
        if (pengajian != null) {
          final endedAt = pengajian['ended_at'];
          final isActive =
              endedAt == null || DateTime.parse(endedAt).isAfter(now);

          if (isActive) {
            results.add(PengajianQr.fromJson(qrData));
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error fetching QR for user: $e');
      return [];
    }
  }

  /// Validate QR code dan dapatkan data-nya
  Future<PengajianQr?> validateQrCode(String qrCode) async {
    try {
      final response = await _client
          .from('pengajian_qr')
          .select('*, pengajian!inner(title, location, started_at, ended_at)')
          .eq('qr_code', qrCode)
          .maybeSingle();

      if (response == null) {
        debugPrint('QR code not found: $qrCode');
        return null;
      }

      return PengajianQr.fromJson(response);
    } catch (e) {
      debugPrint('Error validating QR: $e');
      return null;
    }
  }

  /// Mark QR as used setelah presensi berhasil
  Future<bool> markQrAsUsed(String qrId) async {
    try {
      await _client
          .from('pengajian_qr')
          .update({
            'is_used': true,
            'used_at': DateTime.now().toIso8601String(),
          })
          .eq('id', qrId);

      debugPrint('QR marked as used: $qrId');
      return true;
    } catch (e) {
      debugPrint('Error marking QR as used: $e');
      return false;
    }
  }

  /// Scan dan proses QR code (validate + mark used + record presensi)
  /// Returns: Map dengan 'success', 'message', dan 'data' (PengajianQr jika sukses)
  Future<Map<String, dynamic>> processQrScan(String qrCode) async {
    try {
      // 1. Validate QR
      final qr = await validateQrCode(qrCode);
      if (qr == null) {
        return {
          'success': false,
          'message': 'QR Code tidak valid atau tidak ditemukan',
        };
      }

      // 2. Check if already used
      if (qr.isUsed) {
        return {
          'success': false,
          'message': 'QR Code sudah digunakan sebelumnya',
          'data': qr,
        };
      }

      // 3. Mark as used
      final marked = await markQrAsUsed(qr.id);
      if (!marked) {
        return {'success': false, 'message': 'Gagal memproses QR Code'};
      }

      // 4. Record presensi
      await _client.from('presensi').upsert({
        'pengajian_id': qr.pengajianId,
        'user_id': qr.userId,
        'status': 'hadir',
        'method': 'qr',
      });

      return {
        'success': true,
        'message': 'Presensi berhasil dicatat',
        'data': qr.copyWith(isUsed: true, usedAt: DateTime.now()),
      };
    } catch (e) {
      debugPrint('Error processing QR scan: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  /// Regenerate QR code if it was previously rejected or used incorrectly
  Future<void> regenerateQrForUser(String pengajianId, String userId) async {
    try {
      // 1. Delete old QR
      await _client
          .from('pengajian_qr')
          .delete()
          .eq('pengajian_id', pengajianId)
          .eq('user_id', userId);

      // 2. Generate new
      final qrCode = _generateUniqueQrCode(pengajianId, userId);
      await _client.from('pengajian_qr').insert({
        'pengajian_id': pengajianId,
        'user_id': userId,
        'qr_code': qrCode,
        'is_used': false,
      });

      // 3. Delete 'tolak' presence record to clear status
      await _client
          .from('presensi')
          .delete()
          .eq('pengajian_id', pengajianId)
          .eq('user_id', userId)
          .eq('status', 'tolak');

      debugPrint('QR regenerated for user: $userId');
    } catch (e) {
      debugPrint('Error regenerating QR: $e');
      rethrow;
    }
  }

  /// Delete semua QR untuk pengajian tertentu (jika pengajian dihapus/dibatalkan)
  Future<void> deleteQrForPengajian(String pengajianId) async {
    try {
      await _client
          .from('pengajian_qr')
          .delete()
          .eq('pengajian_id', pengajianId);
      debugPrint('Deleted all QR for pengajian: $pengajianId');
    } catch (e) {
      debugPrint('Error deleting QR: $e');
    }
  }
}
