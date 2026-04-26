import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/social/social_post_details.dart';
import 'package:jobify/job_post/job_detail_employer.dart';
import 'package:jobify/social/social_feed_provider.dart';

class MyPostsPage extends StatefulWidget {
  final Users currentUser;
  const MyPostsPage({super.key, required this.currentUser});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final FeedRepository _repo = FeedRepository();
  List<FeedPost> _myPosts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
  }

  Future<void> _loadMyPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final posts = await _repo.fetchUserPosts(widget.currentUser.userId);
      if (mounted)
        setState(() {
          _myPosts = posts;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Failed to load your posts';
          _isLoading = false;
        });
    }
  }

  Future<void> _deletePost(FeedPost post) async {
    if (post.jobId != null) {
      showFeedSnackBar(
        context,
        'Job posts must be managed from your employer dashboard.',
        isError: true,
        icon: Icons.info_outline,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Post',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Optimistic removal
    final removed = post;
    setState(() => _myPosts.removeWhere((p) => p.postId == post.postId));

    final success = await _repo.deletePost(post.postId);
    if (!success && mounted) {
      // Revert
      setState(() => _myPosts = [removed, ..._myPosts]);
      showFeedSnackBar(context, 'Failed to delete post', isError: true);
    } else if (mounted) {
      showFeedSnackBar(
        context,
        'Post deleted',
        icon: Icons.check_circle_outline,
      );
    }
  }

  void _viewPost(FeedPost post) async {
    if (post.postType == PostType.job && post.linkedJob != null) {
      final jobMap = post.linkedJob!.toLocalDbMap();
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JobDetailEmployer(job: jobMap)),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SocialPostDetails(post: post, currentUser: widget.currentUser),
        ),
      );
    }
    _loadMyPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Posts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.blueGrey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.blueGrey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMyPosts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _myPosts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.post_add_outlined,
                      size: 64,
                      color: Colors.blueGrey.shade200,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button on the Home feed\nto share something with your network!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.blueGrey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadMyPosts,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
                itemCount: _myPosts.length,
                itemBuilder: (ctx, i) {
                  final post = _myPosts[i];
                  return _MyPostCard(
                    post: post,
                    onTap: () => _viewPost(post),
                    onDelete: post.jobId == null
                        ? () => _deletePost(post)
                        : null,
                  );
                },
              ),
            ),
    );
  }
}

// MY POST CARD
class _MyPostCard extends StatelessWidget {
  final FeedPost post;
  final VoidCallback onTap;
  final VoidCallback? onDelete; // null = non-deletable (job post)

  const _MyPostCard({required this.post, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: post.authorName, url: post.authorAvatar),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          post.timeAgo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Post Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: post.postType.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      post.postType.label,
                      style: TextStyle(
                        color: post.postType.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Delete / actions button
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message:
                          'Job posts are managed in your employer dashboard',
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Content
              if (post.content.isNotEmpty)
                Text(
                  post.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),

              // Linked job badge
              if (post.postType == PostType.job && post.linkedJob != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFD9FF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.work,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.linkedJob!.jobTitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1E40AF),
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              post.linkedJob!.companyName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Media Snapshot
              if (post.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: post.mediaUrls.first,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey.shade100, height: 140),
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.grey.shade100, height: 140),
                      ),
                      if (post.mediaUrls.length > 1)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${post.mediaUrls.length - 1} more',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Stats row
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.favorite, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 4),
                  Text(
                    '${post.likeCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.mode_comment,
                    size: 16,
                    color: Colors.blueAccent.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// AVATAR WIDGET
class _Avatar extends StatelessWidget {
  final String name;
  final String? url;

  const _Avatar({required this.name, this.url});

  @override
  Widget build(BuildContext context) {
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
    ];
    final color = name.isEmpty
        ? palette[0]
        : palette[name.codeUnitAt(0) % palette.length];

    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _Fb(color: color, name: name),
        ),
      );
    }
    return _Fb(color: color, name: name);
  }
}

class _Fb extends StatelessWidget {
  final Color color;
  final String name;
  const _Fb({required this.color, required this.name});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 20,
    backgroundColor: color,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  );
}
