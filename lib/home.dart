import 'package:flutter/material.dart';
import 'package:jobify/setting_page.dart';
import 'package:jobify/social/social_feed.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/bottom_bar.dart';
import 'package:jobify/job_post/create_job_post.dart';
import 'package:jobify/job_post/job_post_management.dart';
import 'package:jobify/users/profile_page.dart';
import 'package:provider/provider.dart';
import 'users/user_provider.dart';

class HomePage extends StatefulWidget {
  final Users user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  late final UserProvider _userProvider;

  final GlobalKey<JobPostManagementPageState> _jobsPageKey = GlobalKey();

  late final List<Widget> _screens;
  late final List<BottomBarItem> _items;

  bool get _isJobSeeker =>
      widget.user.role.toUpperCase() == 'JOB_SEEKER';

  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _buildScreensAndItems();
  }

  void _buildScreensAndItems() {
    if (_isJobSeeker) {
      _screens = [
        SocialFeedPage(user: widget.user),
        //DiscoverScreen(user:widget.user),
        const DiscoverScreen(),
        const AppliedScreen(),
        const SettingPage(),
      ];

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
          label: 'Applied',
        ),
        BottomBarItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Account',
        ),
      ];
    } else {
      _screens = [
        SocialFeedPage(user: widget.user),
        //DiscoverScreen(user:widget.user),
        const DiscoverScreen(),
        JobPostManagementPage(key: _jobsPageKey),
        CreateJobPost(
          onPostSuccess: () {
            _jobsPageKey.currentState?.loadJobs();
            setState(() {
              selectedIndex = 1;
            });
          },
        ),
        const SettingPage(),
      ];

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
          icon: Icons.work_outline,
          activeIcon: Icons.work,
          label: 'My Jobs',
        ),
        BottomBarItem(
          icon: Icons.add_box_outlined,
          activeIcon: Icons.add_box,
          label: 'Post',
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
        body: IndexedStack(
          index: selectedIndex,
          children: _screens,
        ),
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

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Discover Screen"));
  }
}

class AppliedScreen extends StatelessWidget {
  const AppliedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Applied Screen"));
  }
}