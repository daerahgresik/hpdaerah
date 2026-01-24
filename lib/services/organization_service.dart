import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/organization_model.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class OrganizationService {
  final SupabaseClient _client = Supabase.instance.client;
  final Random _random = Random();

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  Future<List<Organization>> fetchDaerah() async {
    try {
      final response = await _client
          .from('organizations')
          .select()
          .eq('type', 'daerah')
          .order('name');

      final data = response as List<dynamic>;
      return data.map((json) => Organization.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error Fetch Daerah: $e");
      throw Exception('Gagal memuat daerah: $e');
    }
  }

  // --- STREAMING (REALTIME) ---

  // Stream Root (Daerah)
  Stream<List<Organization>> streamDaerah() {
    return _client
        .from('organizations')
        .stream(primaryKey: ['id'])
        .eq('type', 'daerah')
        .order('name')
        .map(
          (data) => data.map((json) => Organization.fromJson(json)).toList(),
        );
  }

  // Stream Children (Anak)
  Stream<List<Organization>> streamChildren(String parentId) {
    return _client
        .from('organizations')
        .stream(primaryKey: ['id'])
        .eq('parent_id', parentId)
        .order('name')
        .map(
          (data) => data.map((json) => Organization.fromJson(json)).toList(),
        );
  }

  // Calculate stats for UI (Non-streaming for efficiency)
  Future<int> getChildrenCount(String parentId) async {
    try {
      final response = await _client
          .from('organizations')
          .count(CountOption.exact)
          .eq('parent_id', parentId);
      return response;
    } catch (e) {
      // Fallback for older Supabase SDK or if count fails
      // Note: postgrest usually returns 'count' property in response if requested, but flutter SDK has specialized .count() method or count param.
      // If .count() returns an int directly in newer SDKs:
      return 0;
    }
  }

  // Hitung total Kelompok dalam satu Daerah (Grandchildren)
  Future<int> getKelompokCountForDaerah(String daerahId) async {
    try {
      // 1. Ambil semua ID Desa di bawah Daerah ini
      final desaResponse = await _client
          .from('organizations')
          .select('id')
          .eq('parent_id', daerahId);

      final desaList = desaResponse as List<dynamic>;
      if (desaList.isEmpty) return 0;

      final desaIds = desaList.map((e) => e['id'] as String).toList();

      // 2. Hitung semua organisasi yang parent_id-nya ada di daftar desaIds
      final count = await _client
          .from('organizations')
          .count(CountOption.exact)
          .filter('parent_id', 'in', desaIds);

      return count;
    } catch (e) {
      debugPrint("Error count kelompok: $e");
      return 0;
    }
  }

  // --- FETCH (LEGACY/ONCE) ---

  Future<List<Organization>> fetchChildren(String parentId) async {
    // ... logic lama ...
    try {
      final response = await _client
          .from('organizations')
          .select()
          .eq('parent_id', parentId)
          .order('name');

      final data = response as List<dynamic>;
      return data.map((json) => Organization.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error Fetch Children ($parentId): $e");
      throw Exception('Gagal memuat data anak: $e');
    }
  }

  Future<void> createOrganization(Organization org) async {
    try {
      final cleanName = org.name.toLowerCase().trim().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '-',
      );
      // Fix: Handle case if parentId is not valid UUID or null string
      final parentPrefix = (org.parentId != null && org.parentId!.length > 5)
          ? org.parentId!.substring(0, 5)
          : 'root';
      final uniqueSuffix = _randomString(8); // 8 chars random is very safe

      final uniqueSlug = '$parentPrefix-$cleanName-$uniqueSuffix';

      // Pastikan parent_id dikirim null jika kosong/root, jangan string kosong
      final String? validParentId =
          (org.parentId == null || org.parentId!.isEmpty) ? null : org.parentId;

      await _client.from('organizations').insert({
        'name': org.name,
        'type': org.type,
        'parent_id': validParentId,
        'level': org.level,
        // Fix: Replace dash with underscore for DB constraint compatibility (muda-mudi -> muda_mudi)
        'age_category': org.ageCategory?.replaceAll('-', '_'),
        'slug': uniqueSlug,
        'is_active': true,
      });
      debugPrint("Success Create: ${org.name}");
    } catch (e) {
      debugPrint("Error Create Org: $e");
      // Coba berikan pesan error yang lebih manusiawi
      if (e.toString().contains("duplicate key")) {
        throw Exception("Gagal simpan: Data duplikat terdeteksi (coba lagi).");
      }
      throw Exception('Gagal membuat organisasi: ${e.toString()}');
    }
  }

  Future<void> updateOrganization(Organization org) async {
    try {
      await _client
          .from('organizations')
          .update({
            'name': org.name,
            'age_category': org.ageCategory?.replaceAll('-', '_'),
          })
          .eq('id', org.id);
      debugPrint("Success Update: ${org.name}");
    } catch (e) {
      debugPrint("Error Update Org: $e");
      throw Exception('Gagal update organisasi: $e');
    }
  }

  Future<void> deleteOrganization(String id) async {
    try {
      // 1. Cek apakah punya anak (rekursif manual jika DB tidak CASCADE)
      final children = await fetchChildren(id);

      // 2. Hapus anak-anak dulu (Depth-First)
      for (final child in children) {
        await deleteOrganization(child.id); // Recursive call
      }

      // 3. Hapus diri sendiri setelah anak kosong
      await _client.from('organizations').delete().eq('id', id);
      debugPrint("Success Delete: $id");
    } catch (e) {
      debugPrint("Error Delete Org: $e");
      throw Exception(
        'Gagal menghapus organisasi (pastikan sub-organisasi kosong atau coba lagi): $e',
      );
    }
  }
}
