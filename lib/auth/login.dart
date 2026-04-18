import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jobify/auth/auth_service.dart';
import 'package:jobify/home.dart';
import 'package:jobify/auth/registration.dart';
import 'package:jobify/users/users.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../data/user_repository.dart';
import 'forgot_password.dart';
import 'package:provider/provider.dart';
import '../users/user_provider.dart';

/// Login screen with role-based authentication
class Login extends StatefulWidget {
  final String? selectedRole;
  const Login({super.key, this.selectedRole});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final authService = AuthService();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  String? passwordError;
  String? emailError;
  String? roleError;

  bool isPasswordVisible = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  void _toggleAccountType() {
    String? newRole;
    if (widget.selectedRole == 'JOB_SEEKER') {
      newRole = 'POSTER';
    } else if (widget.selectedRole == 'POSTER') {
      newRole = 'JOB_SEEKER';
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Login(selectedRole: newRole),
      ),
    );
  }

  void login() async {
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text;

    setState(() {
      emailError = null;
      passwordError = null;
      roleError = null;
    });

    bool isValid = true;

    // Email validation
    RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

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
      final res = await authService.signInWithEmailAndPassword(email, password);

      if (res.user == null) {
        throw Exception("Invalid login");
      }

      final authUser = res.user!;
      if (authUser.emailConfirmedAt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please verify your email address before logging in."),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final supabase = Supabase.instance.client;
      final userId = res.user!.id;

      final userData = await supabase
          .from('users')
          .select('user_id, role, fullname, profile_image_url, created_at, updated_at, email, phone')
          .eq('user_id', userId)
          .maybeSingle();

      Users user;

      if (userData == null) {
        // Create user record if missing
        await supabase.from('users').insert({
          'user_id': userId,
          'role': 'JOB_SEEKER',
          'email': email,
          'fullname': email.split('@')[0],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        final newUserData = await supabase
            .from('users')
            .select()
            .eq('user_id', userId)
            .single();

        user = Users.fromJson(newUserData);
      } else {
        user = Users.fromJson(userData);
      }

      final userRole = user.role;

      // Check role match
      if (widget.selectedRole != null && widget.selectedRole!.isNotEmpty) {
        if (userRole != widget.selectedRole) {
          String expectedRole = widget.selectedRole == 'JOB_SEEKER' ? 'Job Seeker' : 'Employer';
          String actualRole = userRole == 'JOB_SEEKER' ? 'Job Seeker' : 'Employer';

          await authService.signOut();

          setState(() {
            roleError = "This account is registered as a $actualRole.\n"
                "Please use the \"I'm ${expectedRole == 'Job Seeker' ? 'Looking for a job' : 'Hiring'}\" button to login.";
          });
          return;
        }
      }

      // Cache profile data
      final userRepo = UserRepository();
      await userRepo.cacheFullProfileAfterLogin(userId);

      // Update provider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUser(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login Successful!"),backgroundColor: Colors.green),
        );

        // Use pushReplacement to prevent back navigation to login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(user: user)),
        );
      }
    } catch (e) {
      print('Login error details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login error: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = "Login";
    String subtitle = "Join us and start connecting with opportunities today";

    if (widget.selectedRole == 'JOB_SEEKER') {
      title = "Job Seeker Login";
      subtitle = "Find your dream job";
    } else if (widget.selectedRole == 'POSTER') {
      title = "Employer Login";
      subtitle = "Find the best talent for your company";
    }

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
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  title,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),

                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.blueGrey,
                  ),
                ),

                const SizedBox(height: 40),

                if (roleError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            roleError!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

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
                            builder: (context) => Registration(
                              selectedRole: widget.selectedRole == 'JOB_SEEKER'
                                  ? 'jobseeker'
                                  : 'employer',
                            ),
                          ),
                        );
                      },
                      child: const Text(
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

                if (widget.selectedRole != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _toggleAccountType,
                        icon: Icon(
                          Icons.swap_horiz,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                        label: Text(
                          widget.selectedRole == 'JOB_SEEKER'
                              ? 'Login as Employer instead'
                              : 'Login as Job Seeker instead',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                if (widget.selectedRole == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Login as:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const Login(selectedRole: 'JOB_SEEKER'),
                                  ),
                                );
                              },
                              icon: Icon(Icons.person_outline, size: 16, color: Colors.green.shade700),
                              label: Text(
                                'Job Seeker',
                                style: TextStyle(color: Colors.green.shade700),
                              ),
                            ),
                            const SizedBox(width: 16),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const Login(selectedRole: 'POSTER'),
                                  ),
                                );
                              },
                              icon: Icon(Icons.business_outlined, size: 16, color: Colors.blue.shade700),
                              label: Text(
                                'Employer',
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}