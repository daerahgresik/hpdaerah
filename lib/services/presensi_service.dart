<<<<<<< HEAD
﻿import 'package:supabase_flutter/supabase_flutter.dart';
=======
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
>>>>>>> bb22edb4cde86073391206bc940ebb7205402800
import '../models/presensi_model.dart';
import '../models/user_model.dart';

class PresensiService {
  final _client = Supabase.instance.client;

  Future<void> recordPresence({
    required String pengajianId,
    required String userId,
    required String method,
  }) async {
    try {
      await _client.from('presensi').upsert({
        'pengajian_id': pengajianId,
        'user_id': userId,
        'status': 'hadir',
        'method': method,
        'approved_by': _client.auth.currentUser?.id,
      });
    } catch (e) {
      throw Exception('Gagal mencatat kehadiran: $e');
    }
  }

  Future<void> submitLeaveRequest({
    required String pengajianId,
    required String userId,
    required String keterangan,
    required File imageFile,
  }) async {
    try {
      // 1. Upload photo
      final photoUrl = await _uploadIzinPhoto(userId, imageFile);

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
          .update({
            'is_used': true,
            'used_at': DateTime.now().toIso8601String(),
          })
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

      // We use 'avatars' bucket for now as it's already configured
      // In a production app, we might want a separate 'presensi' bucket
      await _client.storage
          .from('avatars')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return _client.storage.from('avatars').getPublicUrl(filePath);
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
    final result = <String>[];
    try {
      final children = await _client
          .from('organizations')
          .select('id')
          .eq('parent_id', parentId);

      for (final child in children) {
        final childId = child['id'] as String;
        result.add(childId);
        final grandChildren = await _getAllChildOrgIds(childId);
        result.addAll(grandChildren);
      }
    } catch (e) {
      debugPrint('Error _getAllChildOrgIds: $e');
    }
    return result;
  }

  Future<UserModel?> findUserByUsername(String username) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Stream<List<Presensi>> streamAttendanceList(String pengajianId) {
    return _client
        .from('presensi')
        .stream(primaryKey: ['id'])
        .eq('pengajian_id', pengajianId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Presensi.fromJson(json)).toList());
  }
}
