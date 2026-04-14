import 'package:flutter/material.dart';
import 'package:jobify/login.dart';
import 'package:jobify/users.dart';
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
  String? companyNameError;
  String? locationError;
  String? fullnameError;
  String? phoneError;
  String? companyPhoneError;

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  // Additional fields for Employer registration
  final companyNameCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final fullnameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final companyPhoneCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();


  Future<void> register() async {
    setState(() {
      emailError = null;
      passwordError = null;
      confirmPasswordError = null;
      companyNameError = null;
      locationError = null;
      fullnameError = null;
      phoneError = null;
    });

    bool isValid = true;

    String email = emailCtrl.text.trim();
    String password = passwordCtrl.text;
    String confirmPassword = confirmPasswordCtrl.text;
    String companyName = companyNameCtrl.text.trim();
    String location = locationCtrl.text.trim();
    String fullname = fullnameCtrl.text.trim();
    String phone = phoneCtrl.text.trim();

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

    /// Job Seeker-specific validation
    if (selectedRole == "jobseeker") {
      if (fullname.isEmpty) {
        fullnameError = "Full name is required";
        isValid = false;
      }
      if (phone.isEmpty) {
        phoneError = "Phone number is required";
        isValid = false;
      } else if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(phone)) {
        phoneError = "Please enter a valid phone number";
        isValid = false;
      }
    }

    /// Employer-specific validation
    if (selectedRole == "employer") {
      if (companyName.isEmpty) {
        companyNameError = "Company name is required";
        isValid = false;
      }
      if (location.isEmpty) {
        locationError = "Company location is required";
        isValid = false;
      }
      if (companyPhoneCtrl.text.trim().isNotEmpty) {
        if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(companyPhoneCtrl.text.trim())) {
          companyPhoneError = "Please enter a valid phone number";
          isValid = false;
        }
      }
    }

    setState(() {});

    if (!isValid) return;

    final supabase = Supabase.instance.client;

    try {
      final res = await authService
          .signUpWithEmailAndPassword(email, password);

      final user = res.user;
      if (user == null) throw Exception("Signup failed");

      // Insert into users table
      if (selectedRole == "jobseeker") {
        await supabase.from('users').insert({
          'user_id': user.id,
          'role': 'JOB_SEEKER',
          'email': email,
          'fullname': fullname,
          'phone': phone,
        });
      } else {
        await supabase.from('users').insert({
          'user_id': user.id,
          'role': 'POSTER',
          'email': email,
          'phone': phone,
        });
      }

      // Insert into role-specific tables
      if (selectedRole == "jobseeker") {
        await supabase.from('job_seeker_profile').insert({
          'user_id': user.id,
          'date_of_birth': null,
          'gender': null,
          'address': null,
          'bio': null,
        });
      } else {
        // For employer, company_name and location are required (NOT NULL in schema)
        await supabase.from('company_profile').insert({
          'user_id': user.id,
          'company_name': companyName,
          'location': location,
          'company_description': '',  // Optional, can be empty
          'industry': '',              // Optional, can be empty
          'company_size': '',          // Optional, can be empty
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful! Please login.")),
      );

      await Future.delayed(const Duration(seconds: 1));

      // Navigate to login page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
            (route) => false,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Register error: $e")),
      );
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    companyNameCtrl.dispose();
    locationCtrl.dispose();
    fullnameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

                        const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          "Join us and start connecting with opportunities today",
                          style: TextStyle(fontSize: 15, color: Colors.blueGrey),
                        ),

                        const SizedBox(height: 30),

                        const Text(
                          "Role",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 10),

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
                                  setState(() {
                                    selectedRole = "jobseeker";
                                  });
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
                                  setState(() {
                                    selectedRole = "employer";
                                  });
                                },
                                child: const Text("Employer"),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 25),

                        // ================================================
                        // ACCOUNT INFORMATION SECTION
                        // ================================================
                        const Text(
                          "Account Information",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),

                        // Email field
                        const Text("Email",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(emailError!,
                                style: const TextStyle(color: Colors.red, fontSize: 14)),
                          ),

                        const SizedBox(height: 20),

                        // Password field
                        const Text("Password",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'At least 8 characters with uppercase, lowercase, and number',
                            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                          ),
                        ),
                        if (passwordError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(passwordError!,
                                style: const TextStyle(color: Colors.red, fontSize: 14)),
                          ),

                        const SizedBox(height: 20),

                        // Confirm Password field
                        const Text("Confirm Password",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                                  isConfirmPasswordVisible = !isConfirmPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        if (confirmPasswordError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(confirmPasswordError!,
                                style: const TextStyle(color: Colors.red, fontSize: 14)),
                          ),

                        // ================================================
                        // JOB SEEKER SPECIFIC FIELDS
                        // ================================================
                        if (selectedRole == "jobseeker") ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),

                          const Text(
                            "Personal Information",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),

                          // Full Name field
                          const Text("Full Name *",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: fullnameCtrl,
                            decoration: InputDecoration(
                              hintText: "Enter your full name",
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          if (fullnameError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(fullnameError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14)),
                            ),
                          const Padding(
                            padding: EdgeInsets.only(top: 4, left: 12),
                            child: Text(
                              'Your full name as it appears on your resume',
                              style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Phone Number field
                          const Text("Phone Number *",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: "e.g., +60 12 345 6789",
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          if (phoneError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(phoneError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14)),
                            ),
                          const Padding(
                            padding: EdgeInsets.only(top: 4, left: 12),
                            child: Text(
                              'Include country code for international numbers',
                              style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                            ),
                          ),
                        ],

                        // ================================================
                        // EMPLOYER SPECIFIC FIELDS
                        // ================================================

                        // Employer-specific fields
                        if (selectedRole == "employer") ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),

                          const Text(
                            "Company Information",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),

                          // Company Name field
                          const Text("Company Name *",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: companyNameCtrl,
                            decoration: InputDecoration(
                              hintText: "Enter your company name",
                              prefixIcon: const Icon(Icons.business),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          if (companyNameError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(companyNameError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14)),
                            ),

                          const SizedBox(height: 16),



                          const Text("Company Phone",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: "e.g., +60 3 1234 5678",
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 4, left: 12),
                            child: Text(
                              'Official company phone number (optional)',
                              style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                            ),
                          ),
                          if (phoneError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(phoneError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14)),
                            ),

                          const SizedBox(height: 16),



                          // Location field
                          const Text("Location *",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: locationCtrl,
                            decoration: InputDecoration(
                              hintText: "e.g., Kuala Lumpur, Malaysia",
                              prefixIcon: const Icon(Icons.location_on),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          if (locationError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(locationError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14)),
                            ),
                        ],

                        // Optional note for Job Seekers
                        if (selectedRole == "jobseeker") ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "You can add other details in your profile after registration.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 30),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: register,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text("Create Account"),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // Login link
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