import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/users/users.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/data/user_repository.dart';
import '../discovery/job_details.dart';
import '../job_post/job_detail_employer.dart';
import '../social/post_feed_setting.dart';
import '../social/social_post_details.dart';

class ViewProfilePage extends StatefulWidget {
  final String userId;
  final String? companyId;
  final String? name;
  final String? avatarUrl;
  final bool isCompany;
  final VoidCallback? onFollowChanged;

  const ViewProfilePage({
    super.key,
    required this.userId,
    this.companyId,
    this.name,
    this.avatarUrl,
    required this.isCompany,
    this.onFollowChanged,
  });

  @override
  State<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final supabase = Supabase.instance.client;
  final UserRepository _userRepo = UserRepository();

  bool _isLoading = true;
  bool _isFollowing = false;

  String _profileVisibility = 'public';
  bool _isLoadingVisibility = false;

  // Track which section is selected
  // For company: 0: Posts, 1: Jobs, 2: Branches, 3: Followers, 4: Following
  // For job seeker: 0: Posts, 1: Following
  int _selectedSection = 0;

  // For job seeker - expanded sections
  bool _showExperience = true;
  bool _showEducation = true;
  bool _showSkills = true;

  // User data
  String? _fullname;
  String? _email;
  String? _bio;
  String? _profileImageUrl;
  String? _phone;
  String? _dateOfBirth;
  String? _gender;

  // Company data
  String? _companyName;
  String? _companyDescription;
  String? _industry;
  String? _companySize;
  String? _location;

  String? _headOfficeAddress;
  String? _headOfficeCity;
  String? _headOfficeState;
  String? _headOfficeCountry;

  // Stats
  int _postsCount = 0;
  int _jobPostsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  int _branchesCount = 0;

  // Lists
  List<Map<String, dynamic>> _recentPosts = [];
  List<Map<String, dynamic>> _jobPosts = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _education = [];
  List<Map<String, dynamic>> _experience = [];

  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadProfile();
    _loadStats();
    _loadRecentPosts();
    _loadJobPosts();
    _loadBranches();
    _loadFollowers();
    _loadFollowing();
    _loadHeadOffice();
    _checkFollowStatus();
    _loadVisibilitySetting();
    if (!widget.isCompany) {
      _loadJobSeekerDetails();
    }
  }

  Future<void> _getCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      _currentUserId = user.id;
    }
  }

  Future<void> _loadHeadOffice() async {
    if (!widget.isCompany || widget.companyId == null) return;

    try {
      final headOffice = await supabase
          .from('company_branch')
          .select()
          .eq('company_id', widget.companyId!)
          .eq('is_head_office', true)
          .maybeSingle();

      if (headOffice != null && mounted) {
        setState(() {
          _headOfficeAddress = headOffice['address'];
          _headOfficeCity = headOffice['city'];
          _headOfficeState = headOffice['state'];
          _headOfficeCountry = headOffice['country'];
        });
      }
    } catch (e) {
      debugPrint('Error loading head office: $e');
    }
  }

  Future<void> _loadJobSeekerDetails() async {
    try {
      final skillsData = await supabase
          .from('skills')
          .select()
          .eq('user_id', widget.userId)
          .order('skill_name');
      setState(() {
        _skills = List<Map<String, dynamic>>.from(skillsData);
      });

      final educationData = await supabase
          .from('education')
          .select()
          .eq('user_id', widget.userId)
          .order('start_date', ascending: false);
      setState(() {
        _education = List<Map<String, dynamic>>.from(educationData);
      });

      final experienceData = await supabase
          .from('experience')
          .select()
          .eq('user_id', widget.userId)
          .order('start_date', ascending: false);
      setState(() {
        _experience = List<Map<String, dynamic>>.from(experienceData);
      });
    } catch (e) {
      debugPrint('Error loading job seeker details: $e');
    }
  }

  Future<void> _loadVisibilitySetting() async {
    if (_currentUserId == null) return;

    try {
      final data = await supabase
          .from('users')
          .select('profile_visibility')
          .eq('user_id', _currentUserId!)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _profileVisibility = data['profile_visibility'] ?? 'public';
        });
      }
    } catch (e) {
      debugPrint('Error loading visibility: $e');
    }
  }

  Future<void> _updateVisibility(String newVisibility) async {
    if (_currentUserId == null) return;

    setState(() => _isLoadingVisibility = true);

    try {
      await supabase
          .from('users')
          .update({'profile_visibility': newVisibility})
          .eq('user_id', _currentUserId!);

      setState(() {
        _profileVisibility = newVisibility;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile visibility updated to ${_getVisibilityLabel(newVisibility)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingVisibility = false);
    }
  }

  void _showVisibilityDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Profile Visibility',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Choose who can view your profile',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  // Public Option
                  _buildVisibilityCard(
                    context: context,
                    icon: Icons.public,
                    title: 'Public',
                    description: 'Everyone can view your profile',
                    value: 'public',
                    currentValue: _profileVisibility,
                    color: Colors.green,
                    onTap: () async {
                      await _updateVisibility('public');
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Employers Only Option
                  _buildVisibilityCard(
                    context: context,
                    icon: Icons.business,
                    title: 'Employers Only',
                    description: 'All employers can view your profile',
                    value: 'employers_only',
                    currentValue: _profileVisibility,
                    color: Colors.orange,
                    onTap: () async {
                      await _updateVisibility('employers_only');
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Hidden Option
                  _buildVisibilityCard(
                    context: context,
                    icon: Icons.visibility_off,
                    title: 'Hidden',
                    description: 'Only employers this user has applied to can view the profile',
                    value: 'hidden',
                    currentValue: _profileVisibility,
                    color: Colors.red,
                    onTap: () async {
                      await _updateVisibility('hidden');
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required String value,
    required String currentValue,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = currentValue == value;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 25,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? color : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                    maxLines: 2, // Limit to 2 lines
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getVisibilityLabel(String visibility) {
    switch (visibility) {
      case 'public': return 'Public';
      case 'employers_only': return 'Employers Only';
      case 'hidden': return 'Hidden';
      default: return 'Public';
    }
  }

  IconData _getVisibilityIcon(String visibility) {
    switch (visibility) {
      case 'public': return Icons.public;
      case 'employers_only': return Icons.business;
      case 'hidden': return Icons.visibility_off;
      default: return Icons.public;
    }
  }

  Future<Map<String, dynamic>> _checkProfileAccess() async {
    // If viewing own profile, always allow
    if (_currentUserId == widget.userId) {
      return {'canView': true, 'visibility': 'public'};
    }

    try {
      // Get profile visibility setting and role for the target user
      final userData = await supabase
          .from('users')
          .select('profile_visibility, role')
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (userData == null) return {'canView': true, 'visibility': 'public'};

      final visibility = userData['profile_visibility'] ?? 'public';
      final userRole = userData['role'];

      // If profile is public, always show
      if (visibility == 'public') {
        return {'canView': true, 'visibility': visibility};
      }

      // If profile is hidden, check if current user is employer who received application
      if (visibility == 'hidden') {
        // If current user is not logged in, cannot view
        if (_currentUserId == null)
          return {'canView': false, 'visibility': visibility};

        // Get current user's role
        final currentUserData = await supabase
            .from('users')
            .select('role')
            .eq('user_id', _currentUserId!)
            .maybeSingle();

        if (currentUserData == null)
          return {'canView': false, 'visibility': visibility};

        // If current user is not an employer, cannot view
        if (currentUserData['role'] != 'POSTER') {
          return {'canView': false, 'visibility': visibility};
        }

        // Get the employer's job posts (posted by current user)
        final employerJobs = await supabase
            .from('job_post')
            .select('job_id')
            .eq('created_by', _currentUserId!);

        final employerJobIds = (employerJobs as List)
            .map((job) => job['job_id'] as String)
            .toList();

        if (employerJobIds.isEmpty) {
          return {'canView': false, 'visibility': visibility};
        }

        // Check if the profile owner (job seeker) has applied to any of this employer's jobs
        final applications = await supabase
            .from('job_application')
            .select('application_id')
            .eq('user_id', widget.userId)  // The profile owner (job seeker)
            .inFilter('job_id', employerJobIds);

        final canView = (applications as List).isNotEmpty;

        debugPrint('Hidden profile check: Profile owner ${widget.userId} has applied to employer jobs: $canView');

        return {'canView': canView, 'visibility': visibility};
      }

      // If employers_only, check if current user is employer (any employer)
      if (visibility == 'employers_only') {
        if (_currentUserId == null)
          return {'canView': false, 'visibility': visibility};

        // Get current user's role
        final currentUserData = await supabase
            .from('users')
            .select('role')
            .eq('user_id', _currentUserId!)
            .maybeSingle();

        if (currentUserData == null)
          return {'canView': false, 'visibility': visibility};

        // Only employers can view
        final canView = currentUserData['role'] == 'POSTER';
        return {'canView': canView, 'visibility': visibility};
      }

      return {'canView': true, 'visibility': visibility};
    } catch (e) {
      debugPrint('Error checking visibility: $e');
      return {'canView': true, 'visibility': 'public'};
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      if (widget.isCompany && widget.companyId != null) {
        final companyData = await supabase
            .from('company_profile')
            .select('''
            *,
            users!company_profile_user_id_fkey (
              email,
              phone
            )
          ''')
            .eq('company_id', widget.companyId!)
            .maybeSingle();

        if (companyData != null && mounted) {
          setState(() {
            _companyName = companyData['company_name'];
            _companyDescription = companyData['company_description'];
            _industry = companyData['industry'];
            _companySize = companyData['company_size'];
            _location = companyData['location'];
            _profileImageUrl = companyData['logo_url'];
            _email = companyData['users']?['email'];
            _phone = companyData['users']?['phone'];
          });
        }
      } else {
        final userData = await supabase
            .from('users')
            .select('''
            user_id,
            fullname,
            email,
            phone,
            profile_image_url,
            role
          ''')
            .eq('user_id', widget.userId)
            .maybeSingle();

        if (userData != null && mounted) {
          // Try to get existing profile
          var profileData = await supabase
              .from('job_seeker_profile')
              .select('bio, address, gender, date_of_birth')
              .eq('user_id', widget.userId)
              .maybeSingle();

          // If profile doesn't exist, create it
          if (profileData == null) {
            await supabase.from('job_seeker_profile').insert({
              'user_id': widget.userId,
              'bio': null,
              'address': null,
              'gender': _gender,
              'date_of_birth': _dateOfBirth,
            });

            // Fetch the newly created profile
            profileData = await supabase
                .from('job_seeker_profile')
                .select('bio, address, gender, date_of_birth')
                .eq('user_id', widget.userId)
                .maybeSingle();
          }

          setState(() {
            _fullname = userData['fullname'];
            _email = userData['email'];
            _profileImageUrl = userData['profile_image_url'];
            _phone = userData['phone'];
            _bio = profileData?['bio'];
            _dateOfBirth = profileData?['date_of_birth'];
            _gender = profileData?['gender'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      if (widget.isCompany && widget.companyId != null) {
        final postsResult = await supabase
            .from('post')
            .select('post_id')
            .eq('company_id', widget.companyId!)
            .isFilter('job_id', null);
        _postsCount = (postsResult as List).length;

        final jobPostsResult = await supabase
            .from('job_post')
            .select('job_id')
            .eq('company_id', widget.companyId!);
        _jobPostsCount = (jobPostsResult as List).length;

        final followersResult = await supabase
            .from('follows')
            .select('follow_id')
            .eq('following_id', widget.userId);
        _followersCount = (followersResult as List).length;

        final followingResult = await supabase
            .from('follows')
            .select('follow_id')
            .eq('follower_id', widget.userId);
        _followingCount = (followingResult as List).length;

        final branchesResult = await supabase
            .from('company_branch')
            .select('branch_id')
            .eq('company_id', widget.companyId!);
        _branchesCount = (branchesResult as List).length;
      } else {
        final postsResult = await supabase
            .from('post')
            .select('post_id')
            .eq('user_id', widget.userId)
            .isFilter('job_id', null);
        _postsCount = (postsResult as List).length;

        final followingResult = await supabase
            .from('follows')
            .select('follow_id')
            .eq('follower_id', widget.userId);
        _followingCount = (followingResult as List).length;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadRecentPosts() async {
    try {
      final posts = await supabase
          .from('post')
          .select('''
            post_id,
            content,
            post_type,
            media_urls,
            created_at,
            users!post_user_id_fkey (fullname, profile_image_url)
          ''')
          .eq(
        widget.isCompany ? 'company_id' : 'user_id',
        widget.isCompany ? widget.companyId! : widget.userId,
      )
          .isFilter('job_id', null)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        final postsList = List<Map<String, dynamic>>.from(posts);
        final postIds = postsList.map((p) => p['post_id'] as String).toList();
        if (postIds.isNotEmpty) {
          final likeCounts = await supabase
              .from('post_like')
              .select('post_id')
              .inFilter('post_id', postIds);

          final likeCountMap = <String, int>{};
          for (final like in likeCounts) {
            final postId = like['post_id'] as String;
            likeCountMap[postId] = (likeCountMap[postId] ?? 0) + 1;
          }

          final commentCounts = await supabase
              .from('post_comment')
              .select('post_id')
              .inFilter('post_id', postIds);

          final commentCountMap = <String, int>{};
          for (final comment in commentCounts) {
            final postId = comment['post_id'] as String;
            commentCountMap[postId] = (commentCountMap[postId] ?? 0) + 1;
          }

          // === NEW: Fetch user's liked and saved states ===
          Set<String> likedIds = {};
          Set<String> savedIds = {};

          if (_currentUserId != null) {
            final likes = await supabase
                .from('post_like')
                .select('post_id')
                .eq('user_id', _currentUserId!)
                .inFilter('post_id', postIds);
            for (var like in likes) {
              likedIds.add(like['post_id'] as String);
            }

            final saves = await supabase
                .from('post_saved')
                .select('post_id')
                .eq('user_id', _currentUserId!)
                .inFilter('post_id', postIds);
            for (var save in saves) {
              savedIds.add(save['post_id'] as String);
            }
          }

          for (final post in postsList) {
            final pid = post['post_id'] as String;
            post['like_count'] = likeCountMap[pid] ?? 0;
            post['comment_count'] = commentCountMap[pid] ?? 0;
            post['is_liked'] = likedIds.contains(pid); // Map state
            post['is_saved'] = savedIds.contains(pid); // Map state
          }
        }

        setState(() {
          _recentPosts = postsList;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent posts: $e');
    }
  }

  Future<void> _loadJobPosts() async {
    if (!widget.isCompany || widget.companyId == null) return;

    try {
      final jobPosts = await supabase
          .from('job_post')
          .select('''
            job_id,
            job_title,
            description,
            location,
            remote_option,
            salary_min,
            salary_max,
            job_type_id!inner (name),
            experience_level_id!inner (name),
            status,
            created_at
          ''')
          .eq('company_id', widget.companyId!)
          .order('created_at', ascending: false);

      if (mounted) {
        final jobList = List<Map<String, dynamic>>.from(jobPosts);

        for (final job in jobList) {
          final jobTypeData = job['job_type_id'];
          if (jobTypeData is List && jobTypeData.isNotEmpty) {
            job['job_type'] = jobTypeData[0]['name'];
          } else if (jobTypeData is Map) {
            job['job_type'] = jobTypeData['name'];
          } else {
            job['job_type'] = 'Not specified';
          }

          final expLevelData = job['experience_level_id'];
          if (expLevelData is List && expLevelData.isNotEmpty) {
            job['experience_level'] = expLevelData[0]['name'];
          } else if (expLevelData is Map) {
            job['experience_level'] = expLevelData['name'];
          } else {
            job['experience_level'] = 'Not specified';
          }

          job.remove('job_type_id');
          job.remove('experience_level_id');
        }

        setState(() {
          _jobPosts = jobList;
        });
      }
    } catch (e) {
      debugPrint('Error loading job posts: $e');
    }
  }

  Future<void> _loadBranches() async {
    if (!widget.isCompany || widget.companyId == null) return;

    try {
      final branches = await supabase
          .from('company_branch')
          .select()
          .eq('company_id', widget.companyId!)
          .order('is_head_office', ascending: false)
          .order('branch_name');

      if (mounted) {
        setState(() {
          _branches = List<Map<String, dynamic>>.from(branches);
        });
      }
    } catch (e) {
      debugPrint('Error loading branches: $e');
    }
  }

  Future<void> _loadFollowers() async {
    try {
      final followersData = await supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', widget.userId);

      if (mounted && (followersData as List).isNotEmpty) {
        final followerIds = followersData
            .map((f) => f['follower_id'] as String)
            .toList();

        if (followerIds.isNotEmpty) {
          final usersData = await supabase
              .from('users')
              .select('user_id, fullname, profile_image_url, role, company_profile(company_name, logo_url)')
              .inFilter('user_id', followerIds);

          final followersList = usersData.map((userData) {
            final user = Map<String, dynamic>.from(userData);
            if (user['role'] == 'POSTER' && user['company_profile'] != null) {
              final cp = user['company_profile'];
              final companyMap = (cp is List && cp.isNotEmpty) ? cp[0] : (cp is Map ? cp : null);
              if (companyMap != null) {
                user['fullname'] = companyMap['company_name'] ?? user['fullname'];
                user['profile_image_url'] = companyMap['logo_url'] ?? user['profile_image_url'];
              }
            }
            return {'users': user};
          }).toList();

          setState(() {
            _followers = List<Map<String, dynamic>>.from(followersList);
          });
        } else {
          setState(() {
            _followers = [];
          });
        }
      } else {
        setState(() {
          _followers = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading followers: $e');
      setState(() {
        _followers = [];
      });
    }
  }

  Future<void> _loadFollowing() async {
    try {
      final followingData = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', widget.userId);

      if (mounted && (followingData as List).isNotEmpty) {
        final followingIds = followingData
            .map((f) => f['following_id'] as String)
            .toList();

        if (followingIds.isNotEmpty) {
          final usersData = await supabase
              .from('users')
              .select('user_id, fullname, profile_image_url, role, company_profile(company_name, logo_url)')
              .inFilter('user_id', followingIds);

          final followingList = usersData.map((userData) {
            final user = Map<String, dynamic>.from(userData);
            if (user['role'] == 'POSTER' && user['company_profile'] != null) {
              final cp = user['company_profile'];
              final companyMap = (cp is List && cp.isNotEmpty) ? cp[0] : (cp is Map ? cp : null);
              if (companyMap != null) {
                user['fullname'] = companyMap['company_name'] ?? user['fullname'];
                user['profile_image_url'] = companyMap['logo_url'] ?? user['profile_image_url'];
              }
            }
            return {'users': user};
          }).toList();

          setState(() {
            _following = List<Map<String, dynamic>>.from(followingList);
          });
        } else {
          setState(() {
            _following = [];
          });
        }
      } else {
        setState(() {
          _following = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading following: $e');
      setState(() {
        _following = [];
      });
    }
  }

  Future<void> _checkFollowStatus() async {
    if (_currentUserId == null) return;

    try {
      final followingId = widget.userId;
      final result = await supabase
          .from('follows')
          .select()
          .eq('follower_id', _currentUserId!)
          .eq('following_id', followingId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFollowing = result != null;
        });
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to follow users')),
        );
      }
      return;
    }

    final followingId = widget.userId;
    setState(() => _isFollowing = !_isFollowing);

    try {
      if (_isFollowing) {
        await supabase.from('follows').insert({
          'follower_id': _currentUserId,
          'following_id': followingId,
        });
        setState(() {
          _followersCount++;
        });
        await _loadFollowers();
        widget.onFollowChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Following successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', followingId);
        setState(() {
          _followersCount--;
        });
        await _loadFollowers();
        widget.onFollowChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unfollowed successfully'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      await _loadStats();
    } catch (e) {
      setState(() => _isFollowing = !_isFollowing);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  // Hidden page
  Widget _buildHiddenRestrictedPage() {
    final String displayName = widget.isCompany
        ? (_companyName ?? widget.name ?? 'Company')
        : (_fullname ?? widget.name ?? 'User');

    final String profileImage = widget.isCompany
        ? (_profileImageUrl ?? '')
        : (_profileImageUrl ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: true,
        actions: [
          // Follow button for non-own profile
          if (_currentUserId != widget.userId)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(
                  _isFollowing ? Icons.check : Icons.person_add,
                  size: 18,
                ),
                label: Text(_isFollowing ? 'Following' : 'Follow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.white : Colors.blue,
                  foregroundColor: _isFollowing ? Colors.blue : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: profileImage.isNotEmpty
                        ? CachedNetworkImageProvider(profileImage)
                        : null,
                    child: profileImage.isEmpty
                        ? Icon(
                      widget.isCompany ? Icons.business : Icons.person,
                      size: 60,
                      color: Colors.blue,
                    )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.isCompany
                          ? Colors.purple.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.isCompany
                            ? Colors.purple.shade200
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Text(
                      widget.isCompany ? 'Employer' : 'Job Seeker',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.isCompany
                            ? Colors.purple.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Hidden Message Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(42),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.visibility_off,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hidden Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Only employers this user has applied to can view the profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployersOnlyRestrictedPage() {
    final String displayName = widget.isCompany
        ? (_companyName ?? widget.name ?? 'Company')
        : (_fullname ?? widget.name ?? 'User');

    final String profileImage = widget.isCompany
        ? (_profileImageUrl ?? '')
        : (_profileImageUrl ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: true,
        actions: [
          // Follow button for non-own profile
          if (_currentUserId != widget.userId)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(
                  _isFollowing ? Icons.check : Icons.person_add,
                  size: 18,
                ),
                label: Text(_isFollowing ? 'Following' : 'Follow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.white : Colors.blue,
                  foregroundColor: _isFollowing ? Colors.blue : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: profileImage.isNotEmpty
                        ? CachedNetworkImageProvider(profileImage)
                        : null,
                    child: profileImage.isEmpty
                        ? Icon(
                      widget.isCompany ? Icons.business : Icons.person,
                      size: 60,
                      color: Colors.blue,
                    )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.isCompany
                          ? Colors.purple.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.isCompany
                            ? Colors.purple.shade200
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Text(
                      widget.isCompany ? 'Employer' : 'Job Seeker',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.isCompany
                            ? Colors.purple.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Employers Only Message Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(42),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.business,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Employers Only',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This profile is only visible to employers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwnProfile = _currentUserId == widget.userId;

    return FutureBuilder<Map<String, dynamic>>(
      future: _checkProfileAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final result = snapshot.data ?? {'canView': true, 'visibility': 'public'};
        final canView = result['canView'] as bool;
        final visibility = result['visibility'] as String;

        if (!canView && !isOwnProfile) {
          if (visibility == 'employers_only') {
            return _buildEmployersOnlyRestrictedPage();
          }
          return _buildHiddenRestrictedPage();
        }
        return _buildProfileContent(isOwnProfile);
      },
    );
  }

  Widget _buildProfileContent(bool isOwnProfile) {
    final String displayName = widget.isCompany
        ? (_companyName ?? widget.name ?? 'Company')
        : (_fullname ?? widget.name ?? 'User');

    // Only show visibility button for job seekers (not companies)
    final bool showVisibilityButton = isOwnProfile && !widget.isCompany;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        actions: [
          // Visibility button for own profile (job seeker only)
          if (showVisibilityButton)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _showVisibilityDialog,
                icon: Icon(
                  _getVisibilityIcon(_profileVisibility),
                  size: 18,
                ),
                label: Text(_getVisibilityLabel(_profileVisibility)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          // Follow button for non-own profile
          if (!isOwnProfile)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(
                  _isFollowing ? Icons.check : Icons.person_add,
                  size: 18,
                ),
                label: Text(_isFollowing ? 'Following' : 'Follow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.white : Colors.blue,
                  foregroundColor: _isFollowing ? Colors.blue : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await _loadProfile();
          await _loadStats();
          await _loadRecentPosts();
          await _loadJobPosts();
          await _loadBranches();
          await _loadFollowers();
          await _loadFollowing();
          await _loadVisibilitySetting();
          if (!widget.isCompany) {
            await _loadJobSeekerDetails();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeaderSection(displayName),
              if (widget.isCompany) _buildCompanyInfoSection()
              else _buildContactInfoSection(isOwnProfile: isOwnProfile),
              _buildAboutSection(),
              _buildStatsRow(),
              if (widget.isCompany)
                _buildCompanyContentSection()
              else
                _buildJobSeekerContentSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(String displayName) {
    final bool isOwnProfile = _currentUserId == widget.userId;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[200],
            backgroundImage:
            _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                ? CachedNetworkImageProvider(_profileImageUrl!)
                : null,
            child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                ? Icon(
              widget.isCompany ? Icons.business : Icons.person,
              size: 60,
              color: Colors.blue,
            )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoSection() {
    String headOfficeLocation = '';
    if (_headOfficeAddress != null && _headOfficeAddress!.isNotEmpty) {
      headOfficeLocation = _headOfficeAddress!;
      if (_headOfficeCity != null && _headOfficeCity!.isNotEmpty) {
        headOfficeLocation += ', ${_headOfficeCity!}';
      }
      if (_headOfficeState != null && _headOfficeState!.isNotEmpty) {
        headOfficeLocation += ', ${_headOfficeState!}';
      }
      if (_headOfficeCountry != null && _headOfficeCountry!.isNotEmpty) {
        headOfficeLocation += ', ${_headOfficeCountry!}';
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headOfficeLocation.isNotEmpty)
            _buildInfoRow(
              Icons.location_on_outlined,
              'Head Office',
              headOfficeLocation,
            ),
          if (_industry != null && _industry!.isNotEmpty)
            _buildInfoRow(Icons.category_outlined, 'Industry', _industry!),
          if (_companySize != null && _companySize!.isNotEmpty)
            _buildInfoRow(Icons.people_outline, 'Company Size', _companySize!),
          if (_email != null && _email!.isNotEmpty)
            _buildInfoRow(Icons.email_outlined, 'Email', _email!),
          if (_phone != null && _phone!.isNotEmpty)
            _buildInfoRow(Icons.phone_outlined, 'Phone', _phone!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoSection({required bool isOwnProfile})  {
    final bool hasEmail = _email != null && _email!.isNotEmpty;
    final bool hasPhone = _phone != null && _phone!.isNotEmpty;
    final bool hasDateOfBirth = _dateOfBirth != null && _dateOfBirth!.isNotEmpty;
    final bool hasGender = _gender != null && _gender!.isNotEmpty;

    if (!hasEmail && !hasPhone && !hasDateOfBirth && !hasGender) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasEmail)
            _buildInfoRow(Icons.email_outlined, 'Email', _email!),
          if (hasPhone && isOwnProfile)
            _buildInfoRow(Icons.phone_outlined, 'Phone', _phone!),
          if (hasDateOfBirth)
            _buildInfoRow(Icons.cake_outlined, 'Date of Birth', _dateOfBirth!),
          if (hasGender)
            _buildInfoRow(Icons.person_outline, 'Gender', _gender!),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    final String displayBio = widget.isCompany
        ? (_companyDescription ?? 'No description provided')
        : (_bio ?? 'No bio provided');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(displayBio, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    if (widget.isCompany) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(_postsCount, 'Posts', 0),
            _buildStatItem(_jobPostsCount, 'Jobs', 1),
            _buildStatItem(_branchesCount, 'Branches', 2),
            _buildStatItem(_followersCount, 'Followers', 3),
            _buildStatItem(_followingCount, 'Following', 4),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(_postsCount, 'Posts', 0),
            _buildStatItem(_followingCount, 'Following', 1),
          ],
        ),
      );
    }
  }

  Widget _buildStatItem(int count, String label, int sectionIndex) {
    final bool isSelected = _selectedSection == sectionIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSection = sectionIndex;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: isSelected
                ? Border(
              bottom: BorderSide(
                color: Colors.blue,
                width: 2,
              ),
            )
                : null,
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue : Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.blue : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyContentSection() {
    // If nothing is selected, don't show any content
    if (_selectedSection == -1) {
      return const SizedBox.shrink();
    }

    // Show the content based on selection
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          if (_selectedSection == 0)
            _buildPostsContent()
          else if (_selectedSection == 1)
            _buildJobPostsContent()
          else if (_selectedSection == 2)
              _buildBranchesContent()
            else if (_selectedSection == 3)
                _buildFollowersContent()
              else if (_selectedSection == 4)
                  _buildFollowingContent(),
        ],
      ),
    );
  }

  Widget _buildJobSeekerContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Posts Section
        if (_selectedSection == 0) ...[
          _buildSectionHeader('Posts', Icons.post_add_outlined),
          _buildPostsContent(),
          const SizedBox(height: 16),
        ],

        // Following Section - only shown when Following stat is clicked
        if (_selectedSection == 1) ...[
          _buildSectionHeader('Following', Icons.people_outline),
          _buildFollowingContent(),
          const SizedBox(height: 16),
        ],

        // Experience Section - always visible
        _buildExpandableSection(
          title: 'Work Experience',
          icon: Icons.work_outline,
          isExpanded: _showExperience,
          onToggle: () => setState(() => _showExperience = !_showExperience),
          content: _buildExperienceContent(),
        ),

        const SizedBox(height: 16),

        // Education Section - always visible
        _buildExpandableSection(
          title: 'Education',
          icon: Icons.school_outlined,
          isExpanded: _showEducation,
          onToggle: () => setState(() => _showEducation = !_showEducation),
          content: _buildEducationContent(),
        ),

        const SizedBox(height: 16),

        // Skills Section - always visible
        _buildExpandableSection(
          title: 'Skills',
          icon: Icons.code_outlined,
          isExpanded: _showSkills,
          onToggle: () => setState(() => _showSkills = !_showSkills),
          content: _buildSkillsContent(),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Colors.blue),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey,
            ),
            onTap: onToggle,
          ),
          if (isExpanded) content,
        ],
      ),
    );
  }

  Widget _buildExperienceContent() {
    if (_experience.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No work experience added yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _experience.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final exp = _experience[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exp['job_title'] ?? 'Unknown Position',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                exp['company_name'] ?? 'Unknown Company',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateRange(exp['start_date'], exp['end_date']),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              if (exp['description'] != null &&
                  exp['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(exp['description'], style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEducationContent() {
    if (_education.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No education added yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _education.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final edu = _education[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                edu['institution_name'] ?? 'Unknown Institution',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                edu['qualification'] ?? 'Unknown Qualification',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              if (edu['field_of_study'] != null &&
                  edu['field_of_study'].toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  edu['field_of_study'],
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _formatDateRange(edu['start_date'], edu['end_date']),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              if (edu['description'] != null &&
                  edu['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(edu['description'], style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkillsContent() {
    if (_skills.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No skills added yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _skills.map((skill) {
          final skillLevel = skill['skill_level'];
          Color levelColor = Colors.blue;
          if (skillLevel == 'Beginner')
            levelColor = Colors.green;
          else if (skillLevel == 'Intermediate')
            levelColor = Colors.orange;
          else if (skillLevel == 'Advanced')
            levelColor = Colors.red;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: levelColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  skill['skill_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: levelColor,
                  ),
                ),
                if (skillLevel != null && skillLevel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: levelColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    skillLevel,
                    style: TextStyle(fontSize: 11, color: levelColor),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDateRange(String? startDate, String? endDate) {
    final start = startDate != null ? _formatShortDate(startDate) : '';
    final end = endDate != null && endDate.isNotEmpty
        ? _formatShortDate(endDate)
        : 'Present';
    if (start.isEmpty) return end;
    return '$start - $end';
  }

  String _formatShortDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildPostsContent() {
    if (_recentPosts.isEmpty) {
      final bool isOwnProfile = _currentUserId == widget.userId;

      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.post_add_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No posts yet',
                style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                isOwnProfile
                    ? 'When you share posts, they\'ll appear here'
                    : 'When this user shares posts, they\'ll appear here',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentPosts.length,
      itemBuilder: (context, index) {
        final post = _recentPosts[index];
        final String displayName = widget.isCompany
            ? (_companyName ?? widget.name ?? 'Company')
            : (_fullname ?? widget.name ?? 'User');

        final postType = post['post_type'] as String? ?? 'post';
        final postTypeColor = _getPostTypeColor(postType);

        return GestureDetector(
          onTap: () => _navigateToPostDetail(post),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: _profileImageUrl != null
                          ? CachedNetworkImageProvider(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? Icon(Icons.person, size: 16, color: Colors.blue)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _formatDate(post['created_at']),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: postTypeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: postTypeColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getPostTypeIcon(postType),
                            size: 10,
                            color: postTypeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getPostTypeLabel(postType),
                            style: TextStyle(
                              fontSize: 10,
                              color: postTypeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post['content'] ?? '',
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (post['media_urls'] != null &&
                    (post['media_urls'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: (post['media_urls'] as List).length,
                      itemBuilder: (context, mediaIndex) {
                        final mediaUrl = (post['media_urls'] as List)[mediaIndex];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: mediaUrl,
                              width: 150,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${post['like_count'] ?? 0}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.comment_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${post['comment_count'] ?? 0}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJobPostsContent() {
    if (_jobPosts.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No job posts')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _jobPosts.length,
      itemBuilder: (context, index) {
        final job = _jobPosts[index];
        final isActive = job['status'] == 'active';

        String salaryDisplay = 'Not specified';
        final salaryMin = job['salary_min'];
        final salaryMax = job['salary_max'];
        if (salaryMin != null && salaryMax != null) {
          salaryDisplay =
          'RM ${_formatSalary(salaryMin)} - RM ${_formatSalary(salaryMax)}';
        } else if (salaryMin != null) {
          salaryDisplay = 'From RM ${_formatSalary(salaryMin)}';
        } else if (salaryMax != null) {
          salaryDisplay = 'Up to RM ${_formatSalary(salaryMax)}';
        }

        final remoteOption = job['remote_option'] == true;
        final jobType = job['job_type'] ?? 'Not specified';
        final experienceLevel = job['experience_level'] ?? 'Not specified';
        final location = job['location'] ?? 'Location not specified';

        return GestureDetector(
          onTap: () => _navigateToJobDetail(job),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? null
                  : Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        job['job_title'] ?? 'Untitled Position',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.blue : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.shade50
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Closed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: isActive ? Colors.grey.shade600 : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive ? Colors.grey.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.work_outline,
                      size: 16,
                      color: isActive ? Colors.grey.shade600 : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      jobType,
                      style: TextStyle(
                        fontSize: 13,
                        color: isActive ? Colors.grey.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (remoteOption) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.wifi,
                        size: 16,
                        color: isActive ? Colors.grey.shade600 : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remote',
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive ? Colors.grey.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 16,
                      color: isActive ? Colors.grey.shade600 : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      experienceLevel,
                      style: TextStyle(
                        fontSize: 13,
                        color: isActive ? Colors.grey.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: isActive ? Colors.green.shade700 : Colors.green.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      salaryDisplay,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isActive ? Colors.green.shade700 : Colors.green.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isActive ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Posted ${_formatDate(job['created_at'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive ? Colors.grey.shade500 : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: isActive ? Colors.blue.shade400 : Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatSalary(dynamic salary) {
    if (salary == null) return '0';
    final num = salary is int ? salary : (salary as double).toInt();
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(0)}k';
    }
    return num.toString();
  }

  Color _getPostTypeColor(String postType) {
    switch (postType.toLowerCase()) {
      case 'post':
        return const Color(0xFF2563EB);
      case 'job':
        return const Color(0xFF8B5CF6);
      case 'tip':
        return const Color(0xFF10B981);
      case 'event':
        return const Color(0xFFF59E0B);
      case 'news':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF2563EB);
    }
  }

  IconData _getPostTypeIcon(String postType) {
    switch (postType.toLowerCase()) {
      case 'post':
        return Icons.chat_bubble_outline;
      case 'job':
        return Icons.work_outline;
      case 'tip':
        return Icons.lightbulb_outline;
      case 'event':
        return Icons.event_outlined;
      case 'news':
        return Icons.article_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  String _getPostTypeLabel(String postType) {
    switch (postType.toLowerCase()) {
      case 'post':
        return 'Post';
      case 'job':
        return 'Hiring';
      case 'tip':
        return 'Tip';
      case 'event':
        return 'Event';
      case 'news':
        return 'News';
      default:
        return postType.toUpperCase();
    }
  }

  Widget _buildBranchesContent() {
    if (_branches.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No branches found')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _branches.length,
      itemBuilder: (context, index) {
        final branch = _branches[index];
        final bool isHeadOffice = branch['is_head_office'] == true;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHeadOffice ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isHeadOffice
                ? Border.all(color: Colors.blue.shade200)
                : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_city, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      branch['branch_name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (isHeadOffice)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Head Office',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (branch['address'] != null)
                _branchRow(Icons.location_on_outlined, branch['address']),
              if (branch['city'] != null || branch['state'] != null)
                _branchRow(
                  Icons.location_city,
                  '${branch['city'] ?? ''}${branch['city'] != null && branch['state'] != null ? ', ' : ''}${branch['state'] ?? ''}',
                ),
              if (branch['country'] != null)
                _branchRow(Icons.public, branch['country']),
              if (branch['phone'] != null &&
                  branch['phone'].toString().isNotEmpty)
                _branchRow(Icons.phone, branch['phone']),
              if (branch['email'] != null &&
                  branch['email'].toString().isNotEmpty)
                _branchRow(Icons.email, branch['email']),
            ],
          ),
        );
      },
    );
  }

  Widget _branchRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildFollowersContent() {
    return _buildUserList(
      users: _followers,
      emptyMessage: 'No followers yet',
      emptySubMessage: "When someone follows this profile, they'll appear here",
      subtitleLabel: 'Follower',
    );
  }

  Widget _buildFollowingContent() {
    return _buildUserList(
      users: _following,
      emptyMessage: 'Not following anyone yet',
      emptySubMessage: 'Companies and people followed will appear here',
      subtitleLabel: 'Following',
    );
  }

  Widget _buildUserList({
    required List<Map<String, dynamic>> users,
    required String emptyMessage,
    required String emptySubMessage,
    required String subtitleLabel,
  }) {
    if (users.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                emptySubMessage,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final userData = users[index];
        final user = userData['users'] as Map<String, dynamic>?;
        if (user == null) return const SizedBox.shrink();

        final isOwnProfile = _currentUserId == user['user_id'];
        final isCompanyUser = user['role'] == 'POSTER';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: isOwnProfile
                    ? null
                    : () => _navigateToUserProfile(user, isCompanyUser),
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: user['profile_image_url'] != null
                      ? CachedNetworkImageProvider(user['profile_image_url'])
                      : null,
                  child: user['profile_image_url'] == null
                      ? Icon(Icons.person, size: 24, color: Colors.blue)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['fullname'] ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          user['role'] == 'POSTER' ? Icons.business : Icons.person_outline,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user['role'] == 'POSTER' ? 'Employer' : 'Job Seeker',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isOwnProfile)
                IconButton(
                  onPressed: () => _navigateToUserProfile(user, isCompanyUser),
                  icon: Icon(
                    Icons.visibility,
                    color: Colors.blue.shade400,
                    size: 20,
                  ),
                  tooltip: 'View Profile',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToPostDetail(Map<String, dynamic> post) async {
    final feedPost = FeedPost(
      postId: post['post_id'] as String,
      userId: widget.userId,
      companyId: widget.isCompany ? widget.companyId : null,
      jobId: null,
      content: post['content'] ?? '',
      postType: postTypeFromString(post['post_type'] as String?),
      hashtags: [],
      mediaUrls: post['media_urls'] != null
          ? List<String>.from(post['media_urls'] as List)
          : [],
      createdAt: DateTime.parse(post['created_at'] as String),
      updatedAt: DateTime.parse(post['created_at'] as String),
      authorName: widget.isCompany
          ? (_companyName ?? widget.name ?? 'Company')
          : (_fullname ?? widget.name ?? 'User'),
      authorAvatar: _profileImageUrl ?? '',
      authorSubtitle: widget.isCompany ? (_industry ?? '') : '',
      isVerified: widget.isCompany,
      likeCount: post['like_count'] ?? 0,
      commentCount: post['comment_count'] ?? 0,
      isLiked: post['is_liked'] == true,
      isSaved: post['is_saved'] == true,
      isFollowing: _isFollowing,
      linkedJob: null,
    );

    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to view post details')),
        );
      }
      return;
    }

    final currentUserData = await supabase
        .from('users')
        .select()
        .eq('user_id', currentUserId)
        .maybeSingle();

    if (currentUserData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data not found')),
        );
      }
      return;
    }

    final currentUser = Users.fromJson(currentUserData);

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SocialPostDetails(
            post: feedPost,
            currentUser: currentUser,
          ),
        ),
      );
      _loadRecentPosts();
    }
  }

  void _navigateToJobDetail(Map<String, dynamic> job) async {
    final jobId = job['job_id'];

    try {
      final fullJob = await supabase
          .from('job_post')
          .select('''
          *,
          job_category_id (name),
          job_type_id (name),
          experience_level_id (name),
          company_profile (company_name, logo_url, industry)
        ''')
          .eq('job_id', jobId)
          .maybeSingle();

      if (fullJob != null && mounted) {
        final isOwnProfile = _currentUserId == widget.userId;

        if (isOwnProfile) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobDetailEmployer(job: fullJob),
            ),
          );
        } else {
          final jobPost = JobPost.fromSupabase(
            fullJob,
            companyName: fullJob['company_profile']?['company_name'] ?? '',
            companyLogoUrl: fullJob['company_profile']?['logo_url'],
            companyIndustry: fullJob['company_profile']?['industry'],
            jobType: fullJob['job_type_id']?['name'] ?? '',
            jobCategory: fullJob['job_category_id']?['name'] ?? '',
            experienceLevel: fullJob['experience_level_id']?['name'] ?? '',
          );

          final currentUserId = supabase.auth.currentUser?.id;
          if (currentUserId != null) {
            final currentUserData = await supabase
                .from('users')
                .select()
                .eq('user_id', currentUserId)
                .single();
            final currentUser = Users.fromJson(currentUserData);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JobDetailPage(job: jobPost, currentUser: currentUser),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading job details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading job details: $e')),
      );
    }
  }

  void _navigateToUserProfile(
      Map<String, dynamic> user,
      bool isCompanyUser,
      ) async {
    String? targetCompanyId;
    if (isCompanyUser) {
      try {
        final company = await supabase
            .from('company_profile')
            .select('company_id')
            .eq('user_id', user['user_id'])
            .maybeSingle();
        targetCompanyId = company?['company_id'];
      } catch (e) {
        debugPrint('Error fetching company for user: $e');
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewProfilePage(
          userId: user['user_id'],
          companyId: targetCompanyId,
          name: user['fullname'],
          avatarUrl: user['profile_image_url'],
          isCompany: isCompanyUser,
          onFollowChanged: () {
            _loadFollowers();
            _loadFollowing();
            _loadStats();
          },
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  String get displayName {
    if (widget.isCompany) {
      return _companyName ?? widget.name ?? 'Company';
    } else {
      return _fullname ?? widget.name ?? 'User';
    }
  }
}