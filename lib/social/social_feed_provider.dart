import 'package:flutter/material.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/data/local_db.dart';

class SocialFeedProvider extends ChangeNotifier {
  final FeedRepository _repository;
  final String userId;

  SocialFeedProvider({
    required FeedRepository repository,
    required this.userId,
  }) : _repository = repository;

  //State
  List<FeedPost> _forYouPosts    = [];
  List<FeedPost> _followingPosts = [];
  bool _isLoadingForYou          = false;
  bool _isLoadingFollowing       = false;
  bool _hasMoreForYou            = true;
  bool _hasMoreFollowing         = true;
  String? _error;
  String _activeFilter           = 'All';
  int _forYouOffset              = 0;
  int _followingOffset           = 0;
  static const int _pageSize     = 20;

  //getter
  List<FeedPost> get forYouPosts     => _forYouPosts;
  List<FeedPost> get followingPosts  => _followingPosts;
  bool   get isLoadingForYou         => _isLoadingForYou;
  bool   get isLoadingFollowing      => _isLoadingFollowing;
  bool   get hasMoreForYou           => _hasMoreForYou;
  bool   get hasMoreFollowing        => _hasMoreFollowing;
  String? get error                  => _error;
  String get activeFilter            => _activeFilter;

  //init and refresh
  Future<void> init() async {
    // Show local cache immediately
    final cached = await LocalDB.getCachedPosts(limit: _pageSize);
    if (cached.isNotEmpty) {
      _forYouPosts = cached;
      notifyListeners();
    }
    await refreshForYou();
  }

  void setFilter(String filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    refreshForYou();
  }

  Future<void> refreshForYou() async {
    _isLoadingForYou = true;
    _forYouOffset    = 0;
    _hasMoreForYou   = true;
    _error           = null;
    notifyListeners();

    try {
      final posts = await _repository.fetchPosts(
        postTypeFilter: _activeFilter == 'All' ? null : _activeFilter,
        limit:          _pageSize,
        offset:         0,
      );
      _forYouPosts  = posts;
      _forYouOffset = posts.length;
      _hasMoreForYou = posts.length == _pageSize;
    } catch (e) {
      _error = 'Could not refresh feed. Showing cached data.';
      final cached = await LocalDB.getCachedPosts(
        postType: _activeFilter == 'All' ? null : _activeFilter,
        limit:    _pageSize,
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
        limit:          _pageSize,
        offset:         _forYouOffset,
      );
      _forYouPosts  = [..._forYouPosts, ...posts];
      _forYouOffset += posts.length;
      _hasMoreForYou = posts.length == _pageSize;
    } finally {
      _isLoadingForYou = false;
      notifyListeners();
    }
  }

  Future<void> refreshFollowing() async {
    _isLoadingFollowing = true;
    _followingOffset    = 0;
    _hasMoreFollowing   = true;
    notifyListeners();

    try {
      final posts = await _repository.fetchPosts(
        followingOnly: true,
        limit:         _pageSize,
        offset:        0,
      );
      _followingPosts  = posts;
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
        limit:         _pageSize,
        offset:        _followingOffset,
      );
      _followingPosts  = [..._followingPosts, ...posts];
      _followingOffset += posts.length;
      _hasMoreFollowing = posts.length == _pageSize;
    } finally {
      _isLoadingFollowing = false;
      notifyListeners();
    }
  }

  //interactions
  void _updateInLists(String postId, void Function(FeedPost p) fn) {
    for (final p in _forYouPosts)    { if (p.postId == postId) fn(p); }
    for (final p in _followingPosts) { if (p.postId == postId) fn(p); }
  }

  Future<void> toggleLike(FeedPost post) async {
    // Optimistic update
    final wasLiked = post.isLiked;
    _updateInLists(post.postId, (p) {
      p.isLiked   = !p.isLiked;
      p.likeCount = p.isLiked ? p.likeCount + 1 : p.likeCount - 1;
    });
    notifyListeners();

    final serverResult = await _repository.toggleLike(post.postId, wasLiked);
    if (serverResult == wasLiked) {
      // Server revert (same as original → toggle failed)
      _updateInLists(post.postId, (p) {
        p.isLiked   = wasLiked;
        p.likeCount = wasLiked ? p.likeCount + 1 : p.likeCount - 1;
      });
      notifyListeners();
    }
  }

  Future<void> toggleSave(FeedPost post) async {
    final wasSaved = post.isSaved;
    _updateInLists(post.postId, (p) => p.isSaved = !p.isSaved);
    notifyListeners();

    final serverResult = await _repository.toggleSavePost(post.postId, wasSaved);
    if (serverResult == wasSaved) {
      // Revert
      _updateInLists(post.postId, (p) => p.isSaved = wasSaved);
      notifyListeners();
    }
  }

  Future<void> toggleFollow(FeedPost post) async {
    if (post.companyId == null) return;
    final wasFollowing = post.isFollowing;
    _updateInLists(post.postId, (p) => p.isFollowing = !p.isFollowing);
    notifyListeners();

    await _repository.toggleFollowCompany(post.companyId!, wasFollowing);
  }

  Future<FeedPost?> createPost({
    required String content,
    required PostType postType,
    required List<String> hashtags,
    required List<String> mediaUrls,
    String? companyId,
    String? jobId,
  }) async {
    final post = await _repository.createPost(
      userId:    userId,
      companyId: companyId,
      content:   content,
      postType:  postType,
      hashtags:  hashtags,
      mediaUrls: mediaUrls,
      jobId:     jobId,
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
      _forYouPosts    = _forYouPosts.where((p)    => p.postId != postId).toList();
      _followingPosts = _followingPosts.where((p) => p.postId != postId).toList();
      notifyListeners();
    }
    return ok;
  }

  //comment
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

//job provider
class JobProvider extends ChangeNotifier {
  final FeedRepository _repository;
  final String userId;

  JobProvider({required FeedRepository repository, required this.userId})
      : _repository = repository;

  List<JobPost> _jobs        = [];
  bool _isLoading            = false;
  bool _hasMore              = true;
  String? _error;
  int _offset                = 0;
  static const int _pageSize = 20;

  // Filters
  String  _keyword        = '';
  String  _jobTypeFilter  = 'All';
  String  _expLevelFilter = 'All';
  String  _locationFilter = '';
  double? _salaryMin;
  bool    _remoteOnly     = false;

  List<JobPost> get jobs          => _jobs;
  bool          get isLoading     => _isLoading;
  bool          get hasMore       => _hasMore;
  String?       get error         => _error;
  String        get keyword       => _keyword;
  String        get jobTypeFilter => _jobTypeFilter;
  String        get expLevelFilter=> _expLevelFilter;
  String        get locationFilter=> _locationFilter;
  double?       get salaryMin     => _salaryMin;
  bool          get remoteOnly    => _remoteOnly;

  bool get hasActiveFilters =>
      _jobTypeFilter  != 'All' ||
          _expLevelFilter != 'All' ||
          _locationFilter.isNotEmpty ||
          _salaryMin != null ||
          _remoteOnly;

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
    _offset    = 0;
    _hasMore   = true;
    _error     = null;
    notifyListeners();

    try {
      final jobs = await _repository.fetchJobs(
        keyword:         _keyword.isEmpty ? null : _keyword,
        jobType:         _jobTypeFilter  == 'All' ? null : _jobTypeFilter,
        experienceLevel: _expLevelFilter == 'All' ? null : _expLevelFilter,
        location:        _locationFilter.isEmpty  ? null : _locationFilter,
        salaryMin:       _salaryMin,
        remoteOnly:      _remoteOnly,
        limit:           _pageSize,
        offset:          0,
      );
      _jobs   = jobs;
      _offset = jobs.length;
      _hasMore = jobs.length == _pageSize;
    } catch (e) {
      _error = 'Could not load jobs.';
      _jobs  = await LocalDB.getCachedJobs(
        jobType:         _jobTypeFilter  == 'All' ? null : _jobTypeFilter,
        experienceLevel: _expLevelFilter == 'All' ? null : _expLevelFilter,
        salaryMin:       _salaryMin,
        keyword:         _keyword.isEmpty ? null : _keyword,
        remoteOnly:      _remoteOnly,
        limit:           _pageSize,
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
        keyword:         _keyword.isEmpty ? null : _keyword,
        jobType:         _jobTypeFilter  == 'All' ? null : _jobTypeFilter,
        experienceLevel: _expLevelFilter == 'All' ? null : _expLevelFilter,
        location:        _locationFilter.isEmpty  ? null : _locationFilter,
        salaryMin:       _salaryMin,
        remoteOnly:      _remoteOnly,
        limit:           _pageSize,
        offset:          _offset,
      );
      _jobs    = [..._jobs, ...jobs];
      _offset += jobs.length;
      _hasMore  = jobs.length == _pageSize;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Filter setters (each triggers refresh) ────────────────────────────────

  void search(String q)       { _keyword        = q; refresh(); }
  void setJobType(String t)   { _jobTypeFilter  = t; refresh(); }
  void setExpLevel(String l)  { _expLevelFilter = l; refresh(); }
  void setLocation(String l)  { _locationFilter = l; refresh(); }
  void setSalaryMin(double? v){ _salaryMin       = v; refresh(); }
  void setRemoteOnly(bool v)  { _remoteOnly      = v; refresh(); }

  void clearFilters() {
    _jobTypeFilter  = 'All';
    _expLevelFilter = 'All';
    _locationFilter = '';
    _salaryMin      = null;
    _remoteOnly     = false;
    refresh();
  }

  //save
  Future<void> toggleSaveJob(JobPost job) async {
    final wasSaved = job.isSaved;
    job.isSaved = !job.isSaved;
    notifyListeners();

    final result = await _repository.toggleSaveJob(job.jobId, wasSaved);
    if (result == wasSaved) {
      // Revert
      job.isSaved = wasSaved;
      notifyListeners();
    }
  }
}