import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/background_service.dart';

class AuthRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  Future<AuthResponse> login(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.session != null) {
      await BackgroundService.saveToken(response.session!.accessToken);
    }
    
    return response;
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.urbangologistics://reset-password',
    );
  }

  Future<void> logout() async {
    await BackgroundService.stopHeartbeat();
    await BackgroundService.clearToken();
    await _supabase.auth.signOut();
  }

  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}