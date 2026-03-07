import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
///import 'package:intl/intl.dart' as intl;

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {

  //declare local variables
  String? email;
  String? password;
  String? confirmPassword;
  String selectedRole = "jobseeker";

  // variable for error message
  String? passwordError;
  String? confirmPasswordError;
  String? emailError;

  // variable of password visibility
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  //controller
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  //set focus
  final focusNode = FocusNode();

  //form controller
  final _formKey = GlobalKey<FormState>();

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

                /// Back icon (return main page)
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
                Text(
                  'Create Account',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)
                ),

                /// Subtitle
                Text(
                  "Join us and start connecting with opportunities today",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blueGrey,
                  ),
                ),

                const SizedBox(height: 40),

                /// Select role heading
                Text(
                  "Role",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                /// Select role button (job seeker / employer)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /// Job Seeker Button
                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          /// change color based on the selection
                          backgroundColor: selectedRole == "jobseeker" ? Colors.blue : Colors.grey[300],
                          foregroundColor: selectedRole == "jobseeker" ? Colors.white : Colors.black,
                          elevation: 5,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
                        ),
                        onPressed: () {
                          setState(() {selectedRole = "jobseeker";});
                          },
                        child: const Text(
                          "Job Seeker",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(width: 15),

                    /// Employer Button
                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedRole == "employer" ? Colors.blue : Colors.grey[300],
                          foregroundColor: selectedRole == "employer" ? Colors.white : Colors.black,
                          elevation: 5,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() {selectedRole = "employer";});
                          },
                        child: const Text(
                          "Employer",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// Email column heading
                Text(
                  "Email",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
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

                const SizedBox(height: 5),

                // Error message
                if (emailError != null)
                  Text(
                    emailError!,
                    style: TextStyle(fontSize: 15, color: Colors.red),
                  ),

                const SizedBox(height: 20),

                /// Password heading
                Text(
                  "Password",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: passwordCtrl,
                  /// password visibility
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon( isPasswordVisible ? Icons.visibility : Icons.visibility_off,),
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
                    // Clear error when user types
                    setState(() {
                      passwordError = null;
                    });
                  },
                ),

                const SizedBox(height: 5),

                // Password criteria text
                Text(
                  'At least 8 characters with uppercase, lowercase, and numbers',
                  style: TextStyle(fontSize: 15, color: Colors.blueGrey),
                ),

                // Error message
                if (passwordError != null)
                  Text(
                    passwordError!,
                    style: TextStyle(fontSize: 15, color: Colors.red),
                  ),

                const SizedBox(height: 20),

                /// Confirm password heading
                Text(
                  "Confirm Password",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: confirmPasswordCtrl,
                  /// confirm password visibility
                  obscureText: !isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,),
                      onPressed: () {
                        setState(() {
                          isConfirmPasswordVisible = !isConfirmPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                    onChanged: (_) {
                      // Clear error when user types
                      setState(() {
                       confirmPasswordError = null;
                      });
                  },
                ),

                const SizedBox(height: 5),

                // Error message
                if (confirmPasswordError != null)
                  Text(
                    confirmPasswordError!,
                    style: TextStyle(fontSize: 15, color: Colors.red),
                  ),

                const SizedBox(height: 25),

                /// create account button
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
                    onPressed: () {

                      setState(() {
                        emailError = null;
                        passwordError = null;
                        confirmPasswordError = null;
                      });

                      bool isValid = true;

                      /// Email validation
                      String email = emailCtrl.text.trim();
                      String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
                      RegExp emailRegex = RegExp(emailPattern);

                      if (email.isEmpty) {
                        emailError = "Email is required";
                        isValid = false;
                      } else if (!emailRegex.hasMatch(email)) {
                        emailError = "Email format invalid";
                        isValid = false;
                      }

                      /// Password validation
                      String password = passwordCtrl.text;
                      String passwordPattern = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$';
                      RegExp passwordRegex = RegExp(passwordPattern);

                      if (password.isEmpty) {
                        passwordError = "Password is required";
                        isValid = false;
                      } else if (!passwordRegex.hasMatch(password)) {
                        passwordError = "Password format invalid";
                        isValid = false;
                      }

                      String confirmPassword = confirmPasswordCtrl.text;

                      /// Confirm password validation
                      if (confirmPassword.isEmpty) {
                        confirmPasswordError = "Confirm your password";
                        isValid = false;
                      } else if (confirmPassword != password) {
                        confirmPasswordError = "Passwords do not match";
                        isValid = false;
                      }

                      // Refresh UI
                      setState(() {});

                      if (isValid) {
                        print("Form is valid! Proceed to create account");
                      }
                    },
                    child: const Text(
                      "Create Account",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// Login Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?",
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
                        'Login',
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
      ),
    );
  }
}
