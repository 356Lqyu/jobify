import 'package:flutter/material.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/social/social_post_details.dart';
import 'package:jobify/job_post/job_detail_employer.dart';

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
      setState(() {
        _myPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load your posts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePost(FeedPost post) async {
    // Don't allow deletion of job posts (linked to a real job)
    if (post.jobId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job posts cannot be deleted.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final success = await _repo.deletePost(post.postId);
    if (success && mounted) {
      setState(() {
        _myPosts.removeWhere((p) => p.postId == post.postId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete post'), backgroundColor: Colors.red),
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
      _loadMyPosts();
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SocialPostDetails(post: post, currentUser: widget.currentUser),
        ),
      );
      _loadMyPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('My Post'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _myPosts.isEmpty
          ? const Center(
        child: Text(
          'You haven\'t created any posts yet.\nTap + to share something!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadMyPosts,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _myPosts.length,
          itemBuilder: (ctx, i) {
            final post = _myPosts[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () => _viewPost(post),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: post.authorAvatar.isNotEmpty
                                ? NetworkImage(post.authorAvatar)
                                : null,
                            child: post.authorAvatar.isEmpty
                                ? Text(post.authorName.isNotEmpty
                                ? post.authorName[0].toUpperCase()
                                : '?')
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.authorName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  post.timeAgo,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: post.postType.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              post.postType.label,
                              style: TextStyle(color: post.postType.color, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (post.mediaUrls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(Icons.image, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${post.mediaUrls.length} image(s)',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Only show delete button for non-job posts
                      if (post.jobId == null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deletePost(post),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}