import 'package:flutter/material.dart';
import 'package:jobify/social_feed.dart';
import 'job_discovery.dart';
import 'user.dart';

class NavigationMenu extends StatefulWidget {
  final User user;
  const NavigationMenu({super.key, required this.user});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  int selectedIndex = 0;

  // Job Seeker Screen
  final jobSeekerScreens=[
    SocialFeed(),
    JobDiscovery(),
    // TODO
    // Application(),
    // Profile();
  ];

  // Job Seeker Menu
  List<NavigationDestination> get jobSeekerItems => const [
    NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.work), label: 'Jobs'),
    NavigationDestination(icon: Icon(Icons.description), label: 'Applications'),
    NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
  ];

  // Company Screen
  final companyScreens=[
    SocialFeed(),
    JobDiscovery(),
    // TODO
    // Post(),
    // Profile();
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
    bool isJobSeeker = widget.user.role == 'job_seeker';
    
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
