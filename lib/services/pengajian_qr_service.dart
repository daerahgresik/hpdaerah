import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pengajian_qr_model.dart';

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
  }) async {
    try {
      // 1. Ambil semua user yang terdaftar di organisasi target
      // Ini mencakup user di org tersebut DAN semua child org di bawahnya
      final targetUsers = await _getTargetUsers(targetOrgId);

      if (targetUsers.isEmpty) {
        debugPrint('No target users found for org: $targetOrgId');
        return 0;
      }

      // 2. Generate QR untuk setiap user
      final qrRecords = <Map<String, dynamic>>[];
      for (final userId in targetUsers) {
        final qrCode = _generateUniqueQrCode(pengajianId, userId);
        qrRecords.add({
          'pengajian_id': pengajianId,
          'user_id': userId,
          'qr_code': qrCode,
          'is_used': false,
        });
      }

      // 3. Batch insert ke database
      await _client.from('pengajian_qr').insert(qrRecords);

      debugPrint(
        'Generated ${qrRecords.length} QR codes for pengajian: $pengajianId',
      );
      return qrRecords.length;
    } catch (e) {
      debugPrint('Error generating QR codes: $e');
      rethrow;
    }
  }

  /// Ambil semua user ID yang menjadi target (termasuk child orgs)
  Future<List<String>> _getTargetUsers(String orgId) async {
    try {
      // Ambil org target dan semua child-nya secara rekursif
      final allOrgIds = await _getAllChildOrgIds(orgId);
      allOrgIds.add(orgId); // Include the target org itself

      // Ambil semua user yang current_org_id-nya ada di daftar org
      final response = await _client
          .from('users')
          .select('id')
          .filter('current_org_id', 'in', allOrgIds);

      final users = response as List<dynamic>;
      return users.map((u) => u['id'] as String).toList();
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
        final childId = child['id'] as String;
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
    return _client
        .from('pengajian_qr')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          // Filter only unused QRs and fetch pengajian details
          final results = <PengajianQr>[];

          for (final qrData in data) {
            // Fetch pengajian details
            final pengajianId = qrData['pengajian_id'];
            final pengajianResponse = await _client
                .from('pengajian')
                .select(
                  'title, location, started_at, ended_at, description, target_audience',
                )
                .eq('id', pengajianId)
                .maybeSingle();

            if (pengajianResponse != null) {
              // Check if pengajian is still active (not ended)
              final endedAt = pengajianResponse['ended_at'];
              final isActive =
                  endedAt == null ||
                  DateTime.parse(endedAt).isAfter(DateTime.now());

              if (isActive) {
                // Fetch presence status if it exists
                final presensiResponse = await _client
                    .from('presensi')
                    .select('status')
                    .eq('pengajian_id', pengajianId)
                    .eq('user_id', userId)
                    .maybeSingle();

                final enrichedData = {
                  ...qrData,
                  'pengajian': pengajianResponse,
                  if (presensiResponse != null)
                    'presensi_status': presensiResponse['status'],
                };
                results.add(PengajianQr.fromJson(enrichedData));
              }
            }
          }

          return results;
        });
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
