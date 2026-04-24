import 'package:flutter/material.dart';
import 'package:jobify/users/profile_page.dart';
import 'package:jobify/data/user_repository.dart';
import 'package:jobify/data/local_db.dart';
import 'package:jobify/users/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/change_password.dart';
import 'users/view_profile_page.dart';
import 'package:jobify/job/resume_management_page.dart';
import 'package:jobify/social/social_post_management.dart';
import 'package:jobify/social/saved_post.dart';

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

  String? _phone;
  String? _email;
  String? _dateOfBirth;
  String? _gender;
  String? _address;
  String? _bio;
  String? _companyPhone;
  String? _companyEmail;
  String? _companyDescription;
  String? _industry;
  String? _companySize;
  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _education = [];
  List<Map<String, dynamic>> _experience = [];
  List<Map<String, dynamic>> _branches = [];

  bool showLogoutDialog = false;

  // Stats for Job Seeker
  int _applicationsCount = 0;
  int _savedPostsCount = 0;
  int _followingCount = 0;
  int _userPostsCount = 0;

  // Stats for Employer
  int _posterSocialPostCount = 0;
  int _posterJobPostCount = 0;
  int _posterSavedPostsCount = 0;
  int _companyFollowersCount = 0;
  int _posterFollowingCount = 0;

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

  Future<void> _loadProfileCompletionData() async {
    final authUserId = supabase.auth.currentUser?.id;
    if (authUserId == null) return;

    final isJobSeeker = role?.toUpperCase() == 'JOB_SEEKER';

    if (isJobSeeker) {
      // Fetch job seeker profile
      final profileData = await supabase
          .from('job_seeker_profile')
          .select('date_of_birth, gender, address, bio')
          .eq('user_id', authUserId)
          .maybeSingle();

      if (profileData != null && mounted) {
        setState(() {
          _dateOfBirth = profileData['date_of_birth'];
          _gender = profileData['gender'];
          _address = profileData['address'];
          _bio = profileData['bio'];
        });
      }

      // Fetch skills, education, experience
      final skillsData = await supabase
          .from('skills')
          .select()
          .eq('user_id', authUserId);
      _skills = List<Map<String, dynamic>>.from(skillsData);

      final educationData = await supabase
          .from('education')
          .select()
          .eq('user_id', authUserId);
      _education = List<Map<String, dynamic>>.from(educationData);

      final experienceData = await supabase
          .from('experience')
          .select()
          .eq('user_id', authUserId);
      _experience = List<Map<String, dynamic>>.from(experienceData);

    } else if (role?.toUpperCase() == 'POSTER') {
      // Fetch company profile
      final companyData = await supabase
          .from('company_profile')
          .select('company_name, company_description, industry, company_size')
          .eq('user_id', authUserId)
          .maybeSingle();

      if (companyData != null && mounted) {
        setState(() {
          _companyDescription = companyData['company_description'];
          _industry = companyData['industry'];
          _companySize = companyData['company_size'];
        });
      }

      // Fetch branches
      final companyProfile = await supabase
          .from('company_profile')
          .select('company_id')
          .eq('user_id', authUserId)
          .maybeSingle();

      if (companyProfile != null) {
        final branchesData = await supabase
            .from('company_branch')
            .select()
            .eq('company_id', companyProfile['company_id']);
        _branches = List<Map<String, dynamic>>.from(branchesData);
      }
    }

    // Get email and phone from user table
    final userData = await supabase
        .from('users')
        .select('email, phone')
        .eq('user_id', authUserId)
        .maybeSingle();

    if (userData != null && mounted) {
      setState(() {
        _email = userData['email'];
        _phone = userData['phone'];
      });
    }
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

      // Load profile completion data
      await _loadProfileCompletionData();

      // Load stats after getting user info
      await _loadStats();
    }

    // Fetch company name and ID if employer
    if (role?.toUpperCase() == 'POSTER') {
      final authUserId = supabase.auth.currentUser?.id;
      if (authUserId != null) {
        final companyProfile = await supabase
            .from('company_profile')
            .select()
            .eq('user_id', authUserId)
            .maybeSingle();

        if (companyProfile != null && mounted) {
          setState(() {
            companyName = companyProfile['company_name'];
            companyId = companyProfile['company_id'];
            if (companyProfile['logo_url'] != null &&
                companyProfile['logo_url'].isNotEmpty) {
              profileImageUrl = companyProfile['logo_url'];
            }
          });
          // Update cache
          await LocalDB.cacheCompanyProfile(authUserId, companyProfile);
        } else {
          // Try from cache as fallback
          final cachedProfile = await LocalDB.getCachedCompanyProfile(
            authUserId,
          );
          if (cachedProfile != null && mounted) {
            setState(() {
              companyName = cachedProfile['company_name'];
              companyId = cachedProfile['company_id'];
              if (cachedProfile['logo_url'] != null &&
                  cachedProfile['logo_url'].isNotEmpty) {
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
      // Count social posts only (job_id IS NULL)
      final postsResult = await supabase
          .from('post')
          .select('post_id')
          .eq('user_id', authUserId)
          .isFilter('job_id', null);
      _userPostsCount = (postsResult as List).length;

      // Count all saved posts
      final savedResult = await supabase
          .from('post_saved')
          .select('post_saved_id')
          .eq('user_id', authUserId);
      _savedPostsCount = (savedResult as List).length;

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
          .eq('user_id', authUserId)
          .neq('status', 'withdrawn');
      _applicationsCount = (applicationsResult as List).length;

      debugPrint(
        'Job Seeker Stats - Posts: $_userPostsCount, Saved: $_savedPostsCount, Following: $_followingCount, Applications: $_applicationsCount',
      );

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading job seeker stats: $e');
    }
  }

  Future<void> _loadEmployerStats(String authUserId) async {
    try {
      // Count social posts (post table job_id IS NULL)
      final socialResult = await supabase
          .from('post')
          .select('post_id')
          .eq('user_id', authUserId)
          .isFilter('job_id', null);
      _posterSocialPostCount = (socialResult as List).length;

      // Count job posts (post table job_id IS NOT NULL)
      final jobPostResult = await supabase
          .from('post')
          .select('post_id')
          .eq('user_id', authUserId)
          .not('job_id', 'is', null);
      _posterJobPostCount = (jobPostResult as List).length;

      // Count all saved posts
      final savedResult = await supabase
          .from('post_saved')
          .select('post_saved_id')
          .eq('user_id', authUserId);
      _posterSavedPostsCount = (savedResult as List).length;

      // Count company followers (users following this user account)
      final followersResult = await supabase
          .from('follows')
          .select('follow_id')
          .eq('following_id', authUserId);
      _companyFollowersCount = (followersResult as List).length;

      // Count following
      final followingResult = await supabase
          .from('follows')
          .select('follow_id')
          .eq('follower_id', authUserId);
      _posterFollowingCount = (followingResult as List).length;

      debugPrint(
        'Employer Stats - Social: $_posterSocialPostCount, JobPosts: $_posterJobPostCount, Followers: $_companyFollowersCount, Following: $_posterFollowingCount',
      );

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

      // Reload profile completion data
      await _loadProfileCompletionData();

      // Also refresh company profile if employer
      if (role?.toUpperCase() == 'POSTER') {
        final companyData = await supabase
            .from('company_profile')
            .select()
            .eq('user_id', authUserId)
            .maybeSingle();

        if (companyData != null && mounted) {
          setState(() {
            companyName = companyData['company_name'];
            companyId = companyData['company_id'];
            if (companyData['logo_url'] != null &&
                companyData['logo_url'].isNotEmpty) {
              profileImageUrl = companyData['logo_url'];
            }
          });
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
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
    );
  }

  Widget buildListItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
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

    // Calculate profile completion percentage
    double completionPercentage = _calculateProfileCompletion(isJobSeeker);

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
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                profileImageUrl != null && profileImageUrl!.isNotEmpty
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
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isJobSeeker ? 'Job Seeker' : 'Employer Account',
                      style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Profile Completeness',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${completionPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getProgressColor(completionPercentage),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: completionPercentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(completionPercentage),
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Method to calculate profile completion percentage
  double _calculateProfileCompletion(bool isJobSeeker) {
    int completedFields = 0;
    int totalFields = isJobSeeker ? 10 : 7;

    if (isJobSeeker) {
      // Job Seeker Fields
      if (profileImageUrl != null && profileImageUrl!.isNotEmpty) completedFields++;
      if (userName != null && userName!.isNotEmpty) completedFields++;
      if (_phone != null && _phone!.isNotEmpty) completedFields++;
      if (_dateOfBirth != null && _dateOfBirth!.isNotEmpty) completedFields++;
      if (_gender != null && _gender!.isNotEmpty) completedFields++;
      if (_address != null && _address!.isNotEmpty) completedFields++;
      if (_bio != null && _bio!.isNotEmpty) completedFields++;

      // Skills, Education, Experience
      if (_skills.isNotEmpty) completedFields++;
      if (_education.isNotEmpty) completedFields++;
      if (_experience.isNotEmpty) completedFields++;

      totalFields = 10; // Profile image, name, phone, email, DOB, gender, address, bio, skills, education, experience
    } else {
      // Employer Fields
      if (profileImageUrl != null && profileImageUrl!.isNotEmpty) completedFields++;
      if (companyName != null && companyName!.isNotEmpty) completedFields++;
      if (_phone != null && _phone!.isNotEmpty) completedFields++;
      if (_companyDescription != null && _companyDescription!.isNotEmpty) completedFields++;
      if (_industry != null && _industry!.isNotEmpty) completedFields++;
      if (_companySize != null && _companySize!.isNotEmpty) completedFields++;
      if (_branches.isNotEmpty) completedFields++;

      totalFields = 7; // Logo, company name, phone, email, description, industry, size, branches
    }

    // Calculate percentage
    double percentage = (completedFields / totalFields) * 100;
    return percentage.clamp(0.0, 100.0);
  }

  // Method to get progress color based on percentage
  Color _getProgressColor(double percentage) {
    if (percentage >= 80) {
      return Colors.green;
    } else if (percentage >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Job Seeker activity panel
  // Shows Applications , Social Posts , Saved Posts (clickable) , Following
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
          const Text(
            'Your Activity',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          const SizedBox(height: 16),
          //first fow - Applications , Social Posts , Saved Posts(clickable)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildStatItem(_applicationsCount.toString(), 'Applications'),
              buildStatItem(_userPostsCount.toString(), 'Social Posts'),
              // Saved Posts – tappable
              GestureDetector(
                onTap: _navigateToSavedPosts,
                child: Column(
                  children: [
                    Text(
                      _savedPostsCount.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Saved Posts',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // second row - Following
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [buildStatItem(_followingCount.toString(), 'Following')],
          ),
        ],
      ),
    );
  }

  // Employer activity panel
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
          const Text(
            'Company Activity',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          const SizedBox(height: 16),
          // first row - Social Posts , Job Posts , Saved Posts(clickable)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildStatItem(_posterSocialPostCount.toString(), 'Social Posts'),
              buildStatItem(_posterJobPostCount.toString(), 'Job Posts'),
              // Saved Posts – tappable
              GestureDetector(
                onTap: _navigateToSavedPosts,
                child: Column(
                  children: [
                    Text(
                      _posterSavedPostsCount.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Saved Posts',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildStatItem(_companyFollowersCount.toString(), 'Followers'),
              buildStatItem(_posterFollowingCount.toString(), 'Following'),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // Navigate to saved posts
  void _navigateToSavedPosts() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SavedPostsPage(currentUser: currentUser),
      ),
    ).then((_) => _refreshProfileData());
  }

  // Method to navigate to dashboard (ViewProfilePage)
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
                onFollowChanged: () => _refreshProfileData(),
              ),
            ),
          );
          await _refreshProfileData();
        } else {
          Navigator.pop(context);
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

        Navigator.pop(context);

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
          _showErrorDialog(
            'Unable to load dashboard. Company information not found.',
          );
        }
      } else {
        Navigator.pop(context);
        _showErrorDialog('Unable to load dashboard. Please try again.');
      }
    } catch (e) {
      Navigator.pop(context);
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
        title: const Text('My Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        buildSectionHeader('Profile'),
                        buildListItem(
                          Icons.person_outline,
                          'My Profile',
                          () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfilePage(),
                              ),
                            );
                            await _refreshProfileData();
                          },
                        ),
                        // Dashboard will navigates to ViewProfilePage
                        buildListItem(
                          Icons.dashboard_outlined,
                          'My Dashboard',
                          () {
                            _navigateToDashboard();
                          },
                        ),
                        buildListItem(
                          Icons.post_add_outlined,
                          'Manage My Posts',
                          () {
                            final userProvider = Provider.of<UserProvider>(
                              context,
                              listen: false,
                            );
                            final currentUser = userProvider.currentUser;
                            if (currentUser == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MyPostsPage(currentUser: currentUser),
                              ),
                            ).then((_) => _refreshProfileData());
                          },
                        ),
                        // My Resume for job seeker only
                        if (isJobSeeker)
                          buildListItem(
                            Icons.description_outlined,
                            'My Resume',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ResumeManagementPage(),
                                ),
                              ).then((_) => _refreshProfileData());
                            },
                          ),
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
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        buildSectionHeader('Account'),
                        buildListItem(Icons.lock, 'Change Password', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordPage(),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  // Activity Panel is role-specific stats
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
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                          "Are you sure you want to logout? ",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4E4C4C),
                          ),
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
