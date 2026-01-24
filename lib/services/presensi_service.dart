import 'package:supabase_flutter/supabase_flutter.dart';
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
