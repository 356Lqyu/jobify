import 'package:flutter/material.dart';
import 'package:jobify/users/profile_page.dart';
import 'package:jobify/data/user_repository.dart';
import 'package:jobify/data/local_db.dart';
import 'package:jobify/users/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/change_password.dart';
import 'package:jobify/job/resume_management_page.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final supabase = Supabase.instance.client;
  final UserRepository _userRepo = UserRepository();

  String? role;
  String? userName;
  String? companyName;
  String? profileImageUrl;

  bool showLogoutDialog = false;

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when coming back from ProfilePage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshProfileData();
      }
    });
  }


  Future<void> fetchUserInfo() async {
    // Get current user from provider or cache
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser ?? await _userRepo.getCurrentUser();

    if (user != null && mounted) {
      setState(() {
        role = user.role.toLowerCase();
        userName = user.fullname;
        profileImageUrl = user.profileImageUrl;
      });
    }

    // Fetch company name if employer (from cache)
    if (role?.toUpperCase() == 'POSTER') {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final companyProfile = await LocalDB.getCachedCompanyProfile(userId);
        if (companyProfile != null && mounted) {
          setState(() {
            companyName = companyProfile['company_name'];
            if (companyProfile['logo_url'] != null && companyProfile['logo_url'].isNotEmpty) {
              profileImageUrl = companyProfile['logo_url'];
            }
          });
        }
      }
    }
  }

  // Method to refresh profile data when returning from ProfilePage
  Future<void> _refreshProfileData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      // Force clear cache to get fresh data
      await LocalDB.clearUserCache(userId);

      // Force refresh from server
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.refreshUser();

      // Update local state
      final updatedUser = userProvider.currentUser;
      if (updatedUser != null && mounted) {
        setState(() {
          role = updatedUser.role.toLowerCase();
          userName = updatedUser.fullname;
          profileImageUrl = updatedUser.profileImageUrl;
        });
      }

      // Also refresh company profile if employer
      if (role?.toUpperCase() == 'POSTER') {
        // Fetch fresh company profile from Supabase
        final companyData = await supabase
            .from('company_profile')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (companyData != null && mounted) {
          setState(() {
            companyName = companyData['company_name'];
            if (companyData['logo_url'] != null && companyData['logo_url'].isNotEmpty) {
              profileImageUrl = companyData['logo_url'];
            }
          });
          // Update cache
          await LocalDB.cacheCompanyProfile(userId, companyData);
        }
      }
    }
  }

  void handleLogout() async {
    // Clear user cache on logout
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await LocalDB.clearUserCache(userId);
    }
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Widget buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget buildListItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.grey[400], size: 20),
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(fontSize: 15)),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget buildProfileSummary() {
    final bool isJobSeeker = role == 'job_seeker';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey[200],
            backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                ? NetworkImage(profileImageUrl!)
                : null,
            child: profileImageUrl == null || profileImageUrl!.isEmpty
                ? Icon(
              isJobSeeker ? Icons.person : Icons.business,
              size: 32,
              color: Colors.grey[400],
            )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isJobSeeker ? userName ?? '' : companyName ?? userName ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  isJobSeeker ? 'Job Seeker' : 'Employer Account',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                if (isJobSeeker)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Profile 60% complete',
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget buildJobSeekerStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Activity',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildStatItem('0', 'Applications'),
              buildStatItem('0', 'Saved Jobs'),
              buildStatItem('0', 'Following'),
              buildStatItem('0', 'Posts'),
            ],
          )
        ],
      ),
    );
  }

  Widget buildEmployerStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Company Activity',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildStatItem('0', 'Job Posts'),
              buildStatItem('0', 'Followers'),
              buildStatItem('0'.toString(), 'Applications'),
            ],
          )
        ],
      ),
    );
  }

  Widget buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isJobSeeker = role == 'job_seeker';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Main content
          RefreshIndicator(
            onRefresh: _refreshProfileData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildProfileSummary(),

                  // Profile Section
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6)
                        ]),
                    child: Column(
                      children: [
                        buildSectionHeader('Profile'),
                        buildListItem(Icons.person_outline, 'My Profile', () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfilePage()),
                          );
                          await _refreshProfileData();
                        }),
                        if (isJobSeeker)
                          buildListItem(Icons.work, 'My Resume', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ResumeManagementPage()),
                            ).then((_) => _refreshProfileData());
                          }),
                      ],
                    ),
                  ),

                  // Account Section
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6)
                        ]),
                    child: Column(
                      children: [
                        buildSectionHeader('Account'),
                        buildListItem(Icons.lock, 'Change Password', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                          );
                        }),
                      ],
                    ),
                  ),

                  if (isJobSeeker)
                    buildJobSeekerStats()
                  else if (role == 'poster')
                    buildEmployerStats(),

                  // Logout Button
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      setState(() {
                        showLogoutDialog = true;
                      });
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Logout',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // App Info
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Jobify v1.0.0\n© 2026 Jobify. All rights reserved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Full-screen overlay dialog
          if (showLogoutDialog)
            Container(
              color: Colors.black54, // This now covers the entire screen including AppBar
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => showLogoutDialog = false),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Logout',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Are you sure you want to logout? You'll need to login again to access your account.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: const Color(0xFF4E4C4C)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    showLogoutDialog = false;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: handleLogout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Logout'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}