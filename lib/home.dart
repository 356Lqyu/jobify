import 'package:flutter/material.dart';
import 'package:jobify/setting_page.dart';
import 'package:jobify/social/social_feed.dart';
import 'package:jobify/users.dart';
import 'package:jobify/bottom_bar.dart';
import 'package:jobify/job_post/create_job_post.dart';
import 'package:jobify/job_post/job_post_management.dart';
import 'package:jobify/profile_page.dart';

class HomePage extends StatefulWidget {
  final Users user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  // Key for the My Jobs page
  final GlobalKey<JobPostManagementPageState> _jobsPageKey = GlobalKey();

  late final List<Widget> _screens;
  late final List<BottomBarItem> _items;

  bool get _isJobSeeker =>
      widget.user.role.toUpperCase() == 'JOB_SEEKER';

  @override
  void initState() {
    super.initState();
    _buildScreensAndItems();
  }

  void _buildScreensAndItems() {
    if (_isJobSeeker) {
      _screens = [
        SocialFeedPage(user: widget.user),
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
          label: 'Profile',
        ),
      ];
    } else {
      // ── Company / Poster tabs ────────────────────────────────────────
      // widget.user.userId IS the company's user_id in company_profile table
      _screens = [
        SocialFeedPage(user: widget.user),          // Home tab
        JobPostManagementPage(key: _jobsPageKey),                    // My Jobs tab
        const TalentScreen(),
        CreateJobPost(
          onPostSuccess: (){
            // Switch to the "My Jobs" tab after posting
            _jobsPageKey.currentState?.loadJobs();
            setState(() {
              selectedIndex = 1;
            });
          },
        ),                            // Post tab (create new)
        ProfilePage(),
        const PostScreen(),
        const SettingPage(),
      ];

      _items = const [
        BottomBarItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'Home',
        ),
        BottomBarItem(
          icon: Icons.work_outline,
          activeIcon: Icons.work,
          label: 'My Jobs',
        ),
        BottomBarItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          label: 'Talent',
        ),
        BottomBarItem(
          icon: Icons.add_box_outlined,
          activeIcon: Icons.add_box,
          label: 'Post',
        ),
        BottomBarItem(
          icon: Icons.business_outlined,
          activeIcon: Icons.business,
          label: 'Company',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

class ProfileScreen extends StatelessWidget {
  final Users user;
  const ProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Profile: ${user.fullname}"),
    );
  }
}

class TalentScreen extends StatelessWidget {
  const TalentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Talent Screen"));
  }
}

class PostScreen extends StatelessWidget {
  const PostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Post Screen"));
  }
}