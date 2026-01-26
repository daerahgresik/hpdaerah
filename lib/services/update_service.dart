import 'package:flutter/material.dart';

class UpdateService {
  /// Cek update dari tabel 'app_versions' di Supabase
  Future<void> checkForUpdate(BuildContext context) async {
    // Disabled temporarily: table 'app_versions' does not exist yet
    return;
  }
}
