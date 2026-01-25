import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pengajian_template_model.dart';

class PengajianTemplateService {
  final SupabaseClient _client = Supabase.instance.client;

  // READ: Ambil semua template milik org ini
  Stream<List<PengajianTemplate>> streamTemplates(String orgId) {
    return _client
        .from('pengajian_templates')
        .stream(primaryKey: ['id'])
        .eq('org_id', orgId)
        .order('name')
        .map(
          (data) =>
              data.map((json) => PengajianTemplate.fromJson(json)).toList(),
        );
  }

  // CREATE: Tambah template baru
  Future<void> createTemplate(PengajianTemplate template) async {
    try {
      if (template.orgId.isEmpty) {
        throw Exception("Organization ID cannot be empty");
      }
      final data = {
        'org_id': template.orgId,
        'level': _levelToInt(template.level),
        'name': template.name,
        'default_title': template.defaultTitle,
        'default_description': template.defaultDescription,
        'default_location': template.defaultLocation,
      };

      // Handle ID generation logic same as before if needed, or let DB handle
      // Assuming DB gen_random_uuid(), we don't send ID if empty
      // But model has ID required.
      // Usually we pass empty string for new items in UI model
      if (template.id.isNotEmpty) {
        data['id'] = template.id;
      }

      await _client.from('pengajian_templates').insert(data);
    } catch (e) {
      debugPrint("Error create template: $e");
      rethrow;
    }
  }

  // DELETE
  Future<void> deleteTemplate(String id) async {
    try {
      await _client.from('pengajian_templates').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error delete template: $e");
      rethrow;
    }
  }

  int _levelToInt(String level) {
    if (level.toLowerCase() == 'daerah') return 0;
    if (level.toLowerCase() == 'desa') return 1;
    if (level.toLowerCase() == 'kelompok') return 2;
    return 0; // Default
  }
}
