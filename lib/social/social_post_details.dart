import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/users/users.dart';

class SocialPostDetails extends StatefulWidget {
  final FeedPost post;
  final Users currentUser;

  const SocialPostDetails({
    super.key,
    required this.post,
    required this.currentUser,
  });

  @override
  State<SocialPostDetails> createState() => _SocialPostDetailsState();
}

class _SocialPostDetailsState extends State<SocialPostDetails> {
  final _commentCtrl = TextEditingController();
  final _repo = FeedRepository();

  List<PostComment> _comments = [];
  bool _loadingComments = true;
  bool _submitting = false;
  late FeedPost _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    final list = await _repo.fetchComments(_post.postId);
    if (mounted) {
      setState(() {
      _comments = list;
      _loadingComments = false;
    });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    _commentCtrl.clear();

    final c = await _repo.addComment(_post.postId, text);
    if (c != null && mounted) {
      setState(() {
        _comments.insert(0, c);
        _post.commentCount++;
        _submitting = false;
      });
    } else {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toggleLike() async {
    final wasLiked = _post.isLiked;
    setState(() {
      _post.isLiked = !wasLiked;
      _post.likeCount += wasLiked ? -1 : 1;
    });
    await _repo.toggleLike(_post.postId, wasLiked);
  }

  void _toggleSave() async {
    final wasSaved = _post.isSaved;
    setState(() => _post.isSaved = !wasSaved);
    await _repo.toggleSavePost(_post.postId, wasSaved);
  }

  Future<void> _confirmDelete() async {
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

    final success = await _repo.deletePost(_post.postId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete post'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Post Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.post.userId == widget.currentUser.userId && widget.post.jobId == null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: Icon(
              _post.isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
            ),
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                // Post card (improved styling)
                Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _PostBody(post: _post, onLikeTap: _toggleLike),
                ),
                // Comments header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(
                    children: [
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0EAFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_post.commentCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Comments list
                if (_loadingComments)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_comments.isEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.blueGrey),
                        SizedBox(height: 12),
                        Text(
                          'No comments yet.\nBe the first to comment!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.blueGrey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  ..._comments.map((c) => _CommentTile(comment: c,  currentUser: widget.currentUser,)).toList(),
              ],
            ),
          ),
          _CommentInputBar(
            ctrl: _commentCtrl,
            submitting: _submitting,
            avatarName: widget.currentUser.fullname,
            avatarUrl: widget.currentUser.profileImageUrl,
            onSubmit: _submitComment,
          ),
        ],
      ),
    );
  }
}

// ===================== POST BODY =====================
class _PostBody extends StatelessWidget {
  final FeedPost post;
  final VoidCallback onLikeTap;
  const _PostBody({required this.post, required this.onLikeTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              _DetailAvatar(name: post.authorName, url: post.authorAvatar, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                        ],
                      ],
                    ),
                    if (post.authorSubtitle.isNotEmpty)
                      Text(
                        post.authorSubtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    Text(
                      post.timeAgo,
                      style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              _DetailTypeBadge(type: post.postType),
            ],
          ),
          const SizedBox(height: 14),
          // Content
          Text(
            post.content,
            style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
          ),
          // Hashtags
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: post.hashtags
                  .map((h) => Text(
                '#$h',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ))
                  .toList(),
            ),
          ],
          // Media
          if (post.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MediaGrid(urls: post.mediaUrls),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Like & comment counts
          Text(
            '${post.likeCount} likes · ${post.commentCount} comments',
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 4),
          // Action buttons
          Row(
            children: [
              _DetailActionBtn(
                icon: post.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: 'Like',
                color: post.isLiked ? const Color(0xFF2563EB) : Colors.blueGrey,
                onTap: onLikeTap,
              ),
              const SizedBox(width: 8),
              const _DetailActionBtn(
                icon: Icons.chat_bubble_outline,
                label: 'Comment',
                color: Colors.blueGrey,
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// COMMENT TILE
class _CommentTile extends StatelessWidget {
  final PostComment comment;
  final Users currentUser;
  const _CommentTile({required this.comment, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = comment.userId == currentUser.userId;
    final displayName = isCurrentUser ? 'You' : comment.authorName;
    final avatarUrl = isCurrentUser ? currentUser.profileImageUrl : comment.authorAvatar;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailAvatar(name: displayName, url: avatarUrl, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        comment.timeAgo,
                        style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment.commentText,
                    style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


//COMMENT INPUT BAR
class _CommentInputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool submitting;
  final String avatarName;
  final String? avatarUrl;
  final VoidCallback onSubmit;

  const _CommentInputBar({
    required this.ctrl,
    required this.submitting,
    required this.avatarName,
    required this.avatarUrl,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          _DetailAvatar(name: avatarName, url: avatarUrl, radius: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'Write a comment…',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: submitting ? null : onSubmit,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: submitting ? Colors.blueGrey.shade200 : const Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              child: submitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== MEDIA GRID (unchanged, but kept for completeness) =====================
class _MediaGrid extends StatelessWidget {
  final List<String> urls;
  const _MediaGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: urls[0],
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Color(0xFFE0EAFF)),
          ),
          errorWidget: (_, __, ___) => const AspectRatio(
            aspectRatio: 16 / 9,
            child: Icon(Icons.broken_image_outlined, color: Colors.blueGrey),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      children: urls
          .take(4)
          .map((url) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => const ColoredBox(color: Color(0xFFE0EAFF)),
          errorWidget: (_, __, ___) =>
          const Icon(Icons.broken_image_outlined, color: Colors.blueGrey),
        ),
      ))
          .toList(),
    );
  }
}

class _DetailAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  const _DetailAvatar({required this.name, this.url, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildInitialsAvatar(),
          errorWidget: (_, __, ___) => _buildInitialsAvatar(),
        ),
      );
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final displayName = name.trim().isEmpty ? 'User' : name;
    final initials = displayName
        .split(' ')
        .take(2)
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
        .join();
    final fallbackInitials = initials.isEmpty ? '?' : initials;
    const palette = [
      Color(0xFF6366F1), Color(0xFF2563EB), Color(0xFF10B981),
      Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF0EA5E9),
    ];
    final color = displayName.isEmpty
        ? palette[0]
        : palette[displayName.codeUnitAt(0) % palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        fallbackInitials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.65,
        ),
      ),
    );
  }
}

class _DetailTypeBadge extends StatelessWidget {
  final PostType type;
  const _DetailTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: type.color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: type.color.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(type.icon, size: 12, color: type.color),
        const SizedBox(width: 4),
        Text(
          type.label,
          style: TextStyle(
            fontSize: 11,
            color: type.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DetailActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _DetailActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}