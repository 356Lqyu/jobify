import 'package:flutter/material.dart';
import 'package:jobify/user.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MOCK DATA – replace with real Supabase calls later
// ═══════════════════════════════════════════════════════════════════════════

/// Represents a single item in the social feed.
class _FeedPost {
  final String companyInitials;   // e.g. "TS"
  final Color avatarColor;
  final String companyName;
  final String timeAgo;           // e.g. "2h ago"
  final String content;
  final bool isJobPost;           // true = show "View Job" button
  final String? jobTitle;         // only when isJobPost = true
  final int likeCount;
  final int commentCount;

  const _FeedPost({
    required this.companyInitials,
    required this.avatarColor,
    required this.companyName,
    required this.timeAgo,
    required this.content,
    this.isJobPost = false,
    this.jobTitle,
    required this.likeCount,
    required this.commentCount,
  });
}

final List<_FeedPost> _mockPosts = [
  _FeedPost(
    companyInitials: 'TS',
    avatarColor: Colors.indigo,
    companyName: 'Tech Solutions Inc.',
    timeAgo: '2h ago',
    content: 'We are hiring! Join our team as a Senior Frontend Developer. Remote position with competitive salary and benefits.',
    isJobPost: true,
    jobTitle: 'Senior Frontend Developer',
    likeCount: 24,
    commentCount: 5,
  ),
  _FeedPost(
    companyInitials: 'CA',
    avatarColor: Colors.teal,
    companyName: 'Creative Agency',
    timeAgo: '5h ago',
    content: 'Excited to share that our team has grown to 100+ talented individuals! Thank you to everyone who has been part of this journey. 🎉',
    isJobPost: false,
    likeCount: 45,
    commentCount: 12,
  ),
  _FeedPost(
    companyInitials: 'DI',
    avatarColor: Colors.deepPurple,
    companyName: 'Digital Innovations',
    timeAgo: '1d ago',
    content: 'Looking for a passionate Product Manager to lead our next big project. Great opportunity for growth!',
    isJobPost: true,
    jobTitle: 'Product Manager',
    likeCount: 18,
    commentCount: 3,
  ),
  _FeedPost(
    companyInitials: 'GS',
    avatarColor: Colors.orange,
    companyName: 'GreenStar Corp',
    timeAgo: '2d ago',
    content: 'We just launched our new sustainability initiative. Proud to be part of the green revolution! 🌱',
    isJobPost: false,
    likeCount: 91,
    commentCount: 22,
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
// PAGE
// ═══════════════════════════════════════════════════════════════════════════

class SocialFeedPage extends StatefulWidget {
  final User user;
  const SocialFeedPage({super.key, required this.user});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  // Tracks which posts the current user has liked (by index in mock list)
  final Set<int> _likedPosts = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── App Bar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Home',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            Text(
              'Discover jobs and company updates',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: navigate to notifications
            },
          ),
        ],
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: RefreshIndicator(
        // Pull-to-refresh placeholder
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          // TODO: re-fetch from Supabase
        },
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _mockPosts.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            return _FeedCard(
              post: _mockPosts[index],
              isLiked: _likedPosts.contains(index),
              onLike: () {
                setState(() {
                  if (_likedPosts.contains(index)) {
                    _likedPosts.remove(index);
                  } else {
                    _likedPosts.add(index);
                  }
                });
              },
              onComment: () {
                _showCommentSheet(context, _mockPosts[index]);
              },
              onShare: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share coming soon!')),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ── Bottom sheet for comments ─────────────────────────────────────────────
  void _showCommentSheet(BuildContext context, _FeedPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentSheet(post: post),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FEED CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _FeedCard extends StatelessWidget {
  final _FeedPost post;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _FeedCard({
    required this.post,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: avatar + company name + time ──────────────────────
          Row(
            children: [
              // Company avatar circle
              CircleAvatar(
                radius: 22,
                backgroundColor: post.avatarColor,
                child: Text(
                  post.companyInitials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Company name + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.companyName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (post.isJobPost) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.work_outline, size: 10, color: Colors.green.shade700),
                                const SizedBox(width: 3),
                                Text(
                                  'Hiring',
                                  style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                    Text(
                      post.timeAgo,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Options button
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                onPressed: () {},
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Post content ─────────────────────────────────────────────
          Text(
            post.content,
            style: const TextStyle(fontSize: 14, height: 1.45),
          ),

          // ── "View Job" button (only for job posts) ───────────────────
          if (post.isJobPost && post.jobTitle != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('View Job: ${post.jobTitle}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  // TODO: navigate to job detail page
                },
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Action row: Like | Comment | Share ───────────────────────
          Row(
            children: [
              // Like button
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onLike,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isLiked ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likeCount + (isLiked ? 1 : 0)}',
                        style: TextStyle(
                          color: isLiked ? Colors.red : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Comment button
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onComment,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${post.commentCount}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Share button
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onShare,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Share', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMMENT BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _CommentSheet extends StatefulWidget {
  final _FeedPost post;
  const _CommentSheet({required this.post});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _commentCtrl = TextEditingController();

  // Mock comments – replace with Supabase data later
  final List<Map<String, String>> _mockComments = [
    {'user': 'Alice Tan', 'text': 'This looks amazing! Would love to apply.'},
    {'user': 'Bob Lim', 'text': 'Great opportunity, shared with my network!'},
  ];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),

            Text('Comments (${widget.post.commentCount})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),

            // Comments list
            Expanded(
              child: ListView.builder(
                itemCount: _mockComments.length,
                itemBuilder: (context, i) => ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(_mockComments[i]['user']![0],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                  title: Text(_mockComments[i]['user']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(_mockComments[i]['text']!, style: const TextStyle(fontSize: 13)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            // Comment input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () {
                    // TODO: send comment to Supabase
                    _commentCtrl.clear();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}