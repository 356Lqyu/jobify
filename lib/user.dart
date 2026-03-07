import 'package:flutter/material.dart';

class User {
  String email;
  String password;
  String role;

  // Job Seeker fields
  String? name;
  String? phoneNumber;
  String? locationJS; // Job seeker location
  List<String>? skills;
  List<String>? workExperience;
  Image? resume;

  // Employer fields
  String? companyName;
  List<String>? industry;
  List<String>? companySize;
  String? locationEMP; // Employer location
  String? description;

  // Constructor
  User({required this.email, required this.password, required this.role});

  @override
  String toString() {
    return 'Email: $email, Password: $password, Role: $role';
  }
}
