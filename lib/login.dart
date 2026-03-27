import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jobify/auth/auth_service.dart';
import 'package:jobify/edit_profile_page.dart';
import 'package:jobify/registration.dart';
import 'package:jobify/setting_page.dart';
import 'package:jobify/user.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'company_profile_page.dart';
///import 'package:intl/intl.dart' as intl;

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {

  //get auth service
  final authService = AuthService();

  //controller
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  // variable for error message
  String? passwordError;
  String? emailError;

  // variable of password visibility
  bool isPasswordVisible = false;

  //set focus
  final focusNode = FocusNode();

  //form controller
  final _formKey = GlobalKey<FormState>();

  // Login function
  void login() async {
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text;

    // Reset previous errors
    setState(() {
      emailError = null;
      passwordError = null;
    });

    bool isValid = true;

    // Email validation
    RegExp emailRegex =
    RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (email.isEmpty) {
      emailError = "Email is required";
      isValid = false;
    } else if (!emailRegex.hasMatch(email)) {
      emailError = "Email format invalid";
      isValid = false;
    }

    if (password.isEmpty) {
      passwordError = "Password is required";
      isValid = false;
    }

    setState(() {});
    if (!isValid) return;


    try {
      final res = await authService
          .signInWithEmailAndPassword(email, password);

      if (res.user == null) {
        throw Exception("Invalid login");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Successful!")),
      );

      emailCtrl.clear();
      passwordCtrl.clear();

      // Fetch role from 'users' table
      final supabase = Supabase.instance.client;
      final userId = res.user!.id;

      final userData = await supabase
          .from('users')
          .select('role')
          .eq('user_id', userId)
          .single();

      final role = userData['role'] as String?;

      if (role == 'POSTER') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CompanyProfilePage(companyId: userId),
          ),
        );
      } else {
        // Default: Job seeker profile
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const SettingPage(),
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),

                /// Back icon
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),

                const SizedBox(height: 5),

                /// Title
                const Text(
                  'Login',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),

                /// Subtitle
                const Text(
                  "Join us and start connecting with opportunities today",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blueGrey,
                  ),
                ),

                const SizedBox(height: 40),

                /// Email heading
                const Text(
                  "Email",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    hintText: "your@email.com",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (emailError != null)
                  Text(
                    emailError!,
                    style: const TextStyle(fontSize: 15, color: Colors.red),
                  ),
                const SizedBox(height: 20),

                /// Password heading
                const Text(
                  "Password",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {
                      passwordError = null;
                    });
                  },
                ),
                if (passwordError != null)
                  Text(
                    passwordError!,
                    style: const TextStyle(fontSize: 15, color: Colors.red),
                  ),
                const SizedBox(height: 25),

                /// Login button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: login,
                    child: const Text(
                      "Login",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                /// Register row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(fontSize: 15, color: Colors.blueGrey),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => Registration()),
                        );
                      },
                      child: const Text(
                        'Register',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}