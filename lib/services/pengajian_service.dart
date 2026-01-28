import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/pengajian_model.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/services/pengajian_qr_service.dart';

class PengajianService {
  final SupabaseClient _client = Supabase.instance.client;
  final _qrService = PengajianQrService();

  /// Stream Active Pengajian filtered by Org
  /// Fixes TypeError by ensuring safe casting of realtime data
  Stream<List<Pengajian>> streamActivePengajian(UserModel user, String orgId) {
    if (orgId.isEmpty) return Stream.value([]);

    late StreamController<List<Pengajian>> controller;
    RealtimeChannel? channel;
    List<Pengajian>? latestData; // Cache for instant display

    Future<void> fetch() async {
      try {
        if (controller.isClosed) return;

        // 1. Get Ancestor IDs to allow visibility of Parent Events (e.g. Admin Desa sees Daerah events)
        final ancestorIds = await _getAncestors(orgId);
        final validIds = [orgId, ...ancestorIds];

        // debugPrint("Fetching active pengajian for org: $orgId");

        final response = await _client
            .from('pengajian')
            .select()
            .filter(
              'org_id',
              'in',
              validIds,
            ) // Filter by current AND parent orgs
            .order('started_at', ascending: false);

        final data = response as List<dynamic>;
        // debugPrint("Fetched raw count: ${data.length}");

        final List<Pengajian> items = [];
        for (final item in data) {
          try {
            final map = Map<String, dynamic>.from(item as Map);
            // Default to false if is_template is null/missing
            final isTemplate = map['is_template'] == true;

            if (!isTemplate) {
              items.add(Pengajian.fromJson(map));
            }
          } catch (e) {
            debugPrint("Error parsing pengajian item: $e");
          }
        }

        latestData = items; // Update cache
        if (!controller.isClosed) controller.add(items);
      } catch (e) {
        debugPrint("Error fetching active pengajian: $e");
        if (!controller.isClosed) controller.add([]);
      }
    }

    controller = StreamController<List<Pengajian>>.broadcast(
      onListen: () {
        if (latestData != null) {
          controller.add(latestData!); // Instant emit
        }
        fetch(); // Fetch fresh data

        channel = _client.channel('public:pengajian:org_scope:$orgId');
        channel
            ?.onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'pengajian',
              // Remove strict EQ filter to allow updates from parent orgs to trigger new fetch
              // We rely on fetch() logic to filter what we actually care about
              callback: (_) => fetch(),
            )
            .subscribe();
      },
      onCancel: () {
        channel?.unsubscribe();
        channel = null;
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Stream Templates (Pengajian with is_template = true)
  Stream<List<Pengajian>> streamTemplates(String orgId) {
    return _client
        .from('pengajian')
        .stream(primaryKey: ['id'])
        .eq('org_id', orgId)
        .order('template_name', ascending: true)
        .map((data) {
          final List<dynamic> rawList = data;
          return rawList
              .map((e) {
                final map = Map<String, dynamic>.from(e as Map);
                return Pengajian.fromJson(map);
              })
              .where((p) => p.isTemplate == true)
              .toList();
        })
        .handleError((error) {
          debugPrint('Stream Templates Error: $error');
          return <Pengajian>[];
        });
  }

  /// Create New Pengajian Room
  Future<void> createPengajian(Pengajian pengajian) async {
    try {
      // 1. Prepare Data
      final data = pengajian.toJson();
      // Remove ID to let DB generate it (if empty)
      if (pengajian.id.isEmpty) {
        data.remove('id');
      }

      // Ensure key fields
      data['is_template'] = false;

      // 2. Insert and Get ID returns List<Map>
      final response = await _client
          .from('pengajian')
          .insert(data)
          .select('id, org_id, target_audience, target_kriteria_id')
          .single(); // Use single() to get one Map

      final newId = response['id'] as String;
      final orgId = response['org_id'] as String;

      debugPrint('Created Room with Code: ${pengajian.roomCode}');

      // 3. Generate QR Codes automatically
      // We run this in background so UI doesn't hang, but we await if critical
      await _qrService.generateQrForTargetUsers(
        pengajianId: newId,
        targetOrgId: orgId,
        targetAudience: response['target_audience'],
        targetKriteriaId: response['target_kriteria_id'],
        creatorId: _client.auth.currentUser?.id,
      );
    } catch (e) {
      debugPrint('Error creating pengajian: $e');
      rethrow;
    }
  }

  /// Create Template
  Future<void> createTemplate(Pengajian template) async {
    try {
      final data = template.toJson();
      if (template.id.isEmpty) data.remove('id');
      data['is_template'] = true;

      await _client.from('pengajian').insert(data);
    } catch (e) {
      debugPrint('Error creating template: $e');
      rethrow;
    }
  }

  /// Update Template
  Future<void> updateTemplate(Pengajian template) async {
    try {
      final data = template.toJson();
      data['is_template'] = true;

      await _client.from('pengajian').update(data).eq('id', template.id);
    } catch (e) {
      debugPrint('Error update template: $e');
      rethrow;
    }
  }

  /// Delete Template
  Future<void> deleteTemplate(String id) async {
    try {
      await _client.from('pengajian').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting template: $e');
      rethrow;
    }
  }

  /// Finish/Close Room
  Future<void> closePengajian(String id) async {
    try {
      await _client
          .from('pengajian')
          .update({
            'ended_at': DateTime.now().toIso8601String(),
            // 'is_active': false, // If there's an is_active column, update it.
          })
          .eq('id', id);
    } catch (e) {
      debugPrint("Error closing pengajian: $e");
      rethrow;
    }
  }

  /// Delete Room Permanently
  Future<void> deletePengajian(String id) async {
    try {
      // 1. Delete QRs
      await _client.from('pengajian_qr').delete().eq('pengajian_id', id);
      // 2. Delete Presensi
      await _client.from('presensi').delete().eq('pengajian_id', id);
      // 3. Delete Pengajian
      await _client.from('pengajian').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error delete pengajian: $e");
      rethrow;
    }
  }

  /// Find by Code (For Joining)
  Future<Pengajian?> findPengajianByCode(String code) async {
    try {
      final response = await _client
          .from('pengajian')
          .select()
          .eq('room_code', code)
          .eq('is_template', false)
          .maybeSingle();

      if (response == null) return null;
      return Pengajian.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint("Error findPengajianByCode: $e");
      return null;
    }
  }

  /// Join Existing Room (Sync QRs for my Org's members)
  Future<void> joinPengajian({
    required String pengajianId,
    required String targetOrgId,
    required String targetAudience,
  }) async {
    try {
      // We reuse QR Service to generate QRs for users in 'targetOrgId'
      // to the existing 'pengajianId' with 'targetAudience' criteria.

      // Note: This assumes the logic in QrService handles duplicates.
      await _qrService.generateQrForTargetUsers(
        pengajianId: pengajianId,
        targetOrgId: targetOrgId,
        targetAudience: targetAudience,
        creatorId: _client.auth.currentUser?.id,
      );
    } catch (e) {
      debugPrint("Error joining pengajian: $e");
      rethrow;
    }
  }

  Future<List<String>> _getAncestors(String orgId) async {
    final ancestors = <String>[];
    String? currentId = orgId;

    // Safety limit to prevent infinite loops (though hierarchy depth is usually small)
    int depth = 0;
    while (currentId != null && depth < 5) {
      try {
        final res = await _client
            .from('organizations')
            .select('parent_id')
            .eq('id', currentId)
            .maybeSingle();

        if (res == null) break;

        final parentId = res['parent_id'] as String?;
        if (parentId != null) {
          ancestors.add(parentId);
          currentId = parentId;
        } else {
          break;
        }
        depth++;
      } catch (e) {
        debugPrint("Error fetching ancestor: $e");
        break;
      }
    }
    return ancestors;
  }
}
