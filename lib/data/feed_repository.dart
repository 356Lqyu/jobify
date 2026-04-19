// ═══════════════════════════════════════════════════════════════════════════
// feed_repository.dart
// Supabase remote operations for social feed. Falls back to SQLite on error.
// Comments and likes are REMOTE ONLY (no local persistence).
// Saved posts are stored both locally and remotely.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'local_db.dart';
import 'job_repository.dart';

class FeedRepository {
  final SupabaseClient _sb = Supabase.instance.client;
  final JobRepository _jobRepo = JobRepository();

  String? get _uid => _sb.auth.currentUser?.id;

  // ══════════════════════════════════════════════════════════════════════════
  // IMAGE UPLOAD  →  Supabase Storage  →  public URL
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> uploadImage({
    required String bucket,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    if (!['png', 'jpg', 'jpeg'].contains(ext)) {
      throw Exception('Only png, jpg, jpeg images are supported.');
    }
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    await _sb.storage.from(bucket).uploadBinary(
      fileName,
      fileBytes,
      fileOptions: FileOptions(contentType: mime, upsert: true),
    );
    return _sb.storage.from(bucket).getPublicUrl(fileName);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POSTS  –  READ
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<FeedPost>> fetchPosts({
    String? postTypeFilter,
    bool followingOnly = false,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      var query = _sb.from('post').select('''
        post_id, user_id, company_id, job_id,
        content, post_type, hashtags, media_urls,
        created_at, updated_at,
        users!post_user_id_fkey ( fullname, profile_image_url ),
        company_profile!post_company_id_fkey ( company_name, logo_url, industry )
      ''');

      if (postTypeFilter != null && postTypeFilter != 'All') {
        query = query.eq('post_type', postTypeFilter);
      }

      if (followingOnly && _uid != null) {
        final follows = await _sb
            .from('follows')
            .select('following_user_id, following_company_id')
            .eq('follower_id', _uid!);

        final uids = (follows as List)
            .map((f) => f['following_user_id'] as String?)
            .whereType<String>()
            .toList();
        final cids = follows
            .map((f) => f['following_company_id'] as String?)
            .whereType<String>()
            .toList();

        if (uids.isEmpty && cids.isEmpty) return [];

        final orParts = <String>[];
        if (uids.isNotEmpty) orParts.add('user_id.in.(${uids.join(',')})');
        if (cids.isNotEmpty) orParts.add('company_id.in.(${cids.join(',')})');
        query = query.or(orParts.join(','));
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1) as List<dynamic>;

      // Fetch like / save / follow state for current user
      final likedIds      = _uid != null ? await _getLikedPostIds()      : <String>{};
      final savedIds      = _uid != null ? await LocalDB.getSavedPostIds(_uid!) : <String>{};
      final followedCids  = _uid != null ? await _getFollowedCompanyIds(): <String>{};

      // Fetch like + comment counts in one batch per post
      final postIds = rows.map((r) => (r as Map)['post_id'] as String).toList();
      final likeCountMap    = await _batchCountMap('post_like',    'post_id', postIds);
      final commentCountMap = await _batchCountMap('post_comment', 'post_id', postIds);

      // Build FeedPost list
      final posts = <FeedPost>[];
      for (final row in rows) {
        final r        = row as Map<String, dynamic>;
        final userRow  = r['users']           as Map<String, dynamic>?;
        final compRow  = r['company_profile'] as Map<String, dynamic>?;
        final pid      = r['post_id']  as String;
        final cid      = r['company_id'] as String?;
        final jobId    = r['job_id']   as String?;

        // Load linked job only when needed (postType == job)
        JobPost? linkedJob;
        if (jobId != null && r['post_type'] == 'job') {
          linkedJob = await _jobRepo.fetchJobById(jobId);
        }

        posts.add(FeedPost(
          postId:         pid,
          userId:         r['user_id'] as String,
          companyId:      cid,
          jobId:          jobId,
          content:        r['content'] as String? ?? '',
          postType:       postTypeFromString(r['post_type'] as String?),
          hashtags:       List<String>.from(r['hashtags'] as List? ?? []),
          mediaUrls:      List<String>.from(r['media_urls'] as List? ?? []),
          createdAt:      DateTime.parse(r['created_at'] as String),
          updatedAt:      DateTime.parse(r['updated_at'] as String? ?? r['created_at'] as String),
          authorName:     compRow?['company_name'] as String? ?? userRow?['fullname']  as String? ?? 'Unknown',
          authorAvatar:   compRow?['logo_url'] as String? ?? userRow?['profile_image_url'] as String? ?? '',
          authorSubtitle: compRow?['industry'] as String? ?? '',
          isVerified:     compRow != null,
          likeCount:      likeCountMap[pid]    ?? 0,
          commentCount:   commentCountMap[pid] ?? 0,
          isLiked:        likedIds.contains(pid),
          isSaved:        savedIds.contains(pid),
          isFollowing:    cid != null && followedCids.contains(cid),
          linkedJob:      linkedJob,
        ));
      }

      await LocalDB.insertPosts(posts);
      return posts;
    } catch (e, st) {
      debugPrint('fetchPosts error: $e\n$st');
      return LocalDB.getCachedPosts(
        postType: (postTypeFilter == null || postTypeFilter == 'All')
            ? null
            : postTypeFilter,
        limit:  limit,
        offset: offset,
      );
    }
  }

  // ── Batch count helper (remote only) ─────────────────────────────────────
  Future<Map<String, int>> _batchCountMap(String table, String column, List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await _sb.from(table).select(column).inFilter(column, ids) as List<dynamic>;
      final map = <String, int>{};
      for (final r in rows) {
        final id = (r as Map<String, dynamic>)[column] as String;
        map[id] = (map[id] ?? 0) + 1;
      }
      return map;
    } catch (e) {
      debugPrint('_batchCountMap error: $e');
      return {};
    }
  }

  Future<Set<String>> _getLikedPostIds() async {
    try {
      final rows = await _sb.from('post_like').select('post_id').eq('user_id', _uid!) as List<dynamic>;
      return rows.map((r) => (r as Map)['post_id'] as String).toSet();
    } catch (e) {
      debugPrint('_getLikedPostIds error: $e');
      return {};
    }
  }

  Future<Set<String>> _getFollowedCompanyIds() async {
    try {
      final rows = await _sb
          .from('follows')
          .select('following_company_id')
          .eq('follower_id', _uid!)
          .not('following_company_id', 'is', null) as List<dynamic>;
      return rows.map((r) => (r as Map)['following_company_id'] as String).toSet();
    } catch (e) {
      debugPrint('_getFollowedCompanyIds error: $e');
      return {};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POSTS  –  CREATE / UPDATE / DELETE
  // ══════════════════════════════════════════════════════════════════════════

  Future<FeedPost?> createPost({
    required String userId,
    String? companyId,
    required String content,
    required PostType postType,
    required List<String> hashtags,
    required List<String> mediaUrls,
    String? jobId,
  }) async {
    try {
      final insert = <String, dynamic>{
        'user_id':    userId,
        'content':    content,
        'post_type':  postType.name,
        'hashtags':   hashtags,
        'media_urls': mediaUrls,
        if (companyId != null) 'company_id': companyId,
        if (jobId != null)     'job_id':     jobId,
      };

      final row = await _sb.from('post').insert(insert).select().single();

      final userData = await _sb
          .from('users')
          .select('fullname, profile_image_url')
          .eq('user_id', userId)
          .maybeSingle();

      Map<String, dynamic>? compData;
      if (companyId != null) {
        compData = await _sb
            .from('company_profile')
            .select('company_name, logo_url, industry')
            .eq('user_id', companyId)
            .maybeSingle();
      }

      final post = FeedPost(
        postId:         row['post_id'] as String,
        userId:         userId,
        companyId:      companyId,
        jobId:          jobId,
        content:        content,
        postType:       postType,
        hashtags:       hashtags,
        mediaUrls:      mediaUrls,
        createdAt:      DateTime.parse(row['created_at'] as String),
        updatedAt:      DateTime.parse(row['updated_at'] as String? ?? row['created_at'] as String),
        authorName:     compData?['company_name'] as String? ?? userData?['fullname'] as String? ?? 'You',
        authorAvatar:   compData?['logo_url'] as String? ?? userData?['profile_image_url'] as String? ?? '',
        authorSubtitle: compData?['industry'] as String? ?? '',
        isVerified:     compData != null,
      );
      await LocalDB.insertPost(post);
      return post;
    } catch (e) {
      debugPrint('createPost error: $e');
      return null;
    }
  }

  /// Auto-create a social post when a job is posted (linked via job_id)
  Future<void> autoCreateJobPost({
    required String userId,
    required String companyId,
    required String jobId,
    required String jobTitle,
    required String companyName,
  }) async {
    try {
      await _sb.from('post').insert({
        'user_id':    userId,
        'company_id': companyId,
        'job_id':     jobId,
        'post_type':  'job',
        'content':    '🚀 We\'re hiring! Check out our open position: $jobTitle at $companyName.',
        'hashtags':   ['hiring', 'jobs', companyName.replaceAll(' ', '').toLowerCase()],
        'media_urls': <String>[],
      });
    } catch (e) {
      debugPrint('autoCreateJobPost error: $e');
    }
  }

  Future<bool> updatePost({
    required String postId,
    String? content,
    List<String>? hashtags,
    List<String>? mediaUrls,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        if (content != null)   'content':    content,
        if (hashtags != null)  'hashtags':   hashtags,
        if (mediaUrls != null) 'media_urls': mediaUrls,
      };
      await _sb.from('post').update(data).eq('post_id', postId);
      return true;
    } catch (e) {
      debugPrint('updatePost error: $e');
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _sb.from('post').delete().eq('post_id', postId);
      await LocalDB.deletePost(postId);
      return true;
    } catch (e) {
      debugPrint('deletePost error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIKES (REMOTE ONLY)
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> toggleLike(String postId, bool currentlyLiked) async {
    if (_uid == null) return currentlyLiked;
    final newLiked = !currentlyLiked;
    try {
      if (newLiked) {
        await _sb.from('post_like').insert({'post_id': postId, 'user_id': _uid});
      } else {
        await _sb.from('post_like').delete().eq('post_id', postId).eq('user_id', _uid!);
      }
      return newLiked;
    } catch (e) {
      debugPrint('toggleLike error: $e');
      return currentlyLiked;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVES (LOCAL + REMOTE)
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> toggleSavePost(String postId, bool currentlySaved) async {
    if (_uid == null) return currentlySaved;
    final newSaved = !currentlySaved;
    try {
      if (newSaved) {
        await _sb.from('post_saved').insert({'post_id': postId, 'user_id': _uid});
      } else {
        await _sb.from('post_saved').delete().eq('post_id', postId).eq('user_id', _uid!);
      }
      await LocalDB.setPostSaved(postId, newSaved, _uid!);
      return newSaved;
    } catch (e) {
      debugPrint('toggleSavePost error: $e');
      return currentlySaved;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMMENTS (REMOTE ONLY)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<PostComment>> fetchComments(String postId) async {
    try {
      final rows = await _sb.from('post_comment').select('''
        comment_id, post_id, user_id, comment_text, created_at,
        users!post_comment_user_id_fkey ( fullname, profile_image_url )
      ''')
          .eq('post_id', postId)
          .order('created_at', ascending: false) as List<dynamic>;

      return rows.map((row) {
        final r = row as Map<String, dynamic>;
        final userRow = r['users'] as Map<String, dynamic>?;
        return PostComment(
          commentId:    r['comment_id'] as String,
          postId:       r['post_id']    as String,
          userId:       r['user_id']    as String,
          commentText:  r['comment_text'] as String,
          createdAt:    DateTime.parse(r['created_at'] as String),
          authorName:   userRow?['fullname'] as String? ?? 'Unknown',
          authorAvatar: userRow?['profile_image_url'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('fetchComments error: $e');
      return [];
    }
  }

  Future<PostComment?> addComment(String postId, String text) async {
    if (_uid == null) return null;
    try {
      final row = await _sb.from('post_comment').insert({
        'post_id':      postId,
        'user_id':      _uid,
        'comment_text': text,
      }).select().single();

      final userData = await _sb
          .from('users')
          .select('fullname, profile_image_url')
          .eq('user_id', _uid!)
          .maybeSingle();

      return PostComment(
        commentId:    row['comment_id'] as String,
        postId:       postId,
        userId:       _uid!,
        commentText:  text,
        createdAt:    DateTime.parse(row['created_at'] as String),
        authorName:   userData?['fullname'] as String? ?? 'You',
        authorAvatar: userData?['profile_image_url'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('addComment error: $e');
      return null;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await _sb.from('post_comment').delete().eq('comment_id', commentId);
      return true;
    } catch (e) {
      debugPrint('deleteComment error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOLLOW (REMOTE ONLY)
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> toggleFollowCompany(String companyId, bool currentlyFollowing) async {
    if (_uid == null) return currentlyFollowing;
    final newFollowing = !currentlyFollowing;
    try {
      if (newFollowing) {
        await _sb.from('follows').insert({
          'follower_id':          _uid,
          'following_company_id': companyId,
        });
      } else {
        await _sb
            .from('follows')
            .delete()
            .eq('follower_id', _uid!)
            .eq('following_company_id', companyId);
      }
      return newFollowing;
    } catch (e) {
      debugPrint('toggleFollowCompany error: $e');
      return currentlyFollowing;
    }
  }

  Future<bool> toggleFollowUser(String targetUserId, bool currentlyFollowing) async {
    if (_uid == null) return currentlyFollowing;
    final newFollowing = !currentlyFollowing;
    try {
      if (newFollowing) {
        await _sb.from('follows').insert({
          'follower_id':       _uid,
          'following_user_id': targetUserId,
        });
      } else {
        await _sb
            .from('follows')
            .delete()
            .eq('follower_id', _uid!)
            .eq('following_user_id', targetUserId);
      }
      return newFollowing;
    } catch (e) {
      debugPrint('toggleFollowUser error: $e');
      return currentlyFollowing;
    }
  }
}