// lib/social/saved_posts_page.dart
import 'package:flutter/material.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/social/social_post_details.dart';
import 'package:jobify/discovery/job_details.dart';
import 'package:jobify/data/job_repository.dart';

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
      setState(() {
        _savedPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load saved posts: $e';
        _isLoading = false;
      });
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
          builder: (_) => JobDetailPage(
            job: job!,
            currentUser: widget.currentUser,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SocialPostDetails(
            post: post,
            currentUser: widget.currentUser,
          ),
        ),
      );
    }
    // Refresh after returning (in case the user unsaved the post)
    _loadSavedPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Posts'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _savedPosts.isEmpty
          ? const Center(
        child: Text(
          'No saved posts yet.\nTap the bookmark icon on any post to save it.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadSavedPosts,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _savedPosts.length,
          itemBuilder: (ctx, i) {
            final post = _savedPosts[i];
            return _SavedPostCard(
              post: post,
              onTap: () => _navigateToPost(context, post),
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

  const _SavedPostCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
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
            ],
          ),
        ),
      ),
    );
  }
}