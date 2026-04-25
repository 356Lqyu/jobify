import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/social/social_feed_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  void _sharePost() {
    String deepLink = 'https://jobify.app/post/${_post.postId}';
    String shareText = '';

    if (_post.jobId != null && _post.linkedJob != null) {
      deepLink = 'https://jobify.app/job/${_post.linkedJob!.jobId}';
      shareText = 'Check out this job post: ${_post.linkedJob!.jobTitle} at ${_post.linkedJob!.companyName}!\n$deepLink';
    } else {
      shareText = 'Check out this social post by ${_post.authorName}!\n$deepLink';
    }

    Share.share(shareText);
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
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (!isOwnPost)
            IconButton(
              iconSize: 28,
              padding: const EdgeInsets.all(12),
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
                  onShareTap: _sharePost
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

class _PostBody extends StatelessWidget {
  final FeedPost post;
  final Users currentUser;
  final VoidCallback onLikeTap;
  final VoidCallback? onSaveTap;
  final VoidCallback onShareTap;


  const _PostBody({
    required this.post,
    required this.currentUser,
    required this.onLikeTap,
    this.onSaveTap,
    required this.onShareTap
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
          // Uses the new Paging Media Grid below
          if (post.mediaUrls.isNotEmpty) _MediaGrid(urls: post.mediaUrls),
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
                  onTap: onShareTap,
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

// MEDIA GRID (PAGING VIEW)
class _MediaGrid extends StatefulWidget {
  final List<String> urls;
  const _MediaGrid({required this.urls});

  @override
  State<_MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends State<_MediaGrid> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) return const SizedBox.shrink();

    // Single Image: Show full size (up to 400 height)
    if (widget.urls.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400, minHeight: 200),
            child: _buildImage(widget.urls.first),
          ),
        ),
      );
    }

    // Multiple Images: Paging Carousel view
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 350,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: widget.urls.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return _buildImage(widget.urls[index]);
                    },
                  ),
                  // Counter Indicator (Top Right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Dot Indicators (Bottom)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.urls.length, (index) {
              final isSelected = _currentIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : Colors.blueGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          Container(color: Colors.grey.shade100, height: 250),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade100,
        height: 250,
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
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
