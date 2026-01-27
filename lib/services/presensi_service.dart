import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/presensi_model.dart';
import '../models/user_model.dart';
import '../utils/image_helper.dart';

class PresensiService {
  final _client = Supabase.instance.client;

  Future<void> recordPresence({
    required String pengajianId,
    required String userId,
    required String method,
    String status = 'hadir',
  }) async {
    try {
      await _client.from('presensi').upsert({
        'pengajian_id': pengajianId,
        'user_id': userId,
        'status': status,
        'method': method,
        'approved_by': _client.auth.currentUser?.id,
      });
    } catch (e) {
      throw Exception('Gagal mencatat kehadiran: $e');
    }
  }

  /// Manual attendance by admin - marks a user as present
  Future<void> recordManualAttendance({
    required String pengajianId,
    required String userId,
    required String status,
  }) async {
    try {
      // Check if presensi record already exists
      final existing = await _client
          .from('presensi')
          .select('id')
          .eq('pengajian_id', pengajianId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update existing record
        await _client
            .from('presensi')
            .update({
              'status': status,
              'method': 'manual',
              'approved_by': _client.auth.currentUser?.id,
            })
            .eq('pengajian_id', pengajianId)
            .eq('user_id', userId);
      } else {
        // Insert new record
        await _client.from('presensi').insert({
          'pengajian_id': pengajianId,
          'user_id': userId,
          'status': status,
          'method': 'manual',
          'approved_by': _client.auth.currentUser?.id,
        });
      }

      // Also mark QR as used if exists
      await _client
          .from('pengajian_qr')
          .update({'is_used': true})
          .eq('pengajian_id', pengajianId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error recording manual attendance: $e');
      throw Exception('Gagal mencatat kehadiran manual: $e');
    }
  }

  Future<void> submitLeaveRequest({
    required String pengajianId,
    required String userId,
    required String keterangan,
    required File imageFile,
  }) async {
    try {
      // 1. Compress image to max 200KB
      final compressedFile = await ImageHelper.compressImage(
        file: imageFile,
        maxKiloBytes: 200,
      );

      // 2. Upload photo
      final photoUrl = await _uploadIzinPhoto(userId, compressedFile);

      // 2. Record presence as 'izin'
      await _client.from('presensi').insert({
        'pengajian_id': pengajianId,
        'user_id': userId,
        'status': 'izin',
        'method': 'izin',
        'keterangan': keterangan,
        'foto_izin': photoUrl,
      });

      // 3. Mark QR as used in pengajian_qr table (if exists)
      await _client
          .from('pengajian_qr')
          .update({'is_used': true})
          .eq('pengajian_id', pengajianId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Gagal mengajukan izin: $e');
    }
  }

  Future<String> _uploadIzinPhoto(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName =
          'izin_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = fileName;

      // We use 'fotoizin' bucket (dedicated for leave requests)
      await _client.storage
          .from('fotoizin')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return _client.storage.from('fotoizin').getPublicUrl(filePath);
    } catch (e) {
      throw 'Gagal upload foto izin: $e';
    }
  }

  Future<Map<String, int>> getAttendanceSummary(
    String pengajianId,
    String orgId,
  ) async {
    try {
      // 1. Get total attendees (status = hadir)
      final hadirResponse = await _client
          .from('presensi')
          .count(CountOption.exact)
          .eq('pengajian_id', pengajianId)
          .eq('status', 'hadir');

      // 2. Get total leave requests (status = izin)
      final izinResponse = await _client
          .from('presensi')
          .count(CountOption.exact)
          .eq('pengajian_id', pengajianId)
          .eq('status', 'izin');

      // 3. Get total target users for the organization (including children)
      final totalTargetUsers = await getTotalTargetUsers(orgId);

      final hadirCount = hadirResponse;
      final izinCount = izinResponse;
      final tidakHadirCount = (totalTargetUsers - hadirCount - izinCount).clamp(
        0,
        totalTargetUsers,
      );

      return {
        'hadir': hadirCount,
        'izin': izinCount,
        'tidak_hadir': tidakHadirCount,
        'total': totalTargetUsers,
      };
    } catch (e) {
      debugPrint("Error getAttendanceSummary: $e");
      return {'hadir': 0, 'izin': 0, 'tidak_hadir': 0, 'total': 0};
    }
  }

  Future<int> getTotalTargetUsers(String orgId) async {
    try {
      final allOrgIds = await _getAllChildOrgIds(orgId);
      allOrgIds.add(orgId);

      final response = await _client
          .from('users')
          .count(CountOption.exact)
          .filter('current_org_id', 'in', allOrgIds);

      return response;
    } catch (e) {
      debugPrint("Error getTotalTargetUsers: $e");
      return 0;
    }
  }

  Future<List<String>> _getAllChildOrgIds(String parentId) async {
    try {
      final response = await _client
          .from('organizations')
          .select('id')
          .eq('parent_id', parentId);

      final List<dynamic> children = response as List<dynamic>;
      final List<String> result = [];

      for (final child in children) {
        final childId = child['id'].toString();
        result.add(childId);
        final List<String> grandChildren = await _getAllChildOrgIds(childId);
        result.addAll(grandChildren);
      }
      return List<String>.from(result);
    } catch (e) {
      debugPrint('Error _getAllChildOrgIds: $e');
      return [];
    }
  }

  Future<UserModel?> findUserByUsername(String username) async {
    try {
      final response = await _client
          .from('users')
          .select('''*, 
               org_daerah:organizations!org_daerah_id(name), 
               org_desa:organizations!org_desa_id(name), 
               org_kelompok:organizations!org_kelompok_id(name)''')
          .eq('username', username)
          .maybeSingle();

      if (response == null) return null;

      // Extract names into a custom Map or handle in UserModel
      // For simplicity, let's just pass them in the json and let UserModel handle or use as is.
      return UserModel.fromJson({
        ...response,
        'daerah_name':
            (response['org_daerah'] as Map<String, dynamic>?)?['name'],
        'desa_name': (response['org_desa'] as Map<String, dynamic>?)?['name'],
        'kelompok_name':
            (response['org_kelompok'] as Map<String, dynamic>?)?['name'],
      });
    } catch (e) {
      debugPrint("Error findUserByUsername: $e");
      return null;
    }
  }

  // Refactor: Get all targets for a pengajian with status
  // STREAM VERSION: Realtime targets + attendance
  Stream<List<Map<String, dynamic>>> streamDetailedAttendance(
    String pengajianId,
  ) {
    // 1. Monitor the 'presensi' table for changes in this pengajian
    return _client
        .from('presensi')
        .stream(primaryKey: ['id'])
        .eq('pengajian_id', pengajianId)
        .asyncMap((data) async {
          // 2. Every time presensi changes, re-fetch and re-join with targets
          // This is the most reliable way to get a consistent joined view in realtime
          return await getDetailedAttendanceList(pengajianId);
        });
  }

  Future<List<Map<String, dynamic>>> getDetailedAttendanceList(
    String pengajianId,
  ) async {
    try {
      // 1. Get all QRs (targets) joined with users
      final response = await _client
          .from('pengajian_qr')
          .select('''
            is_used,
            user:users (
              id, nama, username, foto_profil, status_warga, asal,
              org_daerah_id, org_desa_id, org_kelompok_id,
              org_daerah:organizations!org_daerah_id(name),
              org_desa:organizations!org_desa_id(name),
              org_kelompok:organizations!org_kelompok_id(name)
            )
          ''')
          .eq('pengajian_id', pengajianId);

      final List<dynamic> data = response;

      // 2. Get all presence records for this pengajian to get actual status
      final presensiResponse = await _client
          .from('presensi')
          .select()
          .eq('pengajian_id', pengajianId);

      final List<dynamic> presensiList = presensiResponse;

      return data.map((item) {
        final user = item['user'] as Map<String, dynamic>;
        final userId = user['id'];

        // Find presence record
        final actualPresensi = presensiList.firstWhere(
          (p) => p['user_id'] == userId,
          orElse: () => <String, dynamic>{},
        );

        final status = actualPresensi.isEmpty
            ? 'belum_absen'
            : (actualPresensi['status'] ?? 'belum_absen');

        return {
          'user_id': userId,
          'nama': user['nama'] ?? 'Tanpa Nama',
          'username': user['username'],
          'foto_profil': user['foto_profil'],
          'status_warga': user['status_warga'],
          'asal': user['asal'],
          'daerah_id': user['org_daerah_id'],
          'desa_id': user['org_desa_id'],
          'kelompok_id': user['org_kelompok_id'],
          'daerah': user['org_daerah']?['name'],
          'desa': user['org_desa']?['name'],
          'kelompok': user['org_kelompok']?['name'],
          'is_used': item['is_used'],
          'status': status,
          'method': actualPresensi['method'],
          'keterangan': actualPresensi['keterangan'],
          'foto_izin': actualPresensi['foto_izin'],
          'recorded_at': actualPresensi['created_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint("Error getDetailedAttendanceList: $e");
      return [];
    }
  }

  Future<void> recordManualIzin({
    required String pengajianId,
    required String userId,
    required String keterangan,
  }) async {
    try {
      await _client.from('presensi').upsert({
        'pengajian_id': pengajianId,
        'user_id': userId,
        'status': 'izin',
        'method': 'manual',
        'keterangan': keterangan,
        'approved_by': _client.auth.currentUser?.id,
      });

      // Also mark QR as used
      await _client
          .from('pengajian_qr')
          .update({'is_used': true})
          .eq('pengajian_id', pengajianId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Gagal mencatat izin manual: $e');
    }
  }

  Stream<List<Presensi>> streamAttendanceList(String pengajianId) {
    return _client
        .from('presensi')
        .stream(primaryKey: ['id'])
        .eq('pengajian_id', pengajianId)
        .order('created_at', ascending: false)
        .map(
          (data) => (data as List)
              .map(
                (json) =>
                    Presensi.fromJson(Map<String, dynamic>.from(json as Map)),
              )
              .toList(),
        );
  }
}
