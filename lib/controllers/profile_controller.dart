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
    required String? asal, // Citizen Status
    required String? status, // Marriage Status
    required String? jenisKelamin,
    required DateTime? tanggalLahir,
    required String? asalDaerah, // City
    required String? keperluan,
    required String? detailKeperluan,
    required String? keterangan,
    required String? noWa,
    String? newPassword,
    File? newImageFile,
  }) async {
    try {
      final updates = {
        'nama': nama,
        'username': username,
        'asal': asal,
        'status': status,
        'jenis_kelamin': jenisKelamin,
        'tanggal_lahir': tanggalLahir?.toIso8601String().split('T')[0],
        'asal_daerah': asalDaerah,
        'keperluan': keperluan,
        'detail_keperluan': detailKeperluan,
        'keterangan': keterangan,
        'no_wa': noWa,
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
          maxKiloBytes: 200,
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
        final superAdminUpdates = {
          'nama': nama,
          'username': username,
          if (newPassword != null && newPassword.isNotEmpty)
            'password': newPassword,
        };

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
        status: status,
        jenisKelamin: jenisKelamin,
        tanggalLahir: tanggalLahir,
        asalDaerah: asalDaerah,
        keperluan: keperluan,
        detailKeperluan: detailKeperluan,
        keterangan: keterangan,
        noWa: noWa,
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
