import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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
    required dynamic imageFile,
  }) async {
    try {
      // 1. Compress image to max 100KB (Leave Request Policy)
      final compressedFile = await ImageHelper.compressImage(
        file: (kIsWeb && imageFile is XFile) ? imageFile : imageFile,
        maxKiloBytes: 100,
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

  Future<String> _uploadIzinPhoto(String userId, dynamic image) async {
    try {
      final String fileName =
          'izin_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = fileName;

      if (kIsWeb && image is XFile) {
        final bytes = await image.readAsBytes();
        await _client.storage
            .from('fotoizin')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      } else {
        final file = image as File;
        await _client.storage
            .from('fotoizin')
            .upload(
              filePath,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      }

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

  Future<UserModel?> findUserById(String id) async {
    try {
      final response = await _client
          .from('users')
          .select('''*, 
               org_daerah:organizations!org_daerah_id(name), 
               org_desa:organizations!org_desa_id(name), 
               org_kelompok:organizations!org_kelompok_id(name)''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return UserModel.fromJson({
        ...response,
        'daerah_name':
            (response['org_daerah'] as Map<String, dynamic>?)?['name'],
        'desa_name': (response['org_desa'] as Map<String, dynamic>?)?['name'],
        'kelompok_name':
            (response['org_kelompok'] as Map<String, dynamic>?)?['name'],
      });
    } catch (e) {
      debugPrint("Error findUserById: $e");
      return null;
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
    // Listen to ANY change in presensi for this pengajian to trigger a refresh
    return _client
        .from('presensi')
        .stream(primaryKey: ['id'])
        .eq('pengajian_id', pengajianId)
        .asyncMap((_) async {
          return await getDetailedAttendanceList(pengajianId);
        })
        .handleError((error) {
          debugPrint('Stream Detailed Attendance Error: $error');
          return <Map<String, dynamic>>[];
        });
  }

  Future<List<Map<String, dynamic>>> getDetailedAttendanceList(
    String pengajianId,
  ) async {
    try {
      // 1. Get QR targets
      final qrResponse = await _client
          .from('pengajian_qr')
          .select('user_id, is_used')
          .eq('pengajian_id', pengajianId);
      final List<dynamic> qrRaw = qrResponse;

      // 2. Get Presence records
      final presensiResponse = await _client
          .from('presensi')
          .select('user_id, status, method, keterangan, foto_izin, created_at')
          .eq('pengajian_id', pengajianId);
      final List<dynamic> presensiRaw = presensiResponse;

      // 3. Collect unique User IDs
      final userIds = <String>{};
      for (var q in qrRaw) {
        if (q['user_id'] != null) userIds.add(q['user_id'] as String);
      }
      for (var p in presensiRaw) {
        if (p['user_id'] != null) userIds.add(p['user_id'] as String);
      }

      if (userIds.isEmpty) return [];

      // 4. Batch fetch User details with organization names
      final userResponse = await _client
          .from('users')
          .select('''
            id, nama, username, foto_profil,
            org_daerah:organizations!org_daerah_id(name),
            org_desa:organizations!org_desa_id(name),
            org_kelompok:organizations!org_kelompok_id(name)
          ''')
          .filter('id', 'in', userIds.toList());
      final List<dynamic> usersData = userResponse;
      final userMap = {for (var u in usersData) u['id'] as String: u};

      // 5. Merge into consolidated list
      return userIds.map((uid) {
        final userData = userMap[uid] ?? {};
        final qrData = qrRaw.firstWhere(
          (q) => q['user_id'] == uid,
          orElse: () => {},
        );
        final pData = presensiRaw.firstWhere(
          (p) => p['user_id'] == uid,
          orElse: () => {},
        );

        return {
          'user_id': uid,
          'nama': userData['nama'] ?? 'Jamaah',
          'username': userData['username'],
          'foto_profil': userData['foto_profil'],
          'daerah': userData['org_daerah']?['name'],
          'desa': userData['org_desa']?['name'],
          'kelompok': userData['org_kelompok']?['name'],
          'is_used': qrData['is_used'] ?? false,
          'status': pData['status'] ?? 'belum_absen',
          'method': pData['method'],
          'keterangan': pData['keterangan'],
          'foto_izin': pData['foto_izin'],
          'recorded_at': pData['created_at'],
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
        .map((data) {
          final List<dynamic> rawList = data as List<dynamic>;
          return rawList.map((json) {
            return Presensi.fromJson(Map<String, dynamic>.from(json as Map));
          }).toList();
        })
        .handleError((error) {
          debugPrint('Stream Attendance List Error: $error');
          return <Presensi>[];
        });
  }
}
