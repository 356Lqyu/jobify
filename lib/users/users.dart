import 'package:flutter/material.dart';

class Users {
  final String userId;
  final String role;     // JOB_SEEKER or POSTER
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

  // create users object from JSOn map
  factory Users.fromJson(Map<String, dynamic> json) {
    return Users(
      userId: json['user_id'].toString(),
      role: (json['role'] ?? 'JOB_SEEKER').toString(),
      fullname: (json['fullname'] ?? json['company_name'] ?? '').toString(),   // if fullname missing , then use the company name
      phone: json['phone']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      email: (json['email'] ?? '').toString(),
    );
  }

  // convert the users object to JSON map fro db operation
  // use when insert/update record in supabase & caching user data in SQLite & pass user data between app component
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role': role,
      'fullname': fullname,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'email': email,
    };
  }

  // create copy of the Users object with optional field overrides
  Users copyWith({
    String? userId,
    String? role,
    String? fullname,
    String? phone,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? email,
  }) {
    return Users(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      fullname: fullname ?? this.fullname,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      email: email ?? this.email,
    );
  }

  @override
  String toString() {
    return 'Email: $email, Fullname: $fullname, Phone: $phone, Role: $role';
  }
}
