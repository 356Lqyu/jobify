/*
 unauthenticated - login page
 authenticated - profile
*/

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../login.dart';
import '../edit_profile_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // listen auth state change
      stream: Supabase.instance.client.auth.onAuthStateChange,
      // build page based on the auth state
      builder: (context,snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        //check if there is valid session
        final session = snapshot.hasData ? snapshot.data!.session : null;
        if (session != null) {
          return const EditProfilePage();
        } else {
          return const Login();
        }
      },
    );
  }
}
