import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import '../home.dart';
import '../data/user_repository.dart';
import '../main.dart';
import '../users/user_provider.dart';
import '../users/users.dart';

class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final UserRepository _userRepo = UserRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check for errors
        if (snapshot.hasError) {
          debugPrint('Auth error: ${snapshot.error}');
          return const AnimatedHomePage();  // Changed from WelcomePage to AnimatedHomePage
        }

        // Get session
        final session = snapshot.data?.session;

        if (session != null) {
          return FutureBuilder(
            future: _loadUserData(context),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final user = userSnapshot.data;
              if (user == null) {
                return const Login();
              }

              return HomePage(user: user);
            },
          );
        }

        // Not logged in then show welcome page
        return const WelcomePage();
      },
    );
  }

  Future<Users?> _loadUserData(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUser();
    return userProvider.currentUser;
  }
}