import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {

  final SupabaseClient supabase = Supabase.instance.client;

  // Sign in with email & password (authenticate user , return session)
  Future<AuthResponse> signInWithEmailAndPassword(String email, String password) async {
    return await supabase.auth.signInWithPassword(email: email, password: password);
  }

  // Sign Up with email & password (create mew user , send verification email)
  Future<AuthResponse> signUpWithEmailAndPassword(String email, String password) async {
    return await supabase.auth.signUp(email: email, password: password);
  }

  //Sign Out (end session)
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  //Get current user email
  String? getCurrentUserEmail() {
    final session = supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

}
