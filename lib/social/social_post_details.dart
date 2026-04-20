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
    if (mounted) setState(() { _comments = list; _loadingComments = false; });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _post.isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _post.isSaved ? const Color(0xFF2563EB) : Colors.blueGrey,
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
                _PostBody(post: _post, onLikeTap: _toggleLike),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      const Text(
                        'Comments',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0EAFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_post.commentCount}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loadingComments)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No comments yet.\nBe the first to comment!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.blueGrey, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ..._comments.map((c) => _CommentTile(comment: c)).toList(),
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

// ─────────────────────────────────────────────────────────────────────────────
// POST BODY
// ─────────────────────────────────────────────────────────────────────────────
class _PostBody extends StatelessWidget {
  final FeedPost post;
  final VoidCallback onLikeTap;
  const _PostBody({required this.post, required this.onLikeTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DetailAvatar(name: post.authorName, url: post.authorAvatar),
              const SizedBox(width: 10),
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
                                fontSize: 14,
                                color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
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
                            fontSize: 11, color: Colors.blueGrey)),
                  ],
                ),
              ),
              _DetailTypeBadge(type: post.postType),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: const TextStyle(
                fontSize: 15, color: Colors.black87, height: 1.5),
          ),
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: post.hashtags
                  .map((h) => Text('#$h',
                  style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 13,
                      fontWeight: FontWeight.w500)))
                  .toList(),
            ),
          ],
          if (post.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MediaGrid(urls: post.mediaUrls),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(
            '${post.likeCount} likes · ${post.commentCount} comments',
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 4),
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

// ─────────────────────────────────────────────────────────────────────────────
// COMMENT TILE
// ─────────────────────────────────────────────────────────────────────────────
class _CommentTile extends StatelessWidget {
  final PostComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailAvatar(name: comment.authorName, url: comment.authorAvatar, radius: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.authorName.isEmpty ? 'Anonymous' : comment.authorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.black87),
                      ),
                      const Spacer(),
                      Text(comment.timeAgo,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.blueGrey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment.commentText,
                      style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMENT INPUT BAR
// ─────────────────────────────────────────────────────────────────────────────
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
          _DetailAvatar(name: avatarName, url: avatarUrl, radius: 18),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
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
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: urls[0],
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => const AspectRatio(
              aspectRatio: 16 / 9, child: ColoredBox(color: Color(0xFFE0EAFF))),
          errorWidget: (_, __, ___) => const AspectRatio(
              aspectRatio: 16 / 9,
              child: Icon(Icons.broken_image_outlined, color: Colors.blueGrey)),
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

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _DetailAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  const _DetailAvatar({required this.name, this.url, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
          radius: radius, backgroundImage: CachedNetworkImageProvider(url!));
    }
    const palette = [
      Color(0xFF6366F1), Color(0xFF2563EB), Color(0xFF10B981),
      Color(0xFFEC4899), Color(0xFFF59E0B),
    ];
    final color = name.isEmpty ? palette[0] : palette[name.codeUnitAt(0) % palette.length];
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').take(2).map((s) => s[0].toUpperCase()).join();
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

class _DetailTypeBadge extends StatelessWidget {
  final PostType type;
  const _DetailTypeBadge({required this.type});

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
                fontSize: 10, color: type.color, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _DetailActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _DetailActionBtn(
      {required this.icon,
        required this.label,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}