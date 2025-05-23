import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    final AuthResponse response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      final String userId = response.user!.id;

      final List<Map<String, dynamic>> customerData = await _supabase
          .from('customers')
          .select('status')
          .eq('user_id', userId)
          .limit(1);

      if (customerData.isNotEmpty) {
        final String status = customerData[0]['status'];

        if (status == 'banned') {

          await _supabase.auth.signOut();
          throw Exception('Your account has been banned. Please contact support.');
        } else if (status == 'active') {

          return response;
        } else {

          await _supabase.auth.signOut();
          throw Exception('Your account status is not active. Please contact support.');
        }
      } else {

        await _supabase.auth.signOut();
        throw Exception('User data not found. Please contact support.');
      }
    }
    return response;
  }

  Future<AuthResponse> signUpWithEmailPassword(
      String email,
      String password,
      String fullName,
      ) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await _supabase.from('customers').insert({
        'user_id': response.user!.id,
        'full_name': fullName,
        'email': email,
        'phone': '',
        'status': 'active',
        'visits': 0,
      });
    }

    return response;
  }

  Future<void> signOut() async {
    return await _supabase.auth.signOut();
  }

  bool isLoggedIn() {
    final session = _supabase.auth.currentSession;
    return session != null;
  }

  User? getCurrentUser() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user;
  }
}