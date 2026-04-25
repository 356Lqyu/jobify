import 'package:flutter/material.dart';
import 'dart:convert';

enum PostType { post, job, tip, event, news }

extension PostTypeLabel on PostType {
  String get label {
    switch (this) {
      case PostType.post:  return 'Post';
      case PostType.job:   return 'Hiring';
      case PostType.tip:   return 'Tip';
      case PostType.event: return 'Event';
      case PostType.news:  return 'News';
    }
  }

  Color get color {
    switch (this) {
      case PostType.post:  return const Color(0xFF2563EB);
      case PostType.job:   return const Color(0xFF8B5CF6);
      case PostType.tip:   return const Color(0xFF10B981);
      case PostType.event: return const Color(0xFFF59E0B);
      case PostType.news:  return const Color(0xFFEC4899);
    }
  }

  IconData get icon {
    switch (this) {
      case PostType.post:  return Icons.chat_bubble_outline;
      case PostType.job:   return Icons.work_outline;
      case PostType.tip:   return Icons.lightbulb_outline;
      case PostType.event: return Icons.event_outlined;
      case PostType.news:  return Icons.article_outlined;
    }
  }
}

PostType postTypeFromString(String? s) {
  return PostType.values.firstWhere(
        (e) => e.name == (s ?? 'post').toLowerCase(),
    orElse: () => PostType.post,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FEED POST MODEL
// ─────────────────────────────────────────────────────────────────────────────

class FeedPost {
  final String postId;
  final String userId;
  final String? companyId;
  final String? jobId;
  final String content;
  final PostType postType;
  final List<String> hashtags;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String authorName;
  final String authorAvatar;
  final String authorSubtitle;
  final bool isVerified;

  // Mutable interaction state
  int likeCount;
  int commentCount;
  bool isLiked;
  bool isSaved;
  bool isFollowing;

  // Linked job when postType == job
  JobPost? linkedJob;

  FeedPost({
    required this.postId,
    required this.userId,
    this.companyId,
    this.jobId,
    required this.content,
    required this.postType,
    required this.hashtags,
    required this.mediaUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.authorName,
    this.authorAvatar = '',
    this.authorSubtitle = '',
    this.isVerified = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isFollowing = false,
    this.linkedJob,
  });

  // ── SQLite ─────────────────────────────────────────────────────────────────

  factory FeedPost.fromLocalDb(Map<String, dynamic> map) {
    List<String> _decode(String? raw) {
      if (raw == null || raw.isEmpty) return [];
      try { return List<String>.from(jsonDecode(raw) as List); } catch (_) { return []; }
    }
    return FeedPost(
      postId:         map['post_id'] as String,
      userId:         map['user_id'] as String,
      companyId:      map['company_id'] as String?,
      jobId:          map['job_id'] as String?,
      content:        map['content'] as String? ?? '',
      postType:       postTypeFromString(map['post_type'] as String?),
      hashtags:       _decode(map['hashtags'] as String?),
      mediaUrls:      _decode(map['media_urls'] as String?),
      createdAt:      DateTime.parse(map['created_at'] as String),
      updatedAt:      DateTime.parse(map['updated_at'] as String),
      authorName:     map['author_name'] as String? ?? '',
      authorAvatar:   map['author_avatar'] as String? ?? '',
      authorSubtitle: map['author_subtitle'] as String? ?? '',
      isVerified:     (map['is_verified'] as int? ?? 0) == 1,
      likeCount:      map['like_count'] as int? ?? 0,
      commentCount:   map['comment_count'] as int? ?? 0,
      isLiked:        (map['is_liked'] as int? ?? 0) == 1,
      isSaved:        (map['is_saved'] as int? ?? 0) == 1,
      isFollowing:    (map['is_following'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toLocalDbMap() => {
    'post_id':        postId,
    'user_id':        userId,
    'company_id':     companyId,
    'job_id':         jobId,
    'content':        content,
    'post_type':      postType.name,
    'hashtags':       jsonEncode(hashtags),
    'media_urls':     jsonEncode(mediaUrls),
    'created_at':     createdAt.toIso8601String(),
    'updated_at':     updatedAt.toIso8601String(),
    'author_name':    authorName,
    'author_avatar':  authorAvatar,
    'author_subtitle':authorSubtitle,
    'is_verified':    isVerified ? 1 : 0,
    'like_count':     likeCount,
    'comment_count':  commentCount,
    'is_liked':       isLiked ? 1 : 0,
    'is_saved':       isSaved ? 1 : 0,
    'is_following':   isFollowing ? 1 : 0,
  };

  String get timeAgo {
    final d = DateTime.now().difference(createdAt);
    if (d.inDays >= 365) return '${(d.inDays / 365).floor()}y ago';
    if (d.inDays >= 30)  return '${(d.inDays / 30).floor()}mo ago';
    if (d.inDays >= 1)   return '${d.inDays}d ago';
    if (d.inHours >= 1)  return '${d.inHours}h ago';
    if (d.inMinutes >= 1)return '${d.inMinutes}m ago';
    return 'just now';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST COMMENT MODEL
// ─────────────────────────────────────────────────────────────────────────────

class PostComment {
  final String commentId;
  final String postId;
  final String userId;
  final String commentText;
  final DateTime createdAt;
  final String authorName;
  final String authorAvatar;

  const PostComment({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    this.authorName  = '',
    this.authorAvatar = '',
  });

  String get timeAgo {
    final d = DateTime.now().difference(createdAt);
    if (d.inDays >= 1)   return '${d.inDays}d ago';
    if (d.inHours >= 1)  return '${d.inHours}h ago';
    if (d.inMinutes >= 1)return '${d.inMinutes}m ago';
    return 'just now';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOB POST MODEL
// ─────────────────────────────────────────────────────────────────────────────

class JobPost {
  final String jobId;
  final String companyId;
  final String createdBy;
  final String jobTitle;
  final String description;
  final String location;
  final bool remoteOption;
  final double? salaryMin;
  final double? salaryMax;
  final String jobType;
  final String jobCategory;
  final String experienceLevel;
  final int vacancyCount;
  final DateTime? applicationDeadline;
  final String status;
  final int viewCount;
  final int applicationCount;
  final DateTime createdAt;
  final List<String> imageUrls;
  final String? videoUrl;

  final String companyName;
  final String? companyLogoUrl;
  final String? companyIndustry;

  bool isSaved;

  JobPost({
    required this.jobId,
    required this.companyId,
    required this.createdBy,
    required this.jobTitle,
    required this.description,
    required this.location,
    required this.remoteOption,
    this.salaryMin,
    this.salaryMax,
    required this.jobType,
    required this.jobCategory,
    required this.experienceLevel,
    required this.vacancyCount,
    this.applicationDeadline,
    required this.status,
    required this.viewCount,
    required this.applicationCount,
    required this.createdAt,
    this.imageUrls = const [],
    this.videoUrl,
    required this.companyName,
    this.companyLogoUrl,
    this.companyIndustry,
    this.isSaved = false,
  });

  String get salaryDisplay {
    if (salaryMin == null && salaryMax == null) return 'Undisclosed';
    if (salaryMin != null && salaryMax != null) {
      return 'RM ${_fmt(salaryMin!)} – ${_fmt(salaryMax!)}';
    }
    if (salaryMin != null) return 'From RM ${_fmt(salaryMin!)}';
    return 'Up to RM ${_fmt(salaryMax!)}';
  }
  String _fmt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);

  String get timeAgo {
    final d = DateTime.now().difference(createdAt);
    if (d.inDays >= 30)  return '${(d.inDays / 30).floor()}mo ago';
    if (d.inDays >= 1)   return '${d.inDays}d ago';
    if (d.inHours >= 1)  return '${d.inHours}h ago';
    return '${d.inMinutes}m ago';
  }

  Map<String, dynamic> toMap() {
    return {
      'job_id': jobId,
      'company_id': companyId,
      'created_by': createdBy,
      'job_title': jobTitle,
      'description': description,
      'location': location,
      'remote_option': remoteOption,
      'salary_min': salaryMin,
      'salary_max': salaryMax,
      'job_type': jobType,
      'job_category': jobCategory,
      'experience_level': experienceLevel,
      'vacancy_count': vacancyCount,
      'application_deadline': applicationDeadline?.toIso8601String(),
      'status': status,
      'view_count': viewCount,
      'application_count': applicationCount,
      'created_at': createdAt.toIso8601String(),
      'image_urls': imageUrls,  // already List<String>
      'video_url': videoUrl,
      'company_name': companyName,
      'company_logo_url': companyLogoUrl,
      'company_industry': companyIndustry,
      'is_saved': isSaved,
    };
  }

  // ── Supabase deserialization ───────────────────────────────────────────────

  factory JobPost.fromSupabase(Map<String, dynamic> json, {
    String companyName = '',
    String? companyLogoUrl,
    String? companyIndustry,
    String jobType = '',
    String jobCategory = '',
    String experienceLevel = '',
    bool isSaved = false,
  }) {
    return JobPost(
      jobId:               json['job_id'] as String,
      companyId:           json['company_id'] as String,
      createdBy:           json['created_by'] as String,
      jobTitle:            json['job_title'] as String,
      description:         json['description'] as String,
      location:            json['location'] as String,
      remoteOption:        (json['remote_option'] as bool?) ?? false,
      salaryMin:           (json['salary_min'] as num?)?.toDouble(),
      salaryMax:           (json['salary_max'] as num?)?.toDouble(),
      jobType:             jobType,
      jobCategory:         jobCategory,
      experienceLevel:     experienceLevel,
      vacancyCount:        (json['vacancy_count'] as int?) ?? 1,
      applicationDeadline: json['application_deadline'] != null
          ? DateTime.tryParse(json['application_deadline'] as String)
          : null,
      status:              (json['status'] as String?) ?? 'active',
      viewCount:           (json['view_count'] as int?) ?? 0,
      applicationCount:    (json['application_count'] as int?) ?? 0,
      createdAt:           DateTime.parse(json['created_at'] as String),
      imageUrls:           List<String>.from(json['image_urls'] as List? ?? []),
      videoUrl:            json['video_url'] as String?,
      companyName:         companyName,
      companyLogoUrl:      companyLogoUrl,
      companyIndustry:     companyIndustry,
      isSaved:             isSaved,
    );
  }

  // ── SQLite serialization ───────────────────────────────────────────────────

  Map<String, dynamic> toLocalDbMap() => {
    'job_id':               jobId,
    'company_id':           companyId,
    'created_by':           createdBy,
    'job_title':            jobTitle,
    'description':          description,
    'location':             location,
    'remote_option':        remoteOption ? 1 : 0,
    'salary_min':           salaryMin,
    'salary_max':           salaryMax,
    'job_type':             jobType,
    'job_category':         jobCategory,
    'experience_level':     experienceLevel,
    'vacancy_count':        vacancyCount,
    'application_deadline': applicationDeadline?.toIso8601String(),
    'status':               status,
    'view_count':           viewCount,
    'application_count':    applicationCount,
    'created_at':           createdAt.toIso8601String(),
    'image_urls':           jsonEncode(imageUrls),
    'video_url':            videoUrl,
    'company_name':         companyName,
    'company_logo_url':     companyLogoUrl,
    'company_industry':     companyIndustry,
    'is_saved':             isSaved ? 1 : 0,
  };

  factory JobPost.fromLocalDb(Map<String, dynamic> map) {
    List<String> _decode(String? raw) {
      if (raw == null || raw.isEmpty) return [];
      try { return List<String>.from(jsonDecode(raw) as List); } catch (_) { return []; }
    }
    return JobPost(
      jobId:               map['job_id'] as String,
      companyId:           map['company_id'] as String,
      createdBy:           map['created_by'] as String,
      jobTitle:            map['job_title'] as String,
      description:         map['description'] as String,
      location:            map['location'] as String,
      remoteOption:        (map['remote_option'] as int? ?? 0) == 1,
      salaryMin:           map['salary_min'] as double?,
      salaryMax:           map['salary_max'] as double?,
      jobType:             map['job_type'] as String? ?? '',
      jobCategory:         map['job_category'] as String? ?? '',
      experienceLevel:     map['experience_level'] as String? ?? '',
      vacancyCount:        map['vacancy_count'] as int? ?? 1,
      applicationDeadline: map['application_deadline'] != null
          ? DateTime.tryParse(map['application_deadline'] as String)
          : null,
      status:              map['status'] as String? ?? 'active',
      viewCount:           map['view_count'] as int? ?? 0,
      applicationCount:    map['application_count'] as int? ?? 0,
      createdAt:           DateTime.parse(map['created_at'] as String),
      imageUrls:           _decode(map['image_urls'] as String?),
      videoUrl:            map['video_url'] as String?,
      companyName:         map['company_name'] as String? ?? '',
      companyLogoUrl:      map['company_logo_url'] as String?,
      companyIndustry:     map['company_industry'] as String?,
      isSaved:             (map['is_saved'] as int? ?? 0) == 1,
    );
  }
}