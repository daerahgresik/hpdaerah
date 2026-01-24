import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hpdaerah/models/user_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get current authenticated user details from 'users' table
  Future<UserModel?> getCurrentUser(String username) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response == null) return null;

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error fetching user: $e');
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
