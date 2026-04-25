import 'package:flutter/material.dart';
import 'package:jobify/users/profile_page.dart';
import 'package:jobify/auth/reset_password.dart';
import 'package:jobify/users/user_provider.dart';
import 'package:jobify/users/users.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/auth/registration.dart';
import 'auth/forgot_password.dart';
import 'auth/login.dart';
import 'setting_page.dart';
import 'home.dart';
import 'data/user_repository.dart';

const String supabaseUrl = 'https://nejlppdligklddlwvzub.supabase.co';
const String supabaseKey = 'sb_secret_518COekCnlz8R_OAgQVCIw_2E9LVs8_';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  // Clear any stale recovery session flags
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    // Check if this is a stale recovery session
    final userMetadata = session.user?.userMetadata;
    if (userMetadata != null && userMetadata['reset_password'] == true) {
      await Supabase.instance.client.auth.signOut();
      print('Cleared stale password recovery session');
    }
  }

  runApp(const MainApp());
}

final supabase = Supabase.instance.client;

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'Jobify',
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthGate(),
          '/login': (context) => const Login(),
          '/forgot-password': (context) => const ForgotPasswordPage(),
          '/reset-password': (context) => const ResetPasswordPage(),
          '/profile': (context) => const ProfilePage(),
          '/settings': (context) => const SettingPage(),
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          // User is logged in, load user data
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
                return const WelcomePage();
              }

              return HomePage(user: user);
            },
          );
        }

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

// Welcome Page
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// Logo
              Container(
                width: 260,
                height: 130,
                child: Image.asset(
                  'assets/images/logo3.png',
                  fit: BoxFit.contain,
                ),
              ),

              /// Title
              Text(
                'Welcome to Jobify',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),

              /// Subtitle
              Text(
                'Find jobs or hire talent easily',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),

              const SizedBox(height: 40),

              /// Job Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Login(selectedRole: 'JOB_SEEKER')),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.work, color: Colors.white, size: 25),
                      SizedBox(width: 10),
                      Text("I'm Looking for a job", style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// Hiring Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Login(selectedRole: 'POSTER')),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.group_add, color: Colors.white, size: 25),
                      SizedBox(width: 10),
                      Text("I'm Hiring", style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              /// Register Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(fontSize: 15, color: Colors.blueGrey),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Registration()),
                      );
                    },
                    child: Text(
                      'Register',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}