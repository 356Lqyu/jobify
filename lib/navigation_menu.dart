import 'package:flutter/material.dart';
import 'package:jobify/job_post/job_post_management.dart';
import 'social/social_feed.dart';
import 'discovery/job_discovery.dart';
import 'users.dart';

class NavigationMenu extends StatefulWidget {
  final Users user;
  const NavigationMenu({super.key, required this.user});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  int selectedIndex = 0;

  // Job Seeker Menu
  List<NavigationDestination> get jobSeekerItems => const [
    NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.work), label: 'Jobs'),
    NavigationDestination(icon: Icon(Icons.description), label: 'Applications'),
    NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
  ];

  // Company Menu
  List<NavigationDestination> get companyItems => const [
  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
  NavigationDestination(icon: Icon(Icons.work), label: 'Jobs'),
  NavigationDestination(icon: Icon(Icons.add_box), label: 'Post'),
  NavigationDestination(icon: Icon(Icons.person), label: 'Profile')
  ];

  @override
  Widget build(BuildContext context) {
    bool isJobSeeker = widget.user.role == 'JOB_SEEKER';

    final jobSeekerScreens = [
      SocialFeedPage(user: widget.user),
      //JobDiscoveryPage(user: widget.user),
      Container(),
      Container(),
    ];

    final companyScreens = [
      SocialFeedPage(user: widget.user),
      JobPostManagementPage(),
      Container(),
      Container(),
    ];
    
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        height: 80,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index){
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: isJobSeeker? jobSeekerItems : companyItems,
      ),
      body: isJobSeeker? jobSeekerScreens[selectedIndex] : companyScreens[selectedIndex]
    );
  }
}
