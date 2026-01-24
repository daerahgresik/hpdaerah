import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final _client = Supabase.instance.client;

  /// Cek update dari tabel 'app_versions' di Supabase
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // 1. Get Current Version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint("Current Version: $currentVersion ($currentBuildNumber)");

      // 2. Fetch Latest Version from Supabase
      // Table Schema expected:
      // - latest_version (text): "1.0.1"
      // - build_number (int): 2
      // - download_url (text): "https://..."
      // - force_update (bool): false
      // - description (text): "Bug fixes..."
      final response = await _client
          .from('app_versions')
          .select()
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return; // No version info found

      final latestBuildNumber = response['build_number'] as int? ?? 0;
      final latestVersion = response['latest_version'] as String? ?? '0.0.0';
      final downloadUrl = response['download_url'] as String?;
      final forceUpdate = response['force_update'] as bool? ?? false;
      final description =
          response['description'] as String? ?? 'Versi baru tersedia!';

      // 3. Compare Logic
      if (latestBuildNumber > currentBuildNumber) {
        if (!context.mounted) return;
        _showUpdateDialog(
          context,
          latestVersion: latestVersion,
          description: description,
          downloadUrl: downloadUrl,
          forceUpdate: forceUpdate,
        );
      }
    } catch (e) {
      debugPrint("Error checking update: $e");
    }
  }

  void _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String description,
    String? downloadUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => !forceUpdate,
          child: AlertDialog(
            title: const Text('Update Tersedia'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Versi terbaru: $latestVersion"),
                const SizedBox(height: 8),
                Text(description),
                if (forceUpdate)
                  const Padding(
                    padding: EdgeInsets.only(top: 12.0),
                    child: Text(
                      "Update ini bersifat wajib / penting.",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Nanti Saja'),
                ),
              ElevatedButton(
                onPressed: () async {
                  if (downloadUrl != null) {
                    final uri = Uri.parse(downloadUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Gagal membuka link")),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Link download belum tersedia"),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F2D),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update Sekarang'),
              ),
            ],
          ),
        );
      },
    );
  }
}
