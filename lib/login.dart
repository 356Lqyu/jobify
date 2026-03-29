import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jobify/navigation_menu.dart';
import 'package:jobify/registration.dart';
import 'package:jobify/user.dart';
import 'package:jobify/user_provider.dart';
import 'package:provider/provider.dart';
///import 'package:intl/intl.dart' as intl;

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {

  //declare local variables
  String? email;
  String? password;

  // variable for error message
  String? passwordError;
  String? emailError;

  // variable of password visibility
  bool isPasswordVisible = false;

  //controller
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

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
                    'Login',
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
                    onPressed: () {

                      setState(() {
                        emailError = null;
                        passwordError = null;
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

                      String password = passwordCtrl.text;

                      if (password.isEmpty) {
                        passwordError = "Password is required";
                        isValid = false;
                      }

                      // Refresh UI
                      setState(() {});

                      if (isValid) {
                        String email = emailCtrl.text.trim();
                        String password = passwordCtrl.text;

                        final userProvider = Provider.of<UserProvider>(context, listen: false);

                        User? foundUser;

                        try {
                          foundUser = userProvider.registeredUsers.firstWhere(
                                (user) => user.email == email && user.password == password,
                          );
                        } catch (e) {
                          foundUser = null;
                        }

                        if (foundUser != null) {
                          // Login success
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Login Successful !", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          emailCtrl.clear();
                          passwordCtrl.clear();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => NavigationMenu(user: foundUser!)),
                                (route) => false,
                          );

                        } else {
                          // Login failed
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Invalid email or password !", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }

                    },
                    child: const Text(
                      "Login",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

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
      ),
    );
  }
}
