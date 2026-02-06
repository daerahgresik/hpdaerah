import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get current authenticated user details from 'users' table or 'super_admins' table
  Future<UserModel?> getCurrentUser(String username) async {
    try {
      // 1. Try finding in regular 'users' table
      final userResponse = await _client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (userResponse != null) {
        return UserModel.fromJson(userResponse);
      }

      // 2. If not found, try finding in 'super_admins' table
      final superAdminResponse = await _client
          .from('super_admins')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (superAdminResponse != null) {
        // Construct UserModel from SuperAdmin data
        return UserModel(
          id: superAdminResponse['id'],
          username: superAdminResponse['username'],
          nama: superAdminResponse['nama'],
          isAdmin: true,
          adminLevel: 0, // Super Admin Level
          // Super Admin can switch daerah, so initially null or handle in UI
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching user: $e');
      return null;
    }
  }

  /// Get user by Email (for Google Auth)
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final userResponse = await _client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (userResponse != null) {
        return UserModel.fromJson(userResponse);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user by email: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    // Since we are using custom login (no auth.signIn), we just likely clear local state
    // But for Supabase Auth consistency:
    // await _client.auth.signOut();
  }
}
