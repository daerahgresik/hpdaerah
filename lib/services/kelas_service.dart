import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/kelas_model.dart';
import 'package:flutter/foundation.dart';

class KelasService {
  final _client = Supabase.instance.client;

  /// Fetch kelas berdasarkan Kelompok ID
  /// Untuk dropdown saat registrasi atau admin view
  Future<List<Kelas>> fetchKelasByKelompok(String kelompokId) async {
    try {
      final response = await _client
          .from('kelas')
          .select()
          .eq('org_kelompok_id', kelompokId)
          .order('nama', ascending: true);

      return (response as List).map((e) => Kelas.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetchKelasByKelompok: $e");
      return [];
    }
  }

  /// Fetch semua kelas dalam hierarki admin
  /// Admin Daerah bisa lihat semua kelas di daerahnya
  /// Admin Desa bisa lihat semua kelas di desanya
  /// Admin Kelompok bisa lihat kelas di kelompoknya
  Future<List<Kelas>> fetchKelasInHierarchy({
    required String orgId,
    required int adminLevel,
  }) async {
    try {
      // Untuk admin level atas, kita perlu join dengan organizations
      // untuk filter berdasarkan hierarki

      if (adminLevel == 0) {
        // Super Admin - lihat semua
        final response = await _client
            .from('kelas')
            .select()
            .order('nama', ascending: true);
        return (response as List).map((e) => Kelas.fromJson(e)).toList();
      }

      if (adminLevel == 3) {
        // Admin Kelompok - hanya kelompok mereka
        return fetchKelasByKelompok(orgId);
      }

      // Admin Daerah (1) atau Desa (2) - perlu query hierarki
      // Fetch kelompok-kelompok di bawah org ini
      final List<String> kelompokIds = await _getKelompokIdsInHierarchy(
        orgId: orgId,
        adminLevel: adminLevel,
      );

      if (kelompokIds.isEmpty) return [];

      final response = await _client
          .from('kelas')
          .select()
          .inFilter('org_kelompok_id', kelompokIds)
          .order('nama', ascending: true);

      return (response as List).map((e) => Kelas.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetchKelasInHierarchy: $e");
      return [];
    }
  }

  /// Helper: Get semua kelompok ID dalam hierarki
  Future<List<String>> _getKelompokIdsInHierarchy({
    required String orgId,
    required int adminLevel,
  }) async {
    try {
      List<dynamic> response;

      if (adminLevel == 1) {
        // Admin Daerah - ambil semua kelompok (level 2) yang parent-nya
        // adalah desa (level 1) yang parent-nya adalah daerah ini

        // Step 1: Get all Desa under this Daerah
        final desaResponse = await _client
            .from('organizations')
            .select('id')
            .eq('parent_id', orgId)
            .eq('level', 1);

        final desaIds = (desaResponse as List)
            .map((e) => e['id'] as String)
            .toList();

        if (desaIds.isEmpty) return [];

        // Step 2: Get all Kelompok under those Desa
        response = await _client
            .from('organizations')
            .select('id')
            .inFilter('parent_id', desaIds)
            .eq('level', 2);
      } else if (adminLevel == 2) {
        // Admin Desa - ambil semua kelompok di bawah desa ini
        response = await _client
            .from('organizations')
            .select('id')
            .eq('parent_id', orgId)
            .eq('level', 2);
      } else {
        return [];
      }

      return (response as List).map((e) => e['id'] as String).toList();
    } catch (e) {
      debugPrint("Error _getKelompokIdsInHierarchy: $e");
      return [];
    }
  }

  /// Create kelas baru
  Future<Kelas> createKelas(Kelas kelas) async {
    try {
      final response = await _client
          .from('kelas')
          .insert(kelas.toJson())
          .select()
          .single();
      return Kelas.fromJson(response);
    } catch (e) {
      debugPrint("Error createKelas: $e");
      rethrow;
    }
  }

  /// Update kelas
  Future<void> updateKelas(Kelas kelas) async {
    try {
      await _client
          .from('kelas')
          .update({'nama': kelas.nama, 'deskripsi': kelas.deskripsi})
          .eq('id', kelas.id);
    } catch (e) {
      debugPrint("Error updateKelas: $e");
      rethrow;
    }
  }

  /// Delete kelas
  Future<void> deleteKelas(String id) async {
    try {
      await _client.from('kelas').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error deleteKelas: $e");
      rethrow;
    }
  }

  /// Pindahkan user ke kelas lain
  Future<void> moveUserToKelas({
    required String userId,
    required String? kelasId,
  }) async {
    try {
      await _client
          .from('users')
          .update({'org_kategori_id': kelasId})
          .eq('id', userId);
    } catch (e) {
      debugPrint("Error moveUserToKelas: $e");
      rethrow;
    }
  }

  /// Get anggota kelas
  Future<List<Map<String, dynamic>>> getKelasMembers(String kelasId) async {
    try {
      final response = await _client
          .from('users')
          .select('id, nama, username, foto_profil, jenis_kelamin')
          .eq('org_kategori_id', kelasId)
          .order('nama');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error getKelasMembers: $e");
      return [];
    }
  }

  /// Count anggota per kelas dalam satu kelompok
  Future<Map<String, int>> getKelasMemberCounts(String kelompokId) async {
    try {
      // Get all kelas in kelompok
      final kelasList = await fetchKelasByKelompok(kelompokId);
      final Map<String, int> counts = {};

      for (final kelas in kelasList) {
        final response = await _client
            .from('users')
            .select('id')
            .eq('org_kategori_id', kelas.id);
        counts[kelas.id] = (response as List).length;
      }

      return counts;
    } catch (e) {
      debugPrint("Error getKelasMemberCounts: $e");
      return {};
    }
  }

  /// Get users without class in a kelompok
  Future<List<Map<String, dynamic>>> getUnassignedUsers(
    String kelompokId,
  ) async {
    try {
      final response = await _client
          .from('users')
          .select('id, nama, username, foto_profil, jenis_kelamin')
          .eq('org_kelompok_id', kelompokId)
          .filter('org_kategori_id', 'is', 'null')
          .order('nama', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error getUnassignedUsers: $e");
      return [];
    }
  }
}
