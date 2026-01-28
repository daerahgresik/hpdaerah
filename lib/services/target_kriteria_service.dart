import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/target_kriteria_model.dart';
import 'package:flutter/foundation.dart';

class TargetKriteriaService {
  final _client = Supabase.instance.client;

  /// Fetch targets that this admin can USE
  /// Rule: Can use targets from their own org OR any parent org (Top-Down)
  Future<List<TargetKriteria>> fetchAvailableTargets({
    required String orgId,
    String? orgDaerahId,
    String? orgDesaId,
    String? orgKelompokId,
  }) async {
    try {
      // Build filters for hierarchy
      final List<String> relevantOrgIds = [orgId];
      if (orgDaerahId != null) relevantOrgIds.add(orgDaerahId);
      if (orgDesaId != null) relevantOrgIds.add(orgDesaId);
      // We don't necessarily add child IDs here because usage is Top-Down.

      final response = await _client
          .from('target_kriteria')
          .select()
          .filter('org_id', 'in', relevantOrgIds.toSet().toList());

      return (response as List).map((e) => TargetKriteria.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetchAvailableTargets: $e");
      return [];
    }
  }

  /// Fetch all targets for visibility/management
  /// Rule: Admin can see their own + all targets in their subtree
  Future<List<TargetKriteria>> fetchAllTargetsInHierarchy({
    required String orgId,
    required int adminLevel,
  }) async {
    try {
      var query = _client.from('target_kriteria').select();

      if (adminLevel == 0) {
        // Super Admin sees all
      } else if (adminLevel == 1) {
        query = query.eq('org_daerah_id', orgId);
      } else if (adminLevel == 2) {
        query = query.eq('org_desa_id', orgId);
      } else if (adminLevel == 3) {
        query = query.eq('org_kelompok_id', orgId);
      } else {
        query = query.eq('org_id', orgId);
      }

      final response = await query;
      return (response as List).map((e) => TargetKriteria.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetchAllTargetsInHierarchy: $e");
      return [];
    }
  }

  Future<void> createTarget(TargetKriteria target) async {
    await _client.from('target_kriteria').insert(target.toJson());
  }

  Future<void> deleteTarget(String id) async {
    await _client.from('target_kriteria').delete().eq('id', id);
  }
}
