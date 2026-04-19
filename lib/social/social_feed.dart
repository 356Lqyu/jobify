import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/social/social_feed_provider.dart';
import 'package:jobify/social/social_post_bottom_sheet.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/users/users.dart';
//import 'package:jobify/job_post/job_detail.dart'; // job seeker detail page
import 'package:jobify/job_post/job_detail_employer.dart';

class SocialFeedPage extends StatefulWidget {
  final Users user;
  const SocialFeedPage({super.key, required this.user});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage>
    with SingleTickerProviderStateMixin {
  late final TabController      _tabController;
  late final SocialFeedProvider _provider;
  final _searchCtrl  = TextEditingController();
  bool  _showSearch  = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      if (_tabController.index == 1) _provider.refreshFollowing();
    });

    _provider = SocialFeedProvider(
      repository: FeedRepository(),
      userId:     widget.user.userId,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _provider.init());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    _provider.dispose();
    super.dispose();
  }

  void _openCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: _provider,
        child: SocialPostBottomSheet(
          userId:          widget.user.userId,
          authorName:      widget.user.fullname,
          authorAvatarUrl: widget.user.profileImageUrl,
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ChangeNotifierProvider.value(
        value: _provider,
        child: const _FeedFilterSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        // ── Use CustomScrollView so we have full control over header height ──
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Material(
                color: Colors.white,
                elevation: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search row
                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _showSearch
                                  ? _SearchField(
                                key: const ValueKey('search'),
                                ctrl: _searchCtrl,
                                onClose: () {
                                  setState(
                                          () => _showSearch = false);
                                  _searchCtrl.clear();
                                },
                              )
                                  : GestureDetector(
                                key: const ValueKey('bar'),
                                onTap: () => setState(
                                        () => _showSearch = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius:
                                    BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.search,
                                          size: 16,
                                          color: Colors.blueGrey),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Search posts, #hashtags…',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blueGrey
                                                .shade400),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune_outlined,
                                color: Colors.blueGrey, size: 22),
                            onPressed: _showFilterSheet,
                          ),
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.notifications_outlined,
                                    size: 24),
                                onPressed: () {},
                              ),
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Filter chips
                    Consumer<SocialFeedProvider>(
                      builder: (_, prov, __) =>
                          _FilterChips(provider: prov),
                    ),

                    // Tabs
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF2563EB),
                      unselectedLabelColor: Colors.blueGrey,
                      indicatorColor: const Color(0xFF2563EB),
                      indicatorWeight: 2.5,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      tabs: const [
                        Tab(text: 'For You'),
                        Tab(text: 'Following'),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Tab content fills remaining space ──────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ForYouTab(user: widget.user),
                    _FollowingTab(user: widget.user),
                  ],
                ),
              ),
            ],
          ),
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: _openCreatePost,
          backgroundColor: const Color(0xFF2563EB),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIPS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final SocialFeedProvider provider;
  const _FilterChips({required this.provider});

  static const _filters = [
    {'label': 'All',    'value': 'All'},
    {'label': 'Posts',  'value': 'post'},
    {'label': 'Hiring', 'value': 'job'},
    {'label': 'Tips',   'value': 'tip'},
    {'label': 'Events', 'value': 'event'},
    {'label': 'News',   'value': 'news'},
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<SocialFeedProvider>(
      builder: (_, prov, __) => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f   = _filters[i];
            final sel = prov.activeFilter == f['value'];
            return GestureDetector(
              onTap: () => prov.setFilter(f['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : Colors.blueGrey),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onClose;
  const _SearchField({super.key, required this.ctrl, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search posts, #hashtags…',
        hintStyle: const TextStyle(fontSize: 13, color: Colors.blueGrey),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
        prefixIcon:
        const Icon(Icons.search, size: 18, color: Colors.blueGrey),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, size: 16),
          onPressed: onClose,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOR YOU TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ForYouTab extends StatelessWidget {
  final Users user;
  const _ForYouTab({required this.user});


  @override
  Widget build(BuildContext context) {
    return Consumer<SocialFeedProvider>(
      builder: (_, prov, __) {
        if (prov.isLoadingForYou && prov.forYouPosts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (prov.forYouPosts.isEmpty) {
          return const _EmptyState(
            icon: Icons.article_outlined,
            message: 'No posts yet. Be the first to share!',
          );
        }
        return RefreshIndicator(
          onRefresh: prov.refreshForYou,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                prov.loadMoreForYou();
              }
              return false;
            },
            child: ListView.builder(
              padding:
              const EdgeInsets.only(top: 8, bottom: 100),
              // +1 for trending banner, +1 if loading more
              itemCount: prov.forYouPosts.length +
                  (prov.isLoadingForYou ? 1 : 0) +
                  1,
              itemBuilder: (ctx, i) {
                // Trending banner at position 2
                if (i == 2) return const _TrendingBanner();
                // Adjust index to skip the banner slot
                final adj = i > 2 ? i - 1 : i;
                if (adj >= prov.forYouPosts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _FeedCard(
                    post: prov.forYouPosts[adj],
                    currentUser: user);
              },
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOWING TAB
// ─────────────────────────────────────────────────────────────────────────────

class _FollowingTab extends StatelessWidget {
  final Users user;
  const _FollowingTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return Consumer<SocialFeedProvider>(
      builder: (_, prov, __) {
        if (prov.isLoadingFollowing && prov.followingPosts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (prov.followingPosts.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            message:
            'Follow companies & people to see their posts here.',
          );
        }
        return RefreshIndicator(
          onRefresh: prov.refreshFollowing,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                prov.loadMoreFollowing();
              }
              return false;
            },
            child: ListView.builder(
              padding:
              const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: prov.followingPosts.length +
                  (prov.isLoadingFollowing ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= prov.followingPosts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _FeedCard(
                    post: prov.followingPosts[i],
                    currentUser: user);
              },
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEED CARD
// ─────────────────────────────────────────────────────────────────────────────

class _FeedCard extends StatelessWidget {
  final FeedPost post;
  final Users currentUser;
  const _FeedCard({required this.post, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<SocialFeedProvider>();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (avatar, name, follow button, menu) ─────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeedAvatar(
                    name: post.authorName, url: post.authorAvatar),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(post.authorName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (post.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                size: 14, color: Color(0xFF2563EB)),
                          ],
                        ],
                      ),
                      if (post.authorSubtitle.isNotEmpty)
                        Text(post.authorSubtitle,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.blueGrey)),
                      Text(post.timeAgo,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.blueGrey)),
                    ],
                  ),
                ),
                _TypeBadge(type: post.postType),
                const SizedBox(width: 4),
                if (post.companyId != null)
                  _FollowBtn(
                    isFollowing: post.isFollowing,
                    onTap: () => prov.toggleFollow(post),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: Colors.blueGrey),
                  onSelected: (v) async {
                    if (v == 'save') prov.toggleSave(post);
                    if (v == 'delete' &&
                        post.userId == currentUser.userId) {
                      await prov.deletePost(post.postId);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'save', child: Text('Save post')),
                    if (post.userId == currentUser.userId)
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
          ),

          // ── Content (clickable area) ───────────────────────────────────
          GestureDetector(
            onTap: () => _navigateToDetail(context),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rich content (text with hashtags)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: _RichContent(content: post.content),
                ),
                // Hashtags
                if (post.hashtags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Wrap(
                      spacing: 8, runSpacing: 4,
                      children: post.hashtags
                          .map((tag) => GestureDetector(
                        onTap: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Search: #$tag'),
                                  duration:
                                  const Duration(seconds: 1)),
                            ),
                        child: Text('#$tag',
                            style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ))
                          .toList(),
                    ),
                  ),
                // Media (images)
                if (post.mediaUrls.isNotEmpty)
                  _MediaGrid(urls: post.mediaUrls),
                // Linked job card (if job post)
                if (post.postType == PostType.job && post.linkedJob != null)
                  _LinkedJobCard(job: post.linkedJob!),
              ],
            ),
          ),

          // ── Action row (like, comment, share, save) ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
            child: Row(
              children: [
                _ActionBtn(
                  icon: post.isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: post.likeCount.toString(),
                  color: post.isLiked
                      ? const Color(0xFFEF4444)
                      : Colors.blueGrey,
                  onTap: () => prov.toggleLike(post),
                ),
                _ActionBtn(
                  icon: Icons.mode_comment_outlined,
                  label: post.commentCount.toString(),
                  color: Colors.blueGrey,
                  onTap: () => _showComments(context, post, prov),
                ),
                _ActionBtn(
                  icon: Icons.share_outlined,
                  label: '',
                  color: Colors.blueGrey,
                  onTap: () {},
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    post.isSaved
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    size: 20,
                    color: post.isSaved
                        ? const Color(0xFF2563EB)
                        : Colors.blueGrey,
                  ),
                  onPressed: () => prov.toggleSave(post),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Navigation helper
  void _navigateToDetail(BuildContext context) async {  // note: async
    if (post.postType == PostType.job && post.linkedJob != null) {
      final jobId = post.linkedJob!.jobId;

      // Try to get the latest job map from cache
      Map<String, dynamic>? jobMap = await LocalDB.getCachedJobMapById(jobId);

      // Fallback: build a minimal map from the linkedJob if cache miss
      jobMap ??= {
        'job_id': jobId,
        'job_title': post.linkedJob!.jobTitle,
        'company_name': post.linkedJob!.companyName,
        'location': post.linkedJob!.location,
        'description': post.linkedJob!.description,
        'job_type': post.linkedJob!.jobType,
        'job_category': post.linkedJob!.jobCategory,
        'experience_level': post.linkedJob!.experienceLevel,
        'remote_option': post.linkedJob!.remoteOption,
        'salary_min': post.linkedJob!.salaryMin,
        'salary_max': post.linkedJob!.salaryMax,
        'view_count': post.linkedJob!.viewCount,
        'application_count': post.linkedJob!.applicationCount,
        'image_urls': post.linkedJob!.imageUrls,
        'video_url': post.linkedJob!.videoUrl,
        'status': post.linkedJob!.status,
      };

      if (post.userId == currentUser.userId) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailEmployer(job: jobMap!)));
      } else {
        //Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailPage(job: jobMap!)));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post details coming soon')));
    }
  }

  // Keep the existing _showComments method unchanged
  void _showComments(
      BuildContext ctx, FeedPost post, SocialFeedProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _CommentSheet(post: post),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMENT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _CommentSheet extends StatefulWidget {
  final FeedPost post;
  const _CommentSheet({required this.post});
  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _ctrl = TextEditingController();
  List<PostComment> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prov = context.read<SocialFeedProvider>();
    final c = await prov.fetchComments(widget.post.postId);
    if (mounted) setState(() { _comments = c; _loading = false; });
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final prov = context.read<SocialFeedProvider>();
    final c = await prov.addComment(widget.post.postId, text);
    if (c != null && mounted) {
      setState(() => _comments = [c, ..._comments]);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Comments (${widget.post.commentCount})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? const Center(
                  child: Text('No comments yet.',
                      style: TextStyle(
                          color: Colors.blueGrey)))
                  : ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                itemCount: _comments.length,
                itemBuilder: (_, i) {
                  final c = _comments[i];
                  return Padding(
                    padding: const EdgeInsets.only(
                        bottom: 14),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        _FeedAvatar(
                            name: c.authorName,
                            url:  c.authorAvatar,
                            radius: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding:
                            const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                              const Color(0xFFF8FAFC),
                              borderRadius:
                              BorderRadius.circular(
                                  12),
                            ),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(c.authorName,
                                        style: const TextStyle(
                                            fontWeight:
                                            FontWeight.w600,
                                            fontSize: 13)),
                                    const Spacer(),
                                    Text(c.timeAgo,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors
                                                .blueGrey)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(c.commentText,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16,
                  MediaQuery.of(context).viewInsets.bottom + 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Write a comment…',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 18),
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEED FILTER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _FeedFilterSheet extends StatelessWidget {
  const _FeedFilterSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<SocialFeedProvider>(
      builder: (_, prov, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Filter Feed',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    prov.setFilter('All');
                    Navigator.pop(context);
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Post Type',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                'All', 'post', 'job', 'tip', 'event', 'news',
              ].map((v) {
                final sel  = prov.activeFilter == v;
                final label = v == 'All'
                    ? 'All'
                    : PostType.values
                    .firstWhere((t) => t.name == v,
                    orElse: () => PostType.post)
                    .label;
                return ChoiceChip(
                  label: Text(label),
                  selected: sel,
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                      color: sel ? Colors.white : Colors.blueGrey,
                      fontSize: 13),
                  onSelected: (_) {
                    prov.setFilter(v);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RICH CONTENT  (clickable #hashtags)
// ─────────────────────────────────────────────────────────────────────────────

class _RichContent extends StatefulWidget {
  final String content;
  const _RichContent({required this.content});
  @override
  State<_RichContent> createState() => _RichContentState();
}

class _RichContentState extends State<_RichContent> {
  bool _expanded = false;
  static const _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    for (final word in widget.content.split(' ')) {
      if (word.startsWith('#')) {
        spans.add(WidgetSpan(
          child: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Search: $word'),
                    duration: const Duration(seconds: 1))),
            child: Text('$word ',
                style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w500,
                    fontSize: 14)),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: '$word ',
          style: const TextStyle(
              fontSize: 14, height: 1.5, color: Colors.black87),
        ));
      }
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final tp = TextPainter(
          text: TextSpan(children: spans),
          maxLines: _maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              maxLines: _expanded ? null : _maxLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              text: TextSpan(children: spans),
            ),
            if (tp.didExceedMaxLines)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? 'Show less' : 'See more',
                    style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA GRID
// ─────────────────────────────────────────────────────────────────────────────

class _MediaGrid extends StatelessWidget {
  final List<String> urls;
  const _MediaGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: urls.first,
            width: double.infinity, height: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(height: 200, color: Colors.grey.shade100),
            errorWidget: (_, __, ___) => Container(
                height: 200,
                color: Colors.grey.shade100,
                child: const Icon(Icons.broken_image_outlined,
                    color: Colors.grey)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.2,
        ),
        itemCount: urls.length > 4 ? 4 : urls.length,
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: urls[i],
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: Colors.grey.shade100),
                errorWidget: (_, __, ___) =>
                    Container(color: Colors.grey.shade100),
              ),
              if (i == 3 && urls.length > 4)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Text('+${urls.length - 4}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LINKED JOB CARD
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedJobCard extends StatelessWidget {
  final JobPost job;
  const _LinkedJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFD9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_outline,
                  size: 15, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(job.jobTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E40AF)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(job.companyName,
              style: const TextStyle(
                  fontSize: 11, color: Colors.blueGrey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10, runSpacing: 4,
            children: [
              _InlineChip(
                  icon: Icons.location_on_outlined,
                  label: job.location),
              _InlineChip(
                  icon: Icons.attach_money,
                  label: job.salaryDisplay),
              _InlineChip(
                  icon: Icons.access_time_outlined,
                  label: job.jobType),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _InlineChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InlineChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: Colors.blueGrey),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
    ],
  );
}

class _TypeBadge extends StatelessWidget {
  final PostType type;
  const _TypeBadge({required this.type});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: type.color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: type.color.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(type.icon, size: 10, color: type.color),
        const SizedBox(width: 4),
        Text(type.label,
            style: TextStyle(
                fontSize: 10,
                color: type.color,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _FollowBtn extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  const _FollowBtn({required this.isFollowing, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFollowing
            ? Colors.grey.shade100
            : const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isFollowing
                ? Colors.grey.shade300
                : const Color(0xFF2563EB)),
      ),
      child: Text(
        isFollowing ? 'Following' : '+ Follow',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isFollowing ? Colors.blueGrey : Colors.white),
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
        required this.label,
        required this.color,
        required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    ),
  );
}

class _FeedAvatar extends StatelessWidget {
  final String  name;
  final String? url;
  final double  radius;
  const _FeedAvatar(
      {required this.name, this.url, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }
    final initials = name.trim().isEmpty
        ? '?'
        : name
        .trim()
        .split(' ')
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    const palette = [
      Color(0xFF6366F1), Color(0xFF2563EB), Color(0xFF10B981),
      Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF0EA5E9),
    ];
    final color = name.isEmpty
        ? palette[0]
        : palette[name.codeUnitAt(0) % palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.65)),
    );
  }
}

class _TrendingBanner extends StatelessWidget {
  const _TrendingBanner();
  @override
  Widget build(BuildContext context) {
    const skills = [
      'Flutter', 'Python', 'React', 'SQL', 'UI/UX', 'DevOps', 'AI/ML'
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.trending_up, color: Colors.white70, size: 14),
            SizedBox(width: 6),
            Text('Trending skills in Malaysia',
                style: TextStyle(
                    color: Colors.white70, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 5,
            children: skills
                .map((s) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3)),
              ),
              child: Text(s,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.blueGrey.shade200),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.blueGrey.shade400, fontSize: 15)),
        ],
      ),
    ),
  );
}