import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/materi_model.dart';

class MateriService {
  final _client = Supabase.instance.client;

  Future<void> createMateri(Materi materi) async {
    await _client.from('materi').insert(materi.toJson());
  }

  // Future<List<Materi>> getMateriByDate(String orgId, String tanggal) async { ... }
}
