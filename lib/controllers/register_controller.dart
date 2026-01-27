import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/services/organization_service.dart';
import 'package:hpdaerah/utils/image_helper.dart';

class RegisterController {
  final SupabaseClient _client = Supabase.instance.client;
  final OrganizationService _organizationService = OrganizationService();

  // --- HIERARCHY DATA FETCHING ---

  Future<List<Organization>> fetchDaerah() {
    return _organizationService.fetchDaerah();
  }

  Future<List<Organization>> fetchChildren(String parentId) {
    return _organizationService.fetchChildren(parentId);
  }

  // --- ADMIN CONTACT FETCHING ---
  Future<List<UserModel>> fetchAdminsByOrgId(String orgId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('admin_org_id', orgId)
          .eq('is_admin', true); // Hanya ambil admin

      final List<dynamic> data = response;
      return data.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      // Return empty list if error (fail gracefully)
      return [];
    }
  }

  // --- REGISTRATION LOGIC ---

  Future<void> registerUser({
    required String nama,
    required String username,
    required String password,
    required String? asal, // Citizen Status
    required String? status, // Marriage Status
    required String? jenisKelamin,
    required DateTime? tanggalLahir,
    required String? asalDaerah, // Origin City
    required String? keperluan,
    required String? detailKeperluan,
    XFile? fotoProfilFile,
    required String? selectedDaerah,
    required String? selectedDesa,
    required String? selectedKelompok,
    required String? selectedKelas,
    required String? noWa,
  }) async {
    try {
      // 1. Determine Organization ID (Lowest Level)
      final determinedOrgId =
          selectedKelas ?? selectedKelompok ?? selectedDesa ?? selectedDaerah;

      // 2. Upload Photo if exists (with Smart Compression)
      String? fotoUrl;
      if (fotoProfilFile != null) {
        final compressedFile = await ImageHelper.compressImage(
          file: kIsWeb ? fotoProfilFile : File(fotoProfilFile.path),
          maxKiloBytes: 200,
        );
        fotoUrl = await _uploadAvatar(compressedFile);
      }

      // 3. Create User Model (With Hierarchy)
      final userModel = UserModel(
        username: username,
        nama: nama,
        password: password,
        asal: asal,
        status: status ?? 'Belum Kawin',
        jenisKelamin: jenisKelamin,
        tanggalLahir: tanggalLahir,
        asalDaerah: asalDaerah,
        keperluan: keperluan,
        detailKeperluan: detailKeperluan,
        jabatan: null,
        keterangan: null,
        fotoProfil: fotoUrl,
        currentOrgId: determinedOrgId,
        noWa: noWa,
        // Save Hierarchy Explicitly
        orgDaerahId: selectedDaerah,
        orgDesaId: selectedDesa,
        orgKelompokId: selectedKelompok,
        orgKategoriId: selectedKelas,
      );

      // 4. Insert into 'users' table
      final response = await _client
          .from('users')
          .insert(userModel.toJson())
          .select()
          .single();

      final userId = response['id'];

      // 5. Insert into 'user_organizations' (Link to Lowest Level)
      if (determinedOrgId != null) {
        await _client.from('user_organizations').insert({
          'user_id': userId,
          'org_id': determinedOrgId,
          'role': 'member',
        });
      }
    } catch (e) {
      // Check for duplicate username error (Postgres error code 23505)
      if (e.toString().contains('users_username_key') ||
          e.toString().contains('23505')) {
        throw 'Username sudah digunakan. Silakan pilih username lain.';
      }
      throw 'Registrasi gagal: $e';
    }
  }

  Future<String> _uploadAvatar(dynamic image) async {
    try {
      final String fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = fileName;

      if (kIsWeb) {
        final bytes = await (image as XFile).readAsBytes();
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

      return _client.storage.from('fotoprofil').getPublicUrl(filePath);
    } catch (e) {
      throw 'Gagal upload foto: $e';
    }
  }
}
