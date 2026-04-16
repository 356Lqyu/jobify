import 'package:flutter/material.dart';

class Users {
  final String userId;
  final String role;
  final String fullname;
  final String? phone;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String email;

  Users({
    required this.userId,
    required this.role,
    required this.fullname,
    this.phone,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.email,
  });

  factory Users.fromJson(Map<String, dynamic> json) {
    return Users(
      userId: json['user_id'].toString(),
      role: (json['role'] ?? 'JOB_SEEKER').toString(),
      fullname: (json['fullname'] ?? json['company_name'] ?? '').toString(),
      phone: json['phone']?.toString(), // Allow null
      profileImageUrl: json['profile_image_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      email: (json['email'] ?? '').toString(),
    );
  }

  @override
  String toString() {
    return 'Email: $email, Fullname: $fullname, Phone: $phone, ProfileRole: $role';
  }
}
