import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:jobify/setting_page.dart';
import 'package:jobify/social/social_feed.dart';
import 'package:jobify/social/social_post_details.dart';
import 'package:jobify/discovery/job_details.dart';
import 'package:jobify/job_post/job_detail_employer.dart';
import 'package:jobify/data/job_repository.dart';
import 'package:jobify/data/feed_repository.dart';
import 'package:jobify/data/local_db.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/bottom_bar.dart';
import 'package:jobify/job_post/create_job_post.dart';
import 'package:jobify/job_post/job_post_management.dart';
import 'package:provider/provider.dart';
import 'discovery/job_discovery.dart';
import 'users/user_provider.dart';
import 'job/my_applications.dart';

class HomePage extends StatefulWidget {
  final Users user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  static bool _isDeepLinkActive = false;
  static String? _activeDeepLinkUrl;

  int selectedIndex = 0;
  late final UserProvider _userProvider;

  final GlobalKey<JobPostManagementPageState> _jobsPageKey = GlobalKey();

  late final List<Widget> _screens;
  late final List<BottomBarItem> _items;

  // App Links state
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  bool get _isJobSeeker => widget.user.role.toUpperCase() == 'JOB_SEEKER';

  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _buildScreensAndItems();
    _initDeepLinks();
  }

  @override
  void dispose() {
    // Cancel the stream subscription when the page is closed
    _linkSubscription?.cancel();
    super.dispose();
  }

  // DEEP LINKING
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Listen to incoming links
    _linkSubscription = _appLinks.uriLinkStream.listen(
          (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint("Link stream error: $err");
      },
    );
  }

  void _handleDeepLink(Uri uri) async {
    final uriString = uri.toString();

    if (_isDeepLinkActive && _activeDeepLinkUrl == uriString) {
      debugPrint("Intercepted duplicate Deep Link trigger: $uriString");
      return;
    }

    _isDeepLinkActive = true;
    _activeDeepLinkUrl = uriString;

    try {
      if (uri.host == 'jobify.app') {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          if (pathSegments[0] == 'job' && pathSegments.length > 1) {
            final jobId = pathSegments[1];
            await _navigateToJobDetails(jobId);
          } else if (pathSegments[0] == 'post' && pathSegments.length > 1) {
            final postId = pathSegments[1];
            await _navigateToSocialPost(postId);
          }
        }
      }
    } finally {
      if (mounted && _activeDeepLinkUrl == uriString) {
        _isDeepLinkActive = false;
        _activeDeepLinkUrl = null;
      }
    }
  }

  Future<void> _navigateToJobDetails(String jobId) async {
    final repo = JobRepository();
    final job = await repo.fetchJobById(jobId);

    if (job == null || !mounted) return;

    // Route based on ownership
    if (widget.user.userId == job.createdBy) {
      final jobMap =
          await LocalDB.getCachedJobMapById(job.jobId) ?? job.toLocalDbMap();

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JobDetailEmployer(job: jobMap)),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailPage(job: job, currentUser: widget.user),
        ),
      );
    }
  }

  Future<void> _navigateToSocialPost(String postId) async {
    final repo = FeedRepository();
    final post = await repo.fetchPostById(postId);

    if (post == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SocialPostDetails(post: post, currentUser: widget.user),
      ),
    );
  }
  // --------------------------

  void _buildScreensAndItems() {
    if (_isJobSeeker) {
      // Job Seeker Screens
      _screens = [
        SocialFeedPage(user: widget.user),
        DiscoveryJob(user: widget.user),
        MyApplicationsPage(),
        const SettingPage(),
      ];

      // Job Seeker Bottom Navigation Items
      _items = const [
        BottomBarItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'Home',
        ),
        BottomBarItem(
          icon: Icons.search_outlined,
          activeIcon: Icons.search,
          label: 'Discover',
        ),
        BottomBarItem(
          icon: Icons.description_outlined,
          activeIcon: Icons.description,
          label: 'Applications',
        ),
        BottomBarItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Account',
        ),
      ];
    } else {
      // Employer Screens
      _screens = [
        SocialFeedPage(user: widget.user),
        DiscoveryJob(user: widget.user),
        CreateJobPost(
          onPostSuccess: () {
            _jobsPageKey.currentState?.loadJobs();
            setState(() {
              selectedIndex = 1;
            });
          },
        ),
        JobPostManagementPage(key: _jobsPageKey),
        const SettingPage(),
      ];

      // Employer Bottom Navigation Items
      _items = const [
        BottomBarItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'Home',
        ),
        BottomBarItem(
          icon: Icons.search_outlined,
          activeIcon: Icons.search,
          label: 'Discover',
        ),
        BottomBarItem(
          icon: Icons.add_box_outlined,
          activeIcon: Icons.add_box,
          label: 'Post',
        ),
        BottomBarItem(
          icon: Icons.work_outline,
          activeIcon: Icons.work,
          label: 'My Jobs',
        ),
        BottomBarItem(
          icon: Icons.business_outlined,
          activeIcon: Icons.business,
          label: 'Account',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent going back to login screen
        if (selectedIndex != 0) {
          setState(() {
            selectedIndex = 0;
          });
          return false;
        }
        // Show exit dialog if on home screen
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        body: IndexedStack(index: selectedIndex, children: _screens),
        bottomNavigationBar: CustomBottomBar(
          currentIndex: selectedIndex,
          onTap: (index) => setState(() => selectedIndex = index),
          items: _items,
          accentColor: Colors.blue,
        ),
      ),
    );
  }
}
