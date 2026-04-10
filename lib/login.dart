import 'package:flutter/material.dart';
import 'package:jobify/auth/auth_service.dart';
import 'package:jobify/home.dart';
import 'package:jobify/registration.dart';
import 'package:jobify/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final authService = AuthService();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  String? passwordError;
  String? emailError;
  bool isPasswordVisible = false;
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();

  void login() async {
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text;

    setState(() {
      emailError = null;
      passwordError = null;
    });

    bool isValid = true;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

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

    if (!isValid) return;

    setState(() => isLoading = true);

    try {
      final res = await authService.signInWithEmailAndPassword(email, password);
      if (res.user == null) throw Exception("Invalid login");

      final supabase = Supabase.instance.client;
      final userId = res.user!.id;

      // ✅ Fetch ALL required fields for the User model
      final userData = await supabase
          .from('users')
          .select('user_id, role, fullname, phone, profile_image_url, created_at, updated_at, email')
          .eq('user_id', userId)
          .single();

      final user = User.fromJson(userData);

      if (!mounted) return;

      emailCtrl.clear();
      passwordCtrl.clear();

      // ✅ Navigate to HomePage – role‑based UI is handled inside HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(user: user)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login error: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
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
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Login',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Join us and start connecting with opportunities today",
                  style: TextStyle(fontSize: 15, color: Colors.blueGrey),
                ),
                const SizedBox(height: 40),
                const Text("Email", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    hintText: "your@email.com",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (emailError != null) Text(emailError!, style: const TextStyle(fontSize: 15, color: Colors.red)),
                const SizedBox(height: 20),
                const Text("Password", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => setState(() => passwordError = null),
                ),
                if (passwordError != null) Text(passwordError!, style: const TextStyle(fontSize: 15, color: Colors.red)),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isLoading ? null : login,
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Login", style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?", style: TextStyle(fontSize: 15, color: Colors.blueGrey)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Registration())),
                      child: const Text('Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
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