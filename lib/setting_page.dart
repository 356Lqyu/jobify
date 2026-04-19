import 'package:flutter/material.dart';
import 'package:jobify/users/profile_page.dart';
import 'package:jobify/data/user_repository.dart';
import 'package:jobify/data/local_db.dart';
import 'package:jobify/users/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/change_password.dart';
import 'users/view_profile_page.dart';

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
  String? userId;
  String? companyId;

  bool showLogoutDialog = false;

  // Stats for Job Seeker
  int _applicationsCount = 0;
  int _savedJobsCount = 0;
  int _followingCount = 0;
  int _userPostsCount = 0;

  // Stats for Employer
  int _jobPostsCount = 0;
  int _companyFollowersCount = 0;
  int _applicationsReceivedCount = 0;

  bool _isLoadingStats = false;

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
        userId = user.userId;
      });

      // Load stats after getting user info
      await _loadStats();
    }

    // Fetch company name and ID if employer
    if (role?.toUpperCase() == 'POSTER') {
      final authUserId = supabase.auth.currentUser?.id;
      if (authUserId != null) {
        // Fetch fresh company profile from Supabase
        final companyProfile = await supabase
            .from('company_profile')
            .select()
            .eq('user_id', authUserId)
            .maybeSingle();

        if (companyProfile != null && mounted) {
          setState(() {
            companyName = companyProfile['company_name'];
            companyId = companyProfile['company_id'];
            if (companyProfile['logo_url'] != null && companyProfile['logo_url'].isNotEmpty) {
              profileImageUrl = companyProfile['logo_url'];
            }
          });
          // Update cache
          await LocalDB.cacheCompanyProfile(authUserId, companyProfile);
        } else {
          // Try from cache as fallback
          final cachedProfile = await LocalDB.getCachedCompanyProfile(authUserId);
          if (cachedProfile != null && mounted) {
            setState(() {
              companyName = cachedProfile['company_name'];
              companyId = cachedProfile['company_id'];
              if (cachedProfile['logo_url'] != null && cachedProfile['logo_url'].isNotEmpty) {
                profileImageUrl = cachedProfile['logo_url'];
              }
            });
          }
        }
      }
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final authUserId = supabase.auth.currentUser?.id;
      if (authUserId == null) return;

      final bool isJobSeeker = role?.toUpperCase() == 'JOB_SEEKER';

      if (isJobSeeker) {
        // Load job seeker stats
        await _loadJobSeekerStats(authUserId);
      } else if (role?.toUpperCase() == 'POSTER') {
        // Load employer stats
        await _loadEmployerStats(authUserId);
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadJobSeekerStats(String authUserId) async {
    try {
      // Count posts by user
      final postsResult = await supabase
          .from('post')
          .select('post_id')
          .eq('user_id', authUserId);
      _userPostsCount = (postsResult as List).length;

      // Count saved jobs
      final savedJobsResult = await supabase
          .from('saved_jobs')
          .select('job_id')
          .eq('user_id', authUserId);
      _savedJobsCount = (savedJobsResult as List).length;

      // Count following (users/companies the current user follows)
      final followingResult = await supabase
          .from('follows')
          .select('follow_id')
          .eq('follower_id', authUserId);
      _followingCount = (followingResult as List).length;

      // Count job applications
      final applicationsResult = await supabase
          .from('job_application')
          .select('application_id')
          .eq('user_id', authUserId);
      _applicationsCount = (applicationsResult as List).length;

      debugPrint('Job Seeker Stats - Posts: $_userPostsCount, Saved Jobs: $_savedJobsCount, Following: $_followingCount, Applications: $_applicationsCount');

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading job seeker stats: $e');
    }
  }

  Future<void> _loadEmployerStats(String authUserId) async {
    try {
      // First get company profile
      final companyProfile = await supabase
          .from('company_profile')
          .select('company_id')
          .eq('user_id', authUserId)
          .maybeSingle();

      if (companyProfile != null) {
        final compId = companyProfile['company_id'];

        // Update companyId if not set
        if (companyId == null && mounted) {
          setState(() {
            companyId = compId;
          });
        }

        // Count job posts
        final jobPostsResult = await supabase
            .from('job_post')
            .select('job_id')
            .eq('company_id', compId);
        _jobPostsCount = (jobPostsResult as List).length;

        // Count company followers
        final followersResult = await supabase
            .from('follows')
            .select('follow_id')
            .eq('following_id', compId);
        _companyFollowersCount = (followersResult as List).length;

        // Count applications received for company's jobs
        final jobsResult = await supabase
            .from('job_post')
            .select('job_id')
            .eq('company_id', compId);

        final jobIds = (jobsResult as List).map((j) => j['job_id'] as String).toList();

        if (jobIds.isNotEmpty) {
          final applicationsResult = await supabase
              .from('job_application')
              .select('application_id')
              .inFilter('job_id', jobIds);
          _applicationsReceivedCount = (applicationsResult as List).length;
        } else {
          _applicationsReceivedCount = 0;
        }

        debugPrint('Employer Stats - Job Posts: $_jobPostsCount, Followers: $_companyFollowersCount, Applications Received: $_applicationsReceivedCount');
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading employer stats: $e');
    }
  }

  // Method to refresh profile data when returning from ProfilePage
  Future<void> _refreshProfileData() async {
    final authUserId = supabase.auth.currentUser?.id;
    if (authUserId != null) {
      // Force clear cache to get fresh data
      await LocalDB.clearUserCache(authUserId);

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
          userId = updatedUser.userId;
        });
      }

      // Also refresh company profile if employer
      if (role?.toUpperCase() == 'POSTER') {
        // Fetch fresh company profile from Supabase
        final companyData = await supabase
            .from('company_profile')
            .select()
            .eq('user_id', authUserId)
            .maybeSingle();

        if (companyData != null && mounted) {
          setState(() {
            companyName = companyData['company_name'];
            companyId = companyData['company_id'];
            if (companyData['logo_url'] != null && companyData['logo_url'].isNotEmpty) {
              profileImageUrl = companyData['logo_url'];
            }
          });
          // Update cache
          await LocalDB.cacheCompanyProfile(authUserId, companyData);
        }
      }

      // Reload stats
      await _loadStats();
    }
  }

  void handleLogout() async {
    // Clear user cache on logout
    final authUserId = supabase.auth.currentUser?.id;
    if (authUserId != null) {
      await LocalDB.clearUserCache(authUserId);
    }

    // Clear UserProvider state
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.clearUser();

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
    if (_isLoadingStats) {
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }

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
              buildStatItem(_applicationsCount.toString(), 'Applications'),
              buildStatItem(_savedJobsCount.toString(), 'Saved Jobs'),
              buildStatItem(_followingCount.toString(), 'Following'),
              buildStatItem(_userPostsCount.toString(), 'Posts'),
            ],
          )
        ],
      ),
    );
  }

  Widget buildEmployerStats() {
    if (_isLoadingStats) {
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }

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
              buildStatItem(_jobPostsCount.toString(), 'Job Posts'),
              buildStatItem(_companyFollowersCount.toString(), 'Followers'),
              buildStatItem(_applicationsReceivedCount.toString(), 'Applications'),
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

  // Method to navigate to dashboard
  void _navigateToDashboard() async {
    final bool isJobSeeker = role == 'job_seeker';

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (isJobSeeker) {
        // For Job Seeker - use userId
        final targetUserId = userId ?? supabase.auth.currentUser?.id;

        if (targetUserId != null) {
          Navigator.pop(context); // Close loading dialog
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewProfilePage(
                userId: targetUserId,
                companyId: null,
                name: userName,
                avatarUrl: profileImageUrl,
                isCompany: false,
              ),
            ),
          );
          await _refreshProfileData();
        } else {
          Navigator.pop(context); // Close loading dialog
          _showErrorDialog('Unable to load dashboard. User ID not found.');
        }
      } else if (role == 'poster') {
        // For Employer - need companyId
        String? targetCompanyId = companyId;

        // If companyId is null, fetch it
        if (targetCompanyId == null) {
          final authUserId = supabase.auth.currentUser?.id;
          if (authUserId != null) {
            final companyProfile = await supabase
                .from('company_profile')
                .select('company_id')
                .eq('user_id', authUserId)
                .maybeSingle();

            if (companyProfile != null) {
              targetCompanyId = companyProfile['company_id'];
              setState(() {
                companyId = targetCompanyId;
              });
            }
          }
        }

        Navigator.pop(context); // Close loading dialog

        if (targetCompanyId != null && userId != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewProfilePage(
                userId: userId!,
                companyId: targetCompanyId,
                name: companyName,
                avatarUrl: profileImageUrl,
                isCompany: true,
              ),
            ),
          );
          await _refreshProfileData();
        } else {
          _showErrorDialog('Unable to load dashboard. Company information not found.');
        }
      } else {
        Navigator.pop(context); // Close loading dialog
        _showErrorDialog('Unable to load dashboard. Please try again.');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorDialog('Error loading dashboard: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfilePage()),
                          );
                          await _refreshProfileData();
                        }),
                        // New Dashboard item
                        buildListItem(Icons.dashboard_outlined, 'My Dashboard', () {
                          _navigateToDashboard();
                        }),
                        if (isJobSeeker)
                          buildListItem(Icons.work, 'My Resume', () {}),
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
              color: Colors.black54,
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
                          style: TextStyle(fontSize: 13, color: Color(0xFF4E4C4C)),
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