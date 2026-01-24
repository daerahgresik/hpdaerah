import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pengajian_model.dart';

class PengajianService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> createPengajian(Pengajian pengajian) async {
    try {
      final data = {
        'org_id': pengajian.orgId,
        'title': pengajian.title,
        'location': pengajian.location,
        'description': pengajian.description,
        'target_audience': pengajian.targetAudience,
        'started_at': pengajian.startedAt.toIso8601String(),
        'ended_at': pengajian.endedAt?.toIso8601String(),
        'created_by': _client.auth.currentUser?.id,
        'is_template': false, // Pastikan bukan template
      };

      // Hanya kirim ID jika tidak kosong (untuk update/specific ID).
      // Jika kosong, biarkan Database generate UUID.
      if (pengajian.id.isNotEmpty) {
        data['id'] = pengajian.id;
      }

      await _client.from('pengajian').insert(data);
      debugPrint("Success Create Pengajian: ${pengajian.title}");
    } catch (e) {
      debugPrint("Error Create Pengajian: $e");
      throw Exception('Gagal membuat pengajian: $e');
    }
  }

  // CREATE TEMPLATE
  Future<void> createTemplate(Pengajian template) async {
    try {
      if (template.orgId.isEmpty) {
        throw Exception("Org ID is empty");
      }
      final data = {
        'org_id': template.orgId,
        'title': template.title, // Judul Default
        'description': template.description, // Deskripsi Default
        'location': template.location, // Lokasi Default
        'target_audience': template.targetAudience, // FIX: Save Target Audience
        'is_template': true,
        'template_name': template.templateName,
        'level': template.level, // 0, 1, 2
        'created_by': _client.auth.currentUser?.id,
        'started_at': DateTime.now()
            .toIso8601String(), // Dummy date required by NOT NULL? Check schema.
        // schema: started_at default now(). OK.
      };

      await _client.from('pengajian').insert(data);
      debugPrint("Success Create Template: ${template.templateName}");
    } catch (e) {
      debugPrint("Error Create Template: $e");
      rethrow;
    }
  }

  // DELETE PENGAJIAN / TEMPLATE
  Future<void> deletePengajian(String id) async {
    try {
      await _client.from('pengajian').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error delete pengajian: $e");
      rethrow;
    }
  }

  // GET TEMPLATES
  Stream<List<Pengajian>> streamTemplates(String orgId) {
    return _client.from('pengajian').stream(primaryKey: ['id']).map((data) {
      // Explicit cast for Web/JS interop safety
      final List<Map<String, dynamic>> typedData =
          List<Map<String, dynamic>>.from(data);

      final templates = typedData
          .where(
            (json) => json['org_id'] == orgId && json['is_template'] == true,
          )
          .map((json) => Pengajian.fromJson(json))
          .toList();

      // Sort client-side
      templates.sort(
        (a, b) => (a.templateName ?? '').compareTo(b.templateName ?? ''),
      );

      return templates;
    });
  }

  // Fetch Active Pengajian (ended_at is NULL AND is_template is FALSE)
  // Fetch Active Pengajian
  // Criteria:
  // 1. Same Org ID
  // 2. Not a template
  // 3. Status Active: ended_at is NULL OR ended_at is in the future
  Stream<List<Pengajian>> streamActivePengajian(String orgId) {
    return _client
        .from('pengajian')
        .stream(primaryKey: ['id'])
        .order('started_at')
        .map((data) {
          // Explicit cast for Web/JS interop safety
          final List<Map<String, dynamic>> typedData =
              List<Map<String, dynamic>>.from(data);

          final now = DateTime.now();
          return typedData
              .where((json) {
                // 1. Filter Check
                final jsonOrgId = json['org_id'];
                if (jsonOrgId != orgId) return false;

                // 2. Template Check
                final isTemplate = json['is_template'] == true;
                if (isTemplate) return false;

                // 3. Time Check
                final endedAtStr = json['ended_at'] as String?;
                if (endedAtStr == null) return true; // No end time = Active

                final endedAt = DateTime.tryParse(endedAtStr)?.toLocal();
                if (endedAt == null) return true; // Parse error = Safe active

                return endedAt.isAfter(now);
              })
              .map((json) => Pengajian.fromJson(json))
              .toList();
        });
  }
}
