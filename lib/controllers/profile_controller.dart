import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/utils/image_helper.dart';

class ProfileController {
  final SupabaseClient _client = Supabase.instance.client;

  /// Update user profile logic
  /// Returns the updated UserModel if successful, throws error if failed.
  Future<UserModel> updateProfile({
    required UserModel currentUser,
    required String nama,
    required String username,
    required String asal,
    required String statusWarga,
    required String keperluan,
    required String detailKeperluan,
    required String keterangan,
    required String noWa, // Add noWa
    String? newPassword,
    File? newImageFile,
  }) async {
    try {
      final updates = {
        'nama': nama,
        'username': username,
        'asal': asal,
        'status_warga': statusWarga,
        'keperluan': keperluan,
        'detail_keperluan': detailKeperluan,
        'keterangan': keterangan,
        'no_wa': noWa, // Add to updates
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Jika password diisi, ikut diupdate
      if (newPassword != null && newPassword.isNotEmpty) {
        updates['password'] = newPassword;
      }

      // --- LOGIKA UPLOAD GAMBAR WITH COMPRESSION ---
      if (newImageFile != null) {
        final compressedFile = await ImageHelper.compressImage(
          file: newImageFile,
          maxKiloBytes: 100,
        );
        final imageUrl = await _uploadProfilePhoto(
          currentUser.id!,
          compressedFile,
        );
        updates['foto_profil'] = imageUrl;
      }

      // --- SELECT TABLE & FIELDS BASED ON ROLE ---
      if (currentUser.isSuperAdmin) {
        // Super Admin -> 'super_admins' table
        // Only update fields that exist in super_admins
        final superAdminUpdates = {
          'nama': nama,
          'username': username,
          if (newPassword != null && newPassword.isNotEmpty)
            'password': newPassword,
        };

        // Note: super_admins table doesn't have profile photo column in this schema yet,
        // but if we want to support it, we'd need to add it or ignore it.
        // For now we'll ignore photo update for super admin or handle it if column exists.
        // Assuming we haven't added 'foto_profil' to super_admins yet in SQL.

        await _client
            .from('super_admins')
            .update(superAdminUpdates)
            .eq('id', currentUser.id!);
      } else {
        // Regular User / Other Admins -> 'users' table
        await _client.from('users').update(updates).eq('id', currentUser.id!);
      }

      // Return updated model locally
      return currentUser.copyWith(
        nama: nama,
        username: username,
        asal: asal,
        statusWarga: statusWarga,
        keperluan: keperluan,
        detailKeperluan: detailKeperluan,
        keterangan: keterangan,
        noWa: noWa, // Update local model
        fotoProfil: updates['foto_profil'] ?? currentUser.fotoProfil,
      );
    } catch (e) {
      throw 'Gagal update profil: $e';
    }
  }

  /// Private helper to upload photo
  Future<String> _uploadProfilePhoto(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName =
          '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = fileName;

      // Upload ke Bucket 'fotoprofil'
      await _client.storage
          .from('fotoprofil')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get Public URL
      final imageUrl = _client.storage
          .from('fotoprofil')
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      throw 'Gagal upload foto ke storage: $e';
    }
  }
}
