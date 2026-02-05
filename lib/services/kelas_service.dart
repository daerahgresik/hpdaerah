import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/kelas_model.dart';
import 'package:hpdaerah/models/aggregated_kelas_model.dart';
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

  /// Get unassigned users count across hierarchy
  Future<int> getUnassignedUsersCountInHierarchy({
    required String orgId,
    required int adminLevel,
  }) async {
    try {
      final kelompokIds = await _getKelompokIdsInHierarchy(
        orgId: orgId,
        adminLevel: adminLevel,
      );

      if (kelompokIds.isEmpty) return 0;

      final response = await _client
          .from('users')
          .select('id')
          .inFilter('org_kelompok_id', kelompokIds)
          .filter('org_kategori_id', 'is', 'null');

      return (response as List).length;
    } catch (e) {
      debugPrint("Error getUnassignedUsersCountInHierarchy: $e");
      return 0;
    }
  }

  /// Fetch aggregated kelas for Overview Mode
  /// Groups classes with similar names across kelompok
  Future<List<AggregatedKelas>> fetchAggregatedKelas({
    required String orgId,
    required int adminLevel,
    String? filterDesaId,
  }) async {
    try {
      // Get all kelompok in hierarchy with their info
      final kelompokInfos = await _getKelompokInfosInHierarchy(
        orgId: orgId,
        adminLevel: adminLevel,
        filterDesaId: filterDesaId,
      );

      if (kelompokInfos.isEmpty) return [];

      final kelompokIds = kelompokInfos.map((k) => k['id'] as String).toList();

      // Fetch all classes in these kelompok
      final kelasResponse = await _client
          .from('kelas')
          .select()
          .inFilter('org_kelompok_id', kelompokIds)
          .order('nama', ascending: true);

      final kelasList = (kelasResponse as List)
          .map((e) => Kelas.fromJson(e))
          .toList();

      // Get member counts for all classes
      final memberCounts = await _getMultiKelasMemberCounts(
        kelasList.map((k) => k.id).toList(),
      );

      // Group by normalized name
      final Map<String, List<KelasBreakdown>> grouped = {};

      for (final kelas in kelasList) {
        final normalized = ClassNameHelper.normalize(kelas.nama);
        final kelompokInfo = kelompokInfos.firstWhere(
          (k) => k['id'] == kelas.orgKelompokId,
          orElse: () => {'id': kelas.orgKelompokId, 'name': 'Unknown'},
        );

        final breakdown = KelasBreakdown(
          kelasId: kelas.id,
          kelasName: kelas.nama,
          kelompokId: kelas.orgKelompokId,
          kelompokName: kelompokInfo['name'] as String? ?? 'Unknown',
          desaId: kelompokInfo['desa_id'] as String?,
          desaName: kelompokInfo['desa_name'] as String?,
          memberCount: memberCounts[kelas.id] ?? 0,
        );

        grouped.putIfAbsent(normalized, () => []).add(breakdown);
      }

      // Convert to AggregatedKelas
      final result = grouped.entries.map((entry) {
        final breakdowns = entry.value;
        final displayName = ClassNameHelper.getDisplayName(
          breakdowns.map((b) => b.kelasName).toList(),
        );
        final totalMembers = breakdowns.fold<int>(
          0,
          (sum, b) => sum + b.memberCount,
        );

        return AggregatedKelas(
          normalizedName: entry.key,
          displayName: displayName,
          totalMembers: totalMembers,
          breakdown: breakdowns,
        );
      }).toList();

      // Sort by display name
      result.sort((a, b) => a.displayName.compareTo(b.displayName));

      return result;
    } catch (e) {
      debugPrint("Error fetchAggregatedKelas: $e");
      return [];
    }
  }

  /// Get hierarchy statistics for stats header
  Future<HierarchyStats> getHierarchyStats({
    required String orgId,
    required int adminLevel,
    String? filterDesaId,
  }) async {
    try {
      // Get desa count (for admin daerah)
      int desaCount = 0;
      if (adminLevel == 1) {
        final desaResponse = await _client
            .from('organizations')
            .select('id')
            .eq('parent_id', orgId)
            .eq('level', 1);
        desaCount = (desaResponse as List).length;
      }

      // Get kelompok infos
      final kelompokInfos = await _getKelompokInfosInHierarchy(
        orgId: orgId,
        adminLevel: adminLevel,
        filterDesaId: filterDesaId,
      );

      final kelompokCount = kelompokInfos.length;
      if (kelompokCount == 0) return HierarchyStats.empty();

      final kelompokIds = kelompokInfos.map((k) => k['id'] as String).toList();

      // Get unique class count
      final kelasResponse = await _client
          .from('kelas')
          .select('nama')
          .inFilter('org_kelompok_id', kelompokIds);

      final uniqueNames = (kelasResponse as List)
          .map((e) => ClassNameHelper.normalize(e['nama'] as String))
          .toSet();

      // Get total members
      final membersResponse = await _client
          .from('users')
          .select('id')
          .inFilter('org_kelompok_id', kelompokIds)
          .not('org_kategori_id', 'is', null);

      final totalMembers = (membersResponse as List).length;

      // Get unassigned count
      final unassignedResponse = await _client
          .from('users')
          .select('id')
          .inFilter('org_kelompok_id', kelompokIds)
          .filter('org_kategori_id', 'is', 'null');

      final unassignedCount = (unassignedResponse as List).length;

      return HierarchyStats(
        desaCount: desaCount,
        kelompokCount: kelompokCount,
        uniqueClassCount: uniqueNames.length,
        totalMembers: totalMembers,
        unassignedCount: unassignedCount,
      );
    } catch (e) {
      debugPrint("Error getHierarchyStats: $e");
      return HierarchyStats.empty();
    }
  }

  /// Get desa list for filter (Admin Daerah)
  Future<List<Map<String, dynamic>>> getDesaListForFilter(
    String daerahId,
  ) async {
    try {
      final response = await _client
          .from('organizations')
          .select('id, name')
          .eq('parent_id', daerahId)
          .eq('level', 1);
      // Apply natural sort untuk urutan yang benar (Desa 1, Desa 2, Desa 10)
      return ClassNameHelper.sortByNameNatural(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint("Error getDesaListForFilter: $e");
      return [];
    }
  }

  /// Get kelompok list for filter (Admin Desa or Daerah with desa filter)
  Future<List<Map<String, dynamic>>> getKelompokListForFilter({
    required String orgId,
    required int adminLevel,
    String? filterDesaId,
  }) async {
    try {
      if (adminLevel == 2 || filterDesaId != null) {
        // Admin Desa or filtered by desa
        final desaId = filterDesaId ?? orgId;
        final response = await _client
            .from('organizations')
            .select('id, name')
            .eq('parent_id', desaId)
            .eq('level', 2);
        // Apply natural sort
        return ClassNameHelper.sortByNameNatural(
          List<Map<String, dynamic>>.from(response),
        );
      } else if (adminLevel == 1) {
        // Admin Daerah - get all kelompok via desa
        final kelompokInfos = await _getKelompokInfosInHierarchy(
          orgId: orgId,
          adminLevel: adminLevel,
        );
        final list = kelompokInfos
            .map((k) => {'id': k['id'], 'name': k['name']})
            .toList();
        // Apply natural sort
        return ClassNameHelper.sortByNameNatural(
          List<Map<String, dynamic>>.from(list),
        );
      }
      return [];
    } catch (e) {
      debugPrint("Error getKelompokListForFilter: $e");
      return [];
    }
  }

  /// Helper: Get kelompok with organization info (name, desa)
  Future<List<Map<String, dynamic>>> _getKelompokInfosInHierarchy({
    required String orgId,
    required int adminLevel,
    String? filterDesaId,
  }) async {
    try {
      if (adminLevel == 3) {
        // Admin Kelompok - only their kelompok
        final response = await _client
            .from('organizations')
            .select('id, name, parent_id')
            .eq('id', orgId)
            .single();

        // Get desa info
        final desaResponse = await _client
            .from('organizations')
            .select('id, name')
            .eq('id', response['parent_id'])
            .maybeSingle();

        return [
          {
            'id': response['id'],
            'name': response['name'],
            'desa_id': desaResponse?['id'],
            'desa_name': desaResponse?['name'],
          },
        ];
      }

      if (adminLevel == 2 || filterDesaId != null) {
        // Admin Desa or filtered
        final desaId = filterDesaId ?? orgId;

        // Get desa info
        final desaInfo = await _client
            .from('organizations')
            .select('id, name')
            .eq('id', desaId)
            .maybeSingle();

        // Get kelompok under this desa
        final response = await _client
            .from('organizations')
            .select('id, name')
            .eq('parent_id', desaId)
            .eq('level', 2)
            .order('name');

        return (response as List)
            .map(
              (k) => {
                'id': k['id'],
                'name': k['name'],
                'desa_id': desaInfo?['id'],
                'desa_name': desaInfo?['name'],
              },
            )
            .toList();
      }

      if (adminLevel == 1) {
        // Admin Daerah - get all via desa
        final desaResponse = await _client
            .from('organizations')
            .select('id, name')
            .eq('parent_id', orgId)
            .eq('level', 1);

        final List<Map<String, dynamic>> result = [];

        for (final desa in desaResponse as List) {
          final kelompokResponse = await _client
              .from('organizations')
              .select('id, name')
              .eq('parent_id', desa['id'])
              .eq('level', 2)
              .order('name');

          for (final k in kelompokResponse as List) {
            result.add({
              'id': k['id'],
              'name': k['name'],
              'desa_id': desa['id'],
              'desa_name': desa['name'],
            });
          }
        }

        return result;
      }

      return [];
    } catch (e) {
      debugPrint("Error _getKelompokInfosInHierarchy: $e");
      return [];
    }
  }

  /// Helper: Get member counts for multiple kelas at once
  Future<Map<String, int>> _getMultiKelasMemberCounts(
    List<String> kelasIds,
  ) async {
    try {
      if (kelasIds.isEmpty) return {};

      final response = await _client
          .from('users')
          .select('org_kategori_id')
          .inFilter('org_kategori_id', kelasIds);

      final Map<String, int> counts = {};
      for (final user in response as List) {
        final kelasId = user['org_kategori_id'] as String?;
        if (kelasId != null) {
          counts[kelasId] = (counts[kelasId] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      debugPrint("Error _getMultiKelasMemberCounts: $e");
      return {};
    }
  }

  // ==================== ROOM TARGET METHODS ====================

  /// Get kelas list with member counts for room target selector
  /// Returns list of kelas with name, id, and memberCount
  Future<List<Map<String, dynamic>>> getKelasListForRoomTarget({
    required String orgId,
    required int adminLevel,
    String? filterKelompokId,
  }) async {
    try {
      // Get kelas based on hierarchy
      final kelasList = await fetchKelasInHierarchy(
        orgId: orgId,
        adminLevel: adminLevel,
      );

      if (kelasList.isEmpty) return [];

      // Get member counts
      final kelasIds = kelasList.map((k) => k.id).toList();
      final counts = await _getMultiKelasMemberCounts(kelasIds);

      // Aggregate by normalized name for display
      final Map<String, Map<String, dynamic>> aggregated = {};

      for (final kelas in kelasList) {
        final normalized = ClassNameHelper.normalize(kelas.nama);
        final count = counts[kelas.id] ?? 0;

        if (aggregated.containsKey(normalized)) {
          // Add to existing
          (aggregated[normalized]!['kelasIds'] as List<String>).add(kelas.id);
          aggregated[normalized]!['memberCount'] =
              (aggregated[normalized]!['memberCount'] as int) + count;
        } else {
          aggregated[normalized] = {
            'normalizedName': normalized,
            'displayName': kelas.nama,
            'kelasIds': [kelas.id],
            'memberCount': count,
          };
        }
      }

      // Convert to list and sort
      final result = aggregated.values.toList();
      result.sort(
        (a, b) => ClassNameHelper.naturalCompare(
          a['displayName'] as String,
          b['displayName'] as String,
        ),
      );

      return result;
    } catch (e) {
      debugPrint("Error getKelasListForRoomTarget: $e");
      return [];
    }
  }

  /// Get estimated target count based on target mode and selections
  /// Returns map with breakdown of counts
  Future<Map<String, dynamic>> getTargetEstimate({
    required String orgId,
    required int adminLevel,
    required String targetMode, // 'all' | 'kelas' | 'kriteria'
    List<String>? targetKelasIds,
    String? targetKriteriaId,
  }) async {
    try {
      int totalCount = 0;
      List<Map<String, dynamic>> breakdown = [];

      if (targetMode == 'all') {
        // Count all members in hierarchy
        final kelompokIds = await _getKelompokIdsInHierarchy(
          orgId: orgId,
          adminLevel: adminLevel,
        );

        if (kelompokIds.isEmpty) {
          return {'total': 0, 'breakdown': []};
        }

        final response = await _client
            .from('users')
            .select('id')
            .inFilter('org_kelompok_id', kelompokIds);

        totalCount = (response as List).length;
        breakdown.add({'label': 'Semua Anggota', 'count': totalCount});
      } else if (targetMode == 'kelas' && targetKelasIds != null) {
        // Count members in selected kelas
        final counts = await _getMultiKelasMemberCounts(targetKelasIds);

        // Get kelas names for breakdown
        for (final kelasId in targetKelasIds) {
          final kelasData = await _client
              .from('kelas')
              .select('nama')
              .eq('id', kelasId)
              .maybeSingle();

          final count = counts[kelasId] ?? 0;
          totalCount += count;

          if (kelasData != null) {
            breakdown.add({
              'label': kelasData['nama'] as String,
              'count': count,
            });
          }
        }
      } else if (targetMode == 'kriteria' && targetKriteriaId != null) {
        // Get kriteria details
        final kriteria = await _client
            .from('target_kriteria')
            .select()
            .eq('id', targetKriteriaId)
            .maybeSingle();

        if (kriteria != null) {
          // Build query based on kriteria
          final kelompokIds = await _getKelompokIdsInHierarchy(
            orgId: orgId,
            adminLevel: adminLevel,
          );

          if (kelompokIds.isNotEmpty) {
            var query = _client
                .from('users')
                .select(
                  'id, tanggal_lahir, jenis_kelamin, status_warga, keperluan, status_pernikahan',
                )
                .inFilter('org_kelompok_id', kelompokIds);

            final users = await query;

            // Filter in-memory based on kriteria
            final now = DateTime.now();
            var filteredCount = 0;

            for (final user in users as List) {
              bool matches = true;

              // Age filter
              if (user['tanggal_lahir'] != null) {
                final birthDate = DateTime.parse(user['tanggal_lahir']);
                final age = now.difference(birthDate).inDays ~/ 365;
                if (age < (kriteria['min_umur'] ?? 0) ||
                    age > (kriteria['max_umur'] ?? 100)) {
                  matches = false;
                }
              }

              // Gender filter
              if (kriteria['jenis_kelamin'] != 'Semua' &&
                  user['jenis_kelamin'] != kriteria['jenis_kelamin']) {
                matches = false;
              }

              // Status warga filter
              if (kriteria['status_warga'] != 'Semua' &&
                  user['status_warga'] != kriteria['status_warga']) {
                matches = false;
              }

              // Keperluan filter
              if (kriteria['keperluan'] != 'Semua' &&
                  user['keperluan'] != kriteria['keperluan']) {
                matches = false;
              }

              // Status pernikahan filter
              if (kriteria['status_pernikahan'] != 'Semua' &&
                  user['status_pernikahan'] != kriteria['status_pernikahan']) {
                matches = false;
              }

              if (matches) filteredCount++;
            }

            totalCount = filteredCount;
            breakdown.add({
              'label': kriteria['nama_target'] as String,
              'count': totalCount,
            });
          }
        }
      }

      return {'total': totalCount, 'breakdown': breakdown, 'mode': targetMode};
    } catch (e) {
      debugPrint("Error getTargetEstimate: $e");
      return {'total': 0, 'breakdown': [], 'error': e.toString()};
    }
  }
}
