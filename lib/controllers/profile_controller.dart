import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/utils/image_helper.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hpdaerah/services/organization_service.dart';
import 'package:hpdaerah/services/auth_service.dart';

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
    dynamic newImageFile, // Can be File or XFile
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
  Future<String> _uploadProfilePhoto(String userId, dynamic image) async {
    try {
      final String fileName =
          '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = fileName;

      if (kIsWeb && image is XFile) {
        final bytes = await image.readAsBytes();
        await _client.storage
            .from('fotoprofil')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      } else {
        final file = image as File;
        await _client.storage
            .from('fotoprofil')
            .upload(
              filePath,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      }

      // Get Public URL
      final imageUrl = _client.storage
          .from('fotoprofil')
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      throw 'Gagal upload foto ke storage: $e';
    }
  }

  /// Link Google Account using existing credentials/account object (from GoogleAuthButton)
  Future<UserModel> linkGoogleAccountFromCreds(
    UserModel currentUser,
    GoogleSignInAccount account,
  ) async {
    try {
      // Internal signIn removed because we receive the account

      // Check if email already used by another user (optional security check)
      // For now we assume Supabase constraint or logic helps us, but good to handle errors.

      final updates = {
        'email': account.email,
        'google_id': account.id,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Also update photo if user doesn't have one?
      // User request said: "bukan hanya disediakan untuk tempat menautkan melainkan juga di tampilkan akun google apa yg dia gunakan"
      // So mainly we just want to link.

      // Update DB
      if (currentUser.isSuperAdmin) {
        await _client
            .from('super_admins')
            .update(updates)
            .eq('id', currentUser.id!);
      } else {
        await _client.from('users').update(updates).eq('id', currentUser.id!);
      }

      // Return updated model locally
      return currentUser.copyWith(email: account.email, googleId: account.id);
    } catch (e) {
      throw 'Gagal menautkan akun Google: $e';
    }
  }

  /// Unlink Google Account (remove email & google_id)
  Future<UserModel> unlinkGoogleAccount(UserModel currentUser) async {
    try {
      final updates = {
        'email': null,
        'google_id': null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update DB
      if (currentUser.isSuperAdmin) {
        await _client
            .from('super_admins')
            .update(updates)
            .eq('id', currentUser.id!);
      } else {
        await _client.from('users').update(updates).eq('id', currentUser.id!);
      }

      // Return updated model locally
      return currentUser.copyWithUnlinkedGoogle();
    } catch (e) {
      throw 'Gagal memutuskan akun Google: $e';
    }
  }

  // --- NEW: FETCH DETAILED PROFILE (ORG NAMES) ---
  final OrganizationService _organizationService =
      OrganizationService(); // Need this imported

  Future<UserModel> fetchDetailedProfile(UserModel user) async {
    String? daerahName = user.orgDaerahName;
    String? desaName = user.orgDesaName;
    String? kelompokName = user.orgKelompokName;

    // Only fetch if name is missing but ID exists
    if (user.orgDaerahId != null && daerahName == null) {
      final org = await _organizationService.getOrgById(user.orgDaerahId!);
      daerahName = org?.name;
    }
    if (user.orgDesaId != null && desaName == null) {
      final org = await _organizationService.getOrgById(user.orgDesaId!);
      desaName = org?.name;
    }
    if (user.orgKelompokId != null && kelompokName == null) {
      final org = await _organizationService.getOrgById(user.orgKelompokId!);
      kelompokName = org?.name;
    }

    return user.copyWith(
      orgDaerahName: daerahName,
      orgDesaName: desaName,
      orgKelompokName: kelompokName,
    );
  }

  // --- NEW: FETCH ADMIN CONTACTS ---
  // Returns Map: {'Daerah': [List of Admins], 'Desa': [...], 'Kelompok': [...]}
  Future<Map<String, List<UserModel>>> fetchMyAdmins(UserModel user) async {
    final Map<String, List<UserModel>> result = {
      'Daerah': [],
      'Desa': [],
      'Kelompok': [],
    };

    final authService = AuthService(); // Need AuthService imported or passed

    if (user.orgDaerahId != null) {
      result['Daerah'] = await authService.getAdminsByOrg(user.orgDaerahId!, 1);
    }
    if (user.orgDesaId != null) {
      result['Desa'] = await authService.getAdminsByOrg(user.orgDesaId!, 2);
    }
    if (user.orgKelompokId != null) {
      result['Kelompok'] = await authService.getAdminsByOrg(
        user.orgKelompokId!,
        3,
      );
    }

    return result;
  }
}
