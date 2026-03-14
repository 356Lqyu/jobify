import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jobify',
      theme: ThemeData(
        primarySwatch: Colors.blue),
      home: const FeedPage(), //const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
          ],
        ),
      ),
    );
  }
}

// ---------- Model ----------
enum PostType { job, update }

class Post {
  final String companyName;
  final String companyInitials;
  final PostType type;
  final String timeAgo;
  final String content;
  final String? jobTitle;
  final int baseLikes;      // likes from other users
  final int baseComments;   // comments from other users
  final int shares;

  Post({
    required this.companyName,
    required this.companyInitials,
    required this.type,
    required this.timeAgo,
    required this.content,
    this.jobTitle,
    required this.baseLikes,
    required this.baseComments,
    required this.shares,
  });
}

// ---------- Mock Data ----------
final List<Post> mockPosts = [
  Post(
    companyName: 'Tech Solutions Inc.',
    companyInitials: 'TS',
    type: PostType.job,
    timeAgo: '2h ago',
    content:
    'We are hiring! Join our team as a Senior Frontend Developer. Remote position with competitive salary and benefits.',
    jobTitle: 'Senior Frontend Developer',
    baseLikes: 45,
    baseComments: 12,
    shares: 8,
  ),
  Post(
    companyName: 'Creative Agency',
    companyInitials: 'CA',
    type: PostType.update,
    timeAgo: '5h ago',
    content:
    'Excited to share that our team has grown to 100+ talented individuals! Thank you to everyone who has been part of this journey. 🎉',
    jobTitle: null,
    baseLikes: 120,
    baseComments: 24,
    shares: 15,
  ),
  Post(
    companyName: 'GreenTech Startup',
    companyInitials: 'GT',
    type: PostType.job,
    timeAgo: '1d ago',
    content:
    'Looking for a passionate Flutter Developer to build the next generation of sustainable apps. On-site in Berlin.',
    jobTitle: 'Flutter Developer',
    baseLikes: 32,
    baseComments: 5,
    shares: 3,
  ),
];

// ---------- Feed Page ----------
class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: false,
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: mockPosts.length,
        itemBuilder: (context, index) {
          return PostCard(post: mockPosts[index]);
        },
      ),
    );
  }
}

// ---------- Stateful Post Card ----------
class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked;
  late int _baseLikes;
  late int _baseComments;
  late List<String> _userComments;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _liked = false;
    _baseLikes = widget.post.baseLikes;
    _baseComments = widget.post.baseComments;
    _userComments = [];
  }

  int get displayLikes => _baseLikes + (_liked ? 1 : 0);
  int get displayComments => _baseComments + _userComments.length;

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
    });
  }

  void _postComment() {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _userComments.add(text);
        _commentController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: company initials, name, time
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    post.companyInitials,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.companyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        post.timeAgo,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Text(post.content),
            if (post.type == PostType.job) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  // TODO: navigate to job details
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.blue.shade700),
                ),
                child: Text('View Job: ${post.jobTitle}'),
              ),
            ],
            const SizedBox(height: 12),
            // Stats row with interactive like and comment counts
            Row(
              children: [
                // Like button with count
                Row(
                  children: [
                    IconButton(
                      onPressed: _toggleLike,
                      icon: Icon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                        color: _liked ? Colors.red : Colors.grey.shade700,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 2),
                    Text('$displayLikes'),
                  ],
                ),
                const SizedBox(width: 16),
                // Comment icon with count (non-interactive, just display)
                Row(
                  children: [
                    Icon(Icons.comment_outlined,
                        size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text('$displayComments'),
                  ],
                ),
                const SizedBox(width: 16),
                // Share icon with count
                Row(
                  children: [
                    Icon(Icons.share_outlined,
                        size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text('${post.shares}'),
                  ],
                ),
                const Spacer(),
                // Share link button
                TextButton(
                  onPressed: () {},
                  child: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Comment input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: null, // allow multiple lines if needed
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _postComment,
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                ),
              ],
            ),
            // Display user comments
            if (_userComments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._userComments.map((comment) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(child: Text(comment)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}