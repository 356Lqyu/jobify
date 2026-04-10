import 'package:flutter/material.dart';
import 'package:jobify/login.dart';
import 'package:jobify/user.dart' as local_user;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_service.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {

  final authService = AuthService();

  String selectedRole = "jobseeker";

  String? passwordError;
  String? confirmPasswordError;
  String? emailError;

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();


  Future<void> register() async {
    setState(() {
      emailError = null;
      passwordError = null;
      confirmPasswordError = null;
    });

    bool isValid = true;

    String email = emailCtrl.text.trim();
    String password = passwordCtrl.text;
    String confirmPassword = confirmPasswordCtrl.text;

    /// Email validation
    String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
    RegExp emailRegex = RegExp(emailPattern);

    if (email.isEmpty) {
      emailError = "Email is required";
      isValid = false;
    } else if (!emailRegex.hasMatch(email)) {
      emailError = "Invalid email format";
      isValid = false;
    }

    /// Password validation
    String passwordPattern = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$';
    RegExp passwordRegex = RegExp(passwordPattern);

    if (password.isEmpty) {
      passwordError = "Password is required";
      isValid = false;
    } else if (!passwordRegex.hasMatch(password)) {
      passwordError = "Min 8 chars, uppercase, lowercase & number";
      isValid = false;
    }

    /// Confirm password validation
    if (confirmPassword.isEmpty) {
      confirmPasswordError = "Confirm password required";
      isValid = false;
    } else if (confirmPassword != password) {
      confirmPasswordError = "Passwords do not match";
      isValid = false;
    }

    setState(() {});

    if (!isValid) return;

    final supabase = Supabase.instance.client;

    try {
      final res = await authService
          .signUpWithEmailAndPassword(email, password);

      final user = res.user;
      if (user == null) throw Exception("Signup failed");

      await supabase.from('users').insert({
        'user_id': user.id,
        'role': selectedRole == "jobseeker"
            ? 'JOB_SEEKER'
            : 'POSTER',
        'fullname': '',
        'email': email,
      });

      if (selectedRole == "jobseeker") {
        await supabase.from('job_seeker_profile').insert({
          'user_id': user.id,
        });
      } else {
        await supabase.from('company_profile').insert({
          'user_id': user.id,
          'company_name': '',
          'location': '',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful")),
      );

      await Future.delayed(const Duration(seconds: 1));

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Register error: $e")),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 30),

                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),

                const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),

                const Text(
                  "Join us and start connecting with opportunities today",
                  style: TextStyle(fontSize: 15, color: Colors.blueGrey),
                ),

                const SizedBox(height: 40),

                const Text(
                  "Role",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          selectedRole == "jobseeker"
                              ? Colors.blue
                              : Colors.grey[300],
                          foregroundColor:
                          selectedRole == "jobseeker"
                              ? Colors.white
                              : Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedRole = "jobseeker";
                          });
                        },
                        child: const Text("Job Seeker"),
                      ),
                    ),

                    const SizedBox(width: 15),

                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          selectedRole == "employer"
                              ? Colors.blue
                              : Colors.grey[300],
                          foregroundColor:
                          selectedRole == "employer"
                              ? Colors.white
                              : Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedRole = "employer";
                          });
                        },
                        child: const Text("Employer"),
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 20),

                const Text("Email",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),

                const SizedBox(height: 8),

                TextFormField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    hintText: "your@email.com",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                if (emailError != null)
                  Text(emailError!,
                      style:
                      const TextStyle(color: Colors.red, fontSize: 14)),

                const SizedBox(height: 20),

                const Text("Password",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),

                const SizedBox(height: 8),

                TextFormField(
                  controller: passwordCtrl,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const Text(
                  'At least 8 characters with uppercase, lowercase, and number',
                  style: TextStyle(color: Colors.blueGrey),
                ),

                if (passwordError != null)
                  Text(passwordError!,
                      style:
                      const TextStyle(color: Colors.red, fontSize: 14)),

                const SizedBox(height: 20),

                const Text("Confirm Password",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),

                const SizedBox(height: 8),

                TextFormField(
                  controller: confirmPasswordCtrl,
                  obscureText: !isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          isConfirmPasswordVisible =
                          !isConfirmPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                if (confirmPasswordError != null)
                  Text(confirmPasswordError!,
                      style:
                      const TextStyle(color: Colors.red, fontSize: 14)),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: register,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text("Create Account"),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    const Text("Already have an account?"),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Login()),
                        );
                      },
                      child: const Text("Login"),
                    )

                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}