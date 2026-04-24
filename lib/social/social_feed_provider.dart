import 'package:flutter/material.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/data/job_repository.dart';
import 'package:jobify/data/local_db.dart';

// SNACKBAR
void showFeedSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  IconData? icon,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError
          ? const Color(0xFFEF4444)
          : const Color(0xFF1D4ED8),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      duration: const Duration(seconds: 2),
    ),
  );
}

class SocialFeedProvider extends ChangeNotifier {
  final FeedRepository _repository;
  final String userId;

  SocialFeedProvider({required FeedRepository repository, required this.userId})
    : _repository = repository;

  // State
  List<FeedPost> _forYouPosts = [];
  List<FeedPost> _followingPosts = [];
  bool _isLoadingForYou = false;
  bool _isLoadingFollowing = false;
  bool _hasMoreForYou = true;
  bool _hasMoreFollowing = true;
  String? _error;
  String _activeFilter = 'All';
  String _followingFilter = 'All'; // new
  int _forYouOffset = 0;
  int _followingOffset = 0;
  static const int _pageSize = 20;

  // Getters
  List<FeedPost> get forYouPosts => _forYouPosts;
  List<FeedPost> get followingPosts => _followingPosts;
  bool get isLoadingForYou => _isLoadingForYou;
  bool get isLoadingFollowing => _isLoadingFollowing;
  bool get hasMoreForYou => _hasMoreForYou;
  bool get hasMoreFollowing => _hasMoreFollowing;
  String? get error => _error;
  String get activeFilter => _activeFilter;
  String get followingFilter => _followingFilter; // new

  // Init
  Future<void> init() async {
    final cached = await LocalDB.getCachedPosts(limit: _pageSize);
    if (cached.isNotEmpty) {
      _forYouPosts = cached;
      notifyListeners();
    }
    await refreshForYou();
  }

  // Filters
  void setFilter(String filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    refreshForYou();
  }

  void setFollowingFilter(String filter) {
    if (_followingFilter == filter) return;
    _followingFilter = filter;
    refreshFollowing();
  }

  // For You data
  Future<void> refreshForYou() async {
    _isLoadingForYou = true;
    _forYouOffset = 0;
    _hasMoreForYou = true;
    _error = null;
    notifyListeners();

    try {
      final posts = await _repository.fetchPosts(
        postTypeFilter: _activeFilter == 'All' ? null : _activeFilter,
        limit: _pageSize,
        offset: 0,
      );
      _forYouPosts = posts;
      _forYouOffset = posts.length;
      _hasMoreForYou = posts.length == _pageSize;
    } catch (e) {
      _error = 'Could not refresh feed. Showing cached data.';
      final cached = await LocalDB.getCachedPosts(
        postType: _activeFilter == 'All' ? null : _activeFilter,
        limit: _pageSize,
      );
      _forYouPosts = cached;
    } finally {
      _isLoadingForYou = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreForYou() async {
    if (_isLoadingForYou || !_hasMoreForYou) return;
    _isLoadingForYou = true;
    notifyListeners();

    try {
      final posts = await _repository.fetchPosts(
        postTypeFilter: _activeFilter == 'All' ? null : _activeFilter,
        limit: _pageSize,
        offset: _forYouOffset,
      );
      _forYouPosts = [..._forYouPosts, ...posts];
      _forYouOffset += posts.length;
      _hasMoreForYou = posts.length == _pageSize;
    } finally {
      _isLoadingForYou = false;
      notifyListeners();
    }
  }

  // Following data
  Future<void> refreshFollowing() async {
    _isLoadingFollowing = true;
    _followingOffset = 0;
    _hasMoreFollowing = true;
    notifyListeners();

    try {
      final posts = await _repository.fetchPosts(
        followingOnly: true,
        followingUsersOnly: true,
        postTypeFilter: _followingFilter == 'All'
            ? null
            : _followingFilter, // apply filter
        limit: _pageSize,
        offset: 0,
      );
      _followingPosts = posts;
      _followingOffset = posts.length;
      _hasMoreFollowing = posts.length == _pageSize;
    } finally {
      _isLoadingFollowing = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreFollowing() async {
    if (_isLoadingFollowing || !_hasMoreFollowing) return;
    _isLoadingFollowing = true;
    notifyListeners();

    try {
      final posts = await _repository.fetchPosts(
        followingOnly: true,
        followingUsersOnly: true,
        postTypeFilter: _followingFilter == 'All' ? null : _followingFilter,
        limit: _pageSize,
        offset: _followingOffset,
      );
      _followingPosts = [..._followingPosts, ...posts];
      _followingOffset += posts.length;
      _hasMoreFollowing = posts.length == _pageSize;
    } finally {
      _isLoadingFollowing = false;
      notifyListeners();
    }
  }

  // Interactions
  void _updateInLists(String postId, void Function(FeedPost p) fn) {
    for (final p in _forYouPosts) {
      if (p.postId == postId) fn(p);
    }
    for (final p in _followingPosts) {
      if (p.postId == postId) fn(p);
    }
  }

  /// Toggle like with optimistic update + snackbar feedback.
  Future<void> toggleLike(FeedPost post, [BuildContext? context]) async {
    final wasLiked = post.isLiked;
    final newLiked = !wasLiked;

    _updateInLists(post.postId, (p) {
      p.isLiked = newLiked;
      p.likeCount = newLiked ? p.likeCount + 1 : p.likeCount - 1;
    });
    notifyListeners();

    if (context != null && context.mounted) {
      showFeedSnackBar(
        context,
        newLiked ? 'Post liked' : 'Like removed',
        icon: newLiked ? Icons.favorite : Icons.favorite_border,
      );
    }

    final serverResult = await _repository.toggleLike(post.postId, wasLiked);
    if (serverResult != newLiked) {
      _updateInLists(post.postId, (p) {
        p.isLiked = wasLiked;
        p.likeCount = wasLiked ? p.likeCount + 1 : p.likeCount - 1;
      });
      notifyListeners();
      if (context != null && context.mounted) {
        showFeedSnackBar(context, 'Failed to update like', isError: true);
      }
    }
  }

  /// Toggle save with optimistic update + snackbar feedback.
  Future<void> toggleSave(FeedPost post, [BuildContext? context]) async {
    final wasSaved = post.isSaved;
    final newSaved = !wasSaved;

    _updateInLists(post.postId, (p) => p.isSaved = newSaved);
    notifyListeners();

    if (context != null && context.mounted) {
      showFeedSnackBar(
        context,
        newSaved ? 'Post saved' : 'Post unsaved',
        icon: newSaved ? Icons.bookmark : Icons.bookmark_outline,
      );
    }

    // Pass the linked jobId to properly sync the discovery/job cache
    final serverResult = await _repository.toggleSavePost(
      post.postId,
      wasSaved,
      jobId: post.jobId,
    );
    if (serverResult == wasSaved) {
      _updateInLists(post.postId, (p) => p.isSaved = wasSaved);
      notifyListeners();
      if (context != null && context.mounted) {
        showFeedSnackBar(context, 'Failed to save post', isError: true);
      }
    }
  }

  /// Toggle follow with optimistic update + snackbar feedback.
  Future<void> toggleFollow(FeedPost post, [BuildContext? context]) async {
    final targetUserId = post.userId;
    final wasFollowing = post.isFollowing;
    final newFollowing = !wasFollowing;

    // Update all posts from the same author
    void setAllFollowing(bool value) {
      for (final p in _forYouPosts) {
        if (p.userId == targetUserId) p.isFollowing = value;
      }
      for (final p in _followingPosts) {
        if (p.userId == targetUserId) p.isFollowing = value;
      }
    }

    setAllFollowing(newFollowing);
    notifyListeners();

    if (context != null && context.mounted) {
      showFeedSnackBar(
        context,
        newFollowing
            ? 'Now following ${post.authorName}'
            : 'Unfollowed ${post.authorName}',
        icon: newFollowing ? Icons.person_add : Icons.person_remove_outlined,
      );
    }

    final result = await _repository.toggleFollowUser(
      targetUserId,
      wasFollowing,
    );
    if (result == wasFollowing) {
      setAllFollowing(wasFollowing);
      notifyListeners();
      if (context != null && context.mounted) {
        showFeedSnackBar(context, 'Failed to update follow', isError: true);
      }
    }
  }

  // Create / delete posts
  Future<FeedPost?> createPost({
    required String content,
    required PostType postType,
    required List<String> hashtags,
    required List<String> mediaUrls,
    String? companyId,
    String? jobId,
  }) async {
    final post = await _repository.createPost(
      userId: userId,
      companyId: companyId,
      content: content,
      postType: postType,
      hashtags: hashtags,
      mediaUrls: mediaUrls,
      jobId: jobId,
    );
    if (post != null) {
      _forYouPosts = [post, ..._forYouPosts];
      notifyListeners();
    }
    return post;
  }

  Future<bool> deletePost(String postId) async {
    final ok = await _repository.deletePost(postId);
    if (ok) {
      _forYouPosts = _forYouPosts.where((p) => p.postId != postId).toList();
      _followingPosts = _followingPosts
          .where((p) => p.postId != postId)
          .toList();
      notifyListeners();
    }
    return ok;
  }

  // Comments
  Future<List<PostComment>> fetchComments(String postId) =>
      _repository.fetchComments(postId);

  Future<PostComment?> addComment(String postId, String text) async {
    final comment = await _repository.addComment(postId, text);
    if (comment != null) {
      _updateInLists(postId, (p) => p.commentCount++);
      notifyListeners();
    }
    return comment;
  }
}

// JOB PROVIDER
class JobProvider extends ChangeNotifier {
  final JobRepository _repository;
  final String userId;

  JobProvider({required JobRepository repository, required this.userId})
    : _repository = repository;

  List<JobPost> _jobs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  static const int _pageSize = 20;

  String _keyword = '';
  String _jobTypeFilter = 'All';
  String _expLevelFilter = 'All';
  String _locationFilter = '';
  double? _salaryMin;
  bool _remoteOnly = false;
  int _postDaysFilter = 0; // 0 means 'All Time'

  List<JobPost> get jobs => _jobs;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get keyword => _keyword;
  String get jobTypeFilter => _jobTypeFilter;
  String get expLevelFilter => _expLevelFilter;
  String get locationFilter => _locationFilter;
  double? get salaryMin => _salaryMin;
  bool get remoteOnly => _remoteOnly;
  int get postDaysFilter => _postDaysFilter;

  bool get hasActiveFilters =>
      _jobTypeFilter != 'All' ||
      _expLevelFilter != 'All' ||
      _locationFilter.isNotEmpty ||
      _salaryMin != null ||
      _remoteOnly ||
      _postDaysFilter > 0;

  Future<void> init() async {
    final cached = await LocalDB.getCachedJobs(limit: _pageSize);
    if (cached.isNotEmpty) {
      _jobs = cached;
      notifyListeners();
    }
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _offset = 0;
    _hasMore = true;
    _error = null;
    notifyListeners();

    try {
      final jobs = await _repository.fetchJobs(
        keyword: _keyword.isEmpty ? null : _keyword,
        jobType: _jobTypeFilter == 'All' ? null : _jobTypeFilter,
        experienceLevel: _expLevelFilter == 'All' ? null : _expLevelFilter,
        location: _locationFilter.isEmpty ? null : _locationFilter,
        salaryMin: _salaryMin,
        remoteOnly: _remoteOnly,
        daysAgo: _postDaysFilter > 0 ? _postDaysFilter : null,
        limit: _pageSize,
        offset: 0,
      );
      _jobs = jobs;
      _offset = jobs.length;
      _hasMore = jobs.length == _pageSize;
    } catch (e) {
      _error = 'Could not load jobs.';
      _jobs = await LocalDB.getCachedJobs(
        jobType: _jobTypeFilter == 'All' ? null : _jobTypeFilter,
        experienceLevel: _expLevelFilter == 'All' ? null : _expLevelFilter,
        salaryMin: _salaryMin,
        keyword: _keyword.isEmpty ? null : _keyword,
        remoteOnly: _remoteOnly,
        limit: _pageSize,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();

    try {
      final jobs = await _repository.fetchJobs(
        keyword: _keyword.isEmpty ? null : _keyword,
        jobType: _jobTypeFilter == 'All' ? null : _jobTypeFilter,
        experienceLevel: _expLevelFilter == 'All' ? null : _expLevelFilter,
        location: _locationFilter.isEmpty ? null : _locationFilter,
        salaryMin: _salaryMin,
        remoteOnly: _remoteOnly,
        daysAgo: _postDaysFilter > 0 ? _postDaysFilter : null,
        limit: _pageSize,
        offset: _offset,
      );
      _jobs = [..._jobs, ...jobs];
      _offset += jobs.length;
      _hasMore = jobs.length == _pageSize;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String keyword) {
    if (_keyword == keyword) return;
    _keyword = keyword;
    refresh();
  }

  void setJobType(String t) {
    _jobTypeFilter = t;
    refresh();
  }

  void setExpLevel(String l) {
    _expLevelFilter = l;
    refresh();
  }

  void setLocation(String l) {
    _locationFilter = l;
    refresh();
  }

  void setSalaryMin(double? v) {
    _salaryMin = v;
    refresh();
  }

  void setRemoteOnly(bool v) {
    _remoteOnly = v;
    refresh();
  }

  void setPostDays(int days) {
    _postDaysFilter = days;
    refresh();
  }

  void clearFilters() {
    _jobTypeFilter = 'All';
    _expLevelFilter = 'All';
    _locationFilter = '';
    _salaryMin = null;
    _remoteOnly = false;
    _postDaysFilter = 0;
    refresh();
  }

  /// Toggle save job with optimistic update + snackbar feedback.
  Future<void> toggleSaveJob(JobPost job, [BuildContext? context]) async {
    final wasSaved = job.isSaved;
    final newSaved = !wasSaved;

    job.isSaved = newSaved;
    notifyListeners();

    if (context != null && context.mounted) {
      showFeedSnackBar(
        context,
        newSaved ? 'Job saved' : 'Job unsaved',
        icon: newSaved ? Icons.bookmark : Icons.bookmark_outline,
      );
    }

    final result = await _repository.toggleSaveJob(job.jobId, wasSaved);
    if (result == wasSaved) {
      job.isSaved = wasSaved;
      notifyListeners();
      if (context != null && context.mounted) {
        showFeedSnackBar(context, 'Failed to save job', isError: true);
      }
    }
  }
}
