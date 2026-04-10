import 'package:flutter/material.dart';
import 'package:jobify/social_feed.dart';
import 'package:jobify/user.dart';
import 'package:jobify/bottom_bar.dart';
import 'package:jobify/profile_page.dart';
import 'package:jobify/company_profile_page.dart';
import 'package:jobify/setting_page.dart';
import 'package:jobify/job_post_management.dart'; // employer dashboard
import 'package:jobify/create_job_post.dart';     // create new job/announcement

class HomePage extends StatefulWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

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
      // ── Job Seeker tabs ──────────────────────────────────────────────
      _screens = [
        SocialFeedPage(user: widget.user),
        SocialFeedPage(user: widget.user),
        SocialFeedPage(user: widget.user),
        SocialFeedPage(user: widget.user),
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
          badgeCount: 2, // TODO: replace with real count from Supabase
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
        JobPostManagementPage(),                    // My Jobs tab
        CreateJobPost(),                            // Post tab (create new)
        CompanyProfilePage(companyId: widget.user.userId), // Company profile
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