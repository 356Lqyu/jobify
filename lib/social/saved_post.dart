import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/social/social_post_details.dart';
import 'package:jobify/discovery/job_details.dart';
import 'package:jobify/data/job_repository.dart';
import 'package:jobify/social/social_feed_provider.dart';

class SavedPostsPage extends StatefulWidget {
  final Users currentUser;
  const SavedPostsPage({super.key, required this.currentUser});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final FeedRepository _feedRepo = FeedRepository();
  final JobRepository _jobRepo = JobRepository();
  List<FeedPost> _savedPosts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final posts = await _feedRepo.fetchSavedPosts();
      if (mounted) {
        setState(() {
          _savedPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load saved posts';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unsavePost(FeedPost post) async {
    // Optimistic UI update
    setState(() {
      _savedPosts.removeWhere((p) => p.postId == post.postId);
    });

    showFeedSnackBar(context, 'Post removed from saved');

    final success = await _feedRepo.toggleSavePost(
      post.postId,
      true, // It was currently saved
      jobId: post.jobId,
    );

    // Revert if it failed
    if (success == true && mounted) {
      showFeedSnackBar(context, 'Failed to unsave post', isError: true);
      _loadSavedPosts();
    }
  }

  Future<void> _navigateToPost(BuildContext context, FeedPost post) async {
    JobPost? job;
    if (post.postType == PostType.job) {
      if (post.linkedJob != null) {
        job = post.linkedJob;
      } else if (post.jobId != null) {
        job = await _jobRepo.fetchJobById(post.jobId!);
      }
    }

    if (post.postType == PostType.job && job != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              JobDetailPage(job: job!, currentUser: widget.currentUser),
        ),
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
    // Refresh after returning in case they unsaved it from the detail page
    _loadSavedPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Saved Posts',
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
                    onPressed: _loadSavedPosts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _savedPosts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 64,
                      color: Colors.blueGrey.shade200,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No saved posts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the bookmark icon on any post\nto save it for later.',
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
              onRefresh: _loadSavedPosts,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
                itemCount: _savedPosts.length,
                itemBuilder: (ctx, i) {
                  final post = _savedPosts[i];
                  return _SavedPostCard(
                    post: post,
                    onTap: () => _navigateToPost(context, post),
                    onUnsave: () => _unsavePost(post),
                  );
                },
              ),
            ),
    );
  }
}

class _SavedPostCard extends StatelessWidget {
  final FeedPost post;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  const _SavedPostCard({
    required this.post,
    required this.onTap,
    required this.onUnsave,
  });

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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onUnsave,
                    child: const Icon(
                      Icons.bookmark,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
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

              // Linked Job Snippet
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
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E40AF),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${post.linkedJob!.companyName} • ${post.linkedJob!.location}',
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

              // Media Snippet
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
            ],
          ),
        ),
      ),
    );
  }
}

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
