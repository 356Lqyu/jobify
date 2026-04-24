import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/social/social_feed_provider.dart';

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
    if (mounted) {
      if (c != null) {
        setState(() {
          _comments.insert(0, c);
          _post.commentCount++;
          _submitting = false;
        });
        showFeedSnackBar(
          context,
          'Comment posted',
          icon: Icons.check_circle_outline,
        );
      } else {
        setState(() => _submitting = false);
        showFeedSnackBar(context, 'Failed to post comment', isError: true);
      }
    }
  }

  void _toggleLike() async {
    final wasLiked = _post.isLiked;
    setState(() {
      _post.isLiked = !wasLiked;
      _post.likeCount += wasLiked ? -1 : 1;
    });
    showFeedSnackBar(
      context,
      wasLiked ? 'Like removed' : 'Post liked',
      icon: wasLiked ? Icons.favorite_border : Icons.favorite,
    );
    final result = await _repo.toggleLike(_post.postId, wasLiked);
    if (result == wasLiked && mounted) {
      setState(() {
        _post.isLiked = wasLiked;
        _post.likeCount += wasLiked ? 1 : -1;
      });
      showFeedSnackBar(context, 'Failed to update like', isError: true);
    }
  }

  void _toggleSave() async {
    final wasSaved = _post.isSaved;
    setState(() => _post.isSaved = !wasSaved);
    showFeedSnackBar(
      context,
      wasSaved ? 'Post unsaved' : 'Post saved',
      icon: wasSaved ? Icons.bookmark_outline : Icons.bookmark,
    );
    final result = await _repo.toggleSavePost(_post.postId, wasSaved);
    if (result == wasSaved && mounted) {
      setState(() => _post.isSaved = wasSaved);
      showFeedSnackBar(context, 'Failed to save post', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnPost = _post.userId == widget.currentUser.userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (!isOwnPost)
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey(_post.isSaved),
                  color: Colors.white,
                ),
              ),
              onPressed: _toggleSave,
              tooltip: _post.isSaved ? 'Unsave' : 'Save',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _PostBody(
                  post: _post,
                  currentUser: widget.currentUser,
                  onLikeTap: _toggleLike,
                  onSaveTap: isOwnPost ? null : _toggleSave,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0EAFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_post.commentCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loadingComments)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No comments yet.\nBe the first to comment!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  )
                else
                  ..._comments.map((c) {
                    final isMe = c.userId == widget.currentUser.userId;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Avatar(
                            name: isMe ? 'You' : c.authorName,
                            url: isMe
                                ? widget.currentUser.profileImageUrl
                                : c.authorAvatar,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
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
                                        isMe ? 'You' : c.authorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        c.timeAgo,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.commentText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    onSubmitted: (_) => _submitComment(),
                    decoration: InputDecoration(
                      hintText: 'Write a comment…',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  child: _submitting
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _submitComment,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- POST BODY --------------------
class _PostBody extends StatelessWidget {
  final FeedPost post;
  final Users currentUser;
  final VoidCallback onLikeTap;
  final VoidCallback? onSaveTap;

  const _PostBody({
    required this.post,
    required this.currentUser,
    required this.onLikeTap,
    this.onSaveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(
                  name: post.authorName,
                  url: post.authorAvatar,
                  radius: 22,
                ),
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
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (post.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                          ],
                        ],
                      ),
                      if (post.authorSubtitle.isNotEmpty)
                        Text(
                          post.authorSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                      Text(
                        post.timeAgo,
                        style: const TextStyle(
                          fontSize: 11,
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
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: post.postType.color.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        post.postType.icon,
                        size: 11,
                        color: post.postType.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.postType.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: post.postType.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SelectableText(
              post.content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
          // 🔹 Hashtags (non‑clickable, just styled text)
          if (post.hashtags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: post.hashtags
                    .map(
                      (tag) => Text(
                        '#$tag',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (post.mediaUrls.isNotEmpty) _MediaGrid(urls: post.mediaUrls),
          if (post.postType == PostType.job && post.linkedJob != null)
            _LinkedJobCard(job: post.linkedJob!),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
            child: Row(
              children: [
                _ActionBtn(
                  icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: post.likeCount.toString(),
                  color: post.isLiked
                      ? const Color(0xFFEF4444)
                      : Colors.blueGrey,
                  onTap: onLikeTap,
                ),
                _ActionBtn(
                  icon: Icons.mode_comment_outlined,
                  label: post.commentCount.toString(),
                  color: Colors.blueGrey,
                  onTap: () {},
                ),
                _ActionBtn(
                  icon: Icons.share_outlined,
                  label: '',
                  color: Colors.blueGrey,
                  onTap: () {},
                ),
                const Spacer(),
                if (onSaveTap != null)
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                        key: ValueKey(post.isSaved),
                        size: 20,
                        color: post.isSaved
                            ? const Color(0xFF2563EB)
                            : Colors.blueGrey,
                      ),
                    ),
                    onPressed: onSaveTap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- MEDIA GRID --------------------
class _MediaGrid extends StatelessWidget {
  final List<String> urls;
  const _MediaGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: urls.first,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(height: 220, color: Colors.grey.shade100),
            errorWidget: (_, __, ___) => Container(
              height: 220,
              color: Colors.grey.shade100,
              child: const Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                placeholder: (_, __) => Container(color: Colors.grey.shade100),
                errorWidget: (_, __, ___) =>
                    Container(color: Colors.grey.shade100),
              ),
              if (i == 3 && urls.length > 4)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      '+${urls.length - 4}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- LINKED JOB CARD --------------------
class _LinkedJobCard extends StatelessWidget {
  final JobPost job;
  const _LinkedJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFD9FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.work_outline, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.jobTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E40AF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  job.companyName,
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          Text(
            job.salaryDisplay,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF059669),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- SMALL WIDGETS --------------------
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  const _Avatar({required this.name, this.url, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, __) => _initials(),
          errorWidget: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final displayName = name.trim().isEmpty ? '?' : name;
    final initials = displayName
        .split(' ')
        .take(2)
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
        .join();
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
    ];
    final color = displayName == '?'
        ? palette[0]
        : palette[displayName.codeUnitAt(0) % palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.65,
        ),
      ),
    );
  }
}
