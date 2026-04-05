import 'package:flutter/material.dart';

class User {
  final String userId;
  final String role;
  final String fullname;
  final String? phone;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String email;

  User({
    required this.userId,
    required this.role,
    required this.fullname,
    this.phone,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'].toString(),
      role: json['role'] as String,
      fullname: json['fullname'] as String,
      phone: json['phone'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      email: json['email'] as String,
    );
  }

  @override
  String toString() {
    return 'Email: $email, Fullname: $fullname, Phone: $phone, ProfileRole: $role';
  }
}