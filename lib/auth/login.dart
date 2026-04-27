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

  late String selectedRole;

  @override
  void initState() {
    super.initState();
    // Initialize selected role based on widget parameter
    if (widget.selectedRole == 'JOB_SEEKER') {
      selectedRole = 'jobseeker';
    } else if (widget.selectedRole == 'POSTER') {
      selectedRole = 'employer';
    } else {
      selectedRole = 'jobseeker'; // default
    }
  }

  void _toggleRole(String role) {
    if (selectedRole == role) return;

    setState(() {
      selectedRole = role;
    });

    // Navigate to the same login screen with new role
    String newRole = role == 'jobseeker' ? 'JOB_SEEKER' : 'POSTER';
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => Login(selectedRole: newRole),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
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
      // check authentication user
      final res = await authService.signInWithEmailAndPassword(email, password);

      if (res.user == null) {
        throw Exception("Invalid login");
      }

      final authUser = res.user!;

      // check if email is confirmed
      if (authUser.emailConfirmedAt == null) {
        await authService.signOut(); // Sign out immediately
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please verify your email address before logging in."),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // fetch user role from db
      final supabase = Supabase.instance.client;
      final userId = res.user!.id;

      final userData = await supabase
          .from('users')
          .select('user_id, role, fullname, profile_image_url, created_at, updated_at, email, phone')
          .eq('user_id', userId)
          .maybeSingle();

      Users user;

      if (userData == null) {
        // Create user record if missing (fallback)
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
      final expectedRole = selectedRole == 'jobseeker' ? 'JOB_SEEKER' : 'POSTER';

      // Check if role match the login page
      if (userRole != expectedRole) {
        String actualRole = userRole == 'JOB_SEEKER' ? 'Job Seeker' : 'Employer';
        String expectedRoleName = selectedRole == 'jobseeker' ? 'Job Seeker' : 'Employer';

        // sign out immediately since role doesn't match
        await authService.signOut();

        passwordCtrl.clear();

        setState(() {
          roleError = "This account is registered as a $actualRole.\n"
              "Please switch to $actualRole login mode.";
        });
        return;
      }

      // login success , Cache profile data and proceed to home page
      final userRepo = UserRepository();
      await userRepo.cacheFullProfileAfterLogin(userId);

      // Update provider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUser(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login Successful!"),
            backgroundColor: Colors.green,
          ),
        );

        // Use pushReplacement to prevent back navigation to login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(user: user)),
        );
      }
    } catch (e) {
      print('Login error details: $e');

      // Handle authentication errors (wrong password, user not found, etc.)
      String errorMessage = e.toString();
      if (errorMessage.toLowerCase().contains('invalid login credentials')) {
        errorMessage = "Invalid email or password. Please try again.";
      } else if (errorMessage.toLowerCase().contains('user already exists')) {
        errorMessage = "Account already exists. Please login instead.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = "Login";
    String subtitle = "Join us and start connecting with opportunities today";

    if (selectedRole == 'jobseeker') {
      title = "Job Seeker Login";
      subtitle = "Find your dream job";
    } else if (selectedRole == 'employer') {
      title = "Employer Login";
      subtitle = "Find the best talent for your company";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// Back icon
                        IconButton(
                          icon: const Icon(Icons.arrow_back, size: 28),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),

                        const SizedBox(height: 5),

                        Text(
                          title,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.blueGrey,
                          ),
                        ),

                        const SizedBox(height: 30),

                        /// Role toggle buttons (similar to registration)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedRole == "jobseeker"
                                      ? Colors.blue
                                      : Colors.grey[300],
                                  foregroundColor: selectedRole == "jobseeker"
                                      ? Colors.white
                                      : Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  _toggleRole("jobseeker");
                                },
                                child: const Text("Job Seeker"),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedRole == "employer"
                                      ? Colors.blue
                                      : Colors.grey[300],
                                  foregroundColor: selectedRole == "employer"
                                      ? Colors.white
                                      : Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  _toggleRole("employer");
                                },
                                child: const Text("Employer"),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

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

                        /// Email field
                        const Text(
                          "Email",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: "your@email.com",
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        if (emailError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              emailError!,
                              style: const TextStyle(fontSize: 13, color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 20),

                        /// Password field
                        const Text(
                          "Password",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: !isPasswordVisible,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
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
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onChanged: (_) {
                            setState(() {
                              passwordError = null;
                            });
                          },
                        ),
                        if (passwordError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              passwordError!,
                              style: const TextStyle(fontSize: 13, color: Colors.red),
                            ),
                          ),

                        const SizedBox(height: 12),

                        /// Forgot Password
                        Align(
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

                        const SizedBox(height: 20),

                        /// Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: login,
                            child: const Text(
                              "Login",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Registration(
                                      selectedRole: selectedRole,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
