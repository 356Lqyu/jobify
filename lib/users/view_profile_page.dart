import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/data/user_repository.dart';

class ViewProfilePage extends StatefulWidget {
  final String userId;
  final String? companyId;
  final String? name;
  final String? avatarUrl;
  final bool isCompany;

  const ViewProfilePage({
    super.key,
    required this.userId,
    this.companyId,
    this.name,
    this.avatarUrl,
    required this.isCompany,
  });

  @override
  State<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final supabase = Supabase.instance.client;
  final UserRepository _userRepo = UserRepository();

  bool _isLoading = true;
  bool _isFollowing = false;

  // Selected tab for content section (for company view)
  int _selectedTabIndex = 0; // 0: Posts, 1: Jobs, 2: Branches, 3: Followers

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
    _loadHeadOffice();
    _checkFollowStatus();
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
      // Load skills
      final skillsData = await supabase
          .from('skills')
          .select()
          .eq('user_id', widget.userId)
          .order('skill_name');
      setState(() {
        _skills = List<Map<String, dynamic>>.from(skillsData);
      });

      // Load education
      final educationData = await supabase
          .from('education')
          .select()
          .eq('user_id', widget.userId)
          .order('start_date', ascending: false);
      setState(() {
        _education = List<Map<String, dynamic>>.from(educationData);
      });

      // Load experience
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

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      if (widget.isCompany && widget.companyId != null) {
        // Load company profile
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
        // Load user profile
        final userData = await supabase
            .from('users')
            .select('''
              *,
              job_seeker_profile!job_seeker_profile_user_id_fkey (
                bio,
                address,
                gender,
                date_of_birth
              )
            ''')
            .eq('user_id', widget.userId)
            .maybeSingle();

        if (userData != null && mounted) {
          setState(() {
            _fullname = userData['fullname'];
            _email = userData['email'];
            _profileImageUrl = userData['profile_image_url'];
            _bio = userData['job_seeker_profile']?['bio'];
            _phone = userData['phone'];
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
        // Count posts
        final postsResult = await supabase
            .from('post')
            .select('post_id')
            .eq('company_id', widget.companyId!);
        _postsCount = (postsResult as List).length;

        // Count job posts
        final jobPostsResult = await supabase
            .from('job_post')
            .select('job_id')
            .eq('company_id', widget.companyId!);
        _jobPostsCount = (jobPostsResult as List).length;

        // Count followers
        final followersResult = await supabase
            .from('follows')
            .select('follow_id')
            .eq('following_id', widget.companyId!);
        _followersCount = (followersResult as List).length;

        // Count branches
        final branchesResult = await supabase
            .from('company_branch')
            .select('branch_id')
            .eq('company_id', widget.companyId!);
        _branchesCount = (branchesResult as List).length;

        debugPrint('Stats - Posts: $_postsCount, Job Posts: $_jobPostsCount, Followers: $_followersCount, Branches: $_branchesCount');
      } else {
        // For user profile - only show posts and followers count
        final postsResult = await supabase
            .from('post')
            .select('post_id')
            .eq('user_id', widget.userId);
        _postsCount = (postsResult as List).length;

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
          .eq(widget.isCompany ? 'company_id' : 'user_id',
          widget.isCompany ? widget.companyId! : widget.userId)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        final postsList = List<Map<String, dynamic>>.from(posts);

        // Get like counts for each post
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

          // Get comment counts for each post
          final commentCounts = await supabase
              .from('post_comment')
              .select('post_id')
              .inFilter('post_id', postIds);

          final commentCountMap = <String, int>{};
          for (final comment in commentCounts) {
            final postId = comment['post_id'] as String;
            commentCountMap[postId] = (commentCountMap[postId] ?? 0) + 1;
          }

          // Attach counts to posts
          for (final post in postsList) {
            final pid = post['post_id'] as String;
            post['like_count'] = likeCountMap[pid] ?? 0;
            post['comment_count'] = commentCountMap[pid] ?? 0;
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
          .eq('status', 'active')
          .order('created_at', ascending: false);

      if (mounted) {
        final jobList = List<Map<String, dynamic>>.from(jobPosts);

        // Process each job to extract nested data
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
      late final List<dynamic> followersData;

      if (widget.isCompany && widget.companyId != null) {
        followersData = await supabase
            .from('follows')
            .select('follower_id')
            .eq('following_id', widget.companyId!);
      } else {
        followersData = await supabase
            .from('follows')
            .select('follower_id')
            .eq('following_id', widget.userId);
      }

      if (mounted && followersData.isNotEmpty) {
        final followerIds = followersData.map((f) => f['follower_id'] as String).toList();

        if (followerIds.isNotEmpty) {
          final usersData = await supabase
              .from('users')
              .select('user_id, fullname, profile_image_url')
              .inFilter('user_id', followerIds);

          final followersList = usersData.map((user) => {
            'users': user,
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

  Future<void> _checkFollowStatus() async {
    if (_currentUserId == null) return;

    try {
      final result = await supabase
          .from('follows')
          .select()
          .eq('follower_id', _currentUserId!)
          .eq('following_id', widget.isCompany ? widget.companyId! : widget.userId)
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

    setState(() => _isFollowing = !_isFollowing);

    try {
      if (_isFollowing) {
        await supabase.from('follows').insert({
          'follower_id': _currentUserId,
          'following_id': widget.isCompany ? widget.companyId! : widget.userId,
        });
        setState(() => _followersCount++);
        await _loadFollowers();
      } else {
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', widget.isCompany ? widget.companyId! : widget.userId);
        setState(() => _followersCount--);
        await _loadFollowers();
      }
    } catch (e) {
      setState(() => _isFollowing = !_isFollowing);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwnProfile = _currentUserId == widget.userId;
    final String displayName = widget.isCompany
        ? (_companyName ?? widget.name ?? 'Company')
        : (_fullname ?? widget.name ?? 'User');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(

        actions: [
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
          if (!widget.isCompany) {
            await _loadJobSeekerDetails();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeaderSection(displayName),
              if (widget.isCompany) _buildCompanyInfoSection(),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[200],
            backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
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
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
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
            _buildInfoRow(Icons.location_on_outlined, 'Head Office', headOfficeLocation),
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
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayBio,
            style: const TextStyle(height: 1.5),
          ),
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
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(_postsCount, 'Posts', 0),
            _buildStatItem(_jobPostsCount, 'Jobs', 1),
            _buildStatItem(_branchesCount, 'Branches', 2),
            _buildStatItem(_followersCount, 'Followers', 3),
          ],
        ),
      );
    } else {
      // For job seeker - only show Posts and Followers in stats row
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(_postsCount, 'Posts', -1),
            _buildStatItem(_followingCount, 'Following', -1),
          ],
        ),
      );
    }
  }

  Widget _buildStatItem(int count, String label, int index) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),

        ],
      ),
    );
  }

  // Company content section with tabs
  Widget _buildCompanyContentSection() {
    return Column(
      children: [
        _buildCompanyTabs(),
        if (_selectedTabIndex == 0)
          _buildPostsContent()
        else if (_selectedTabIndex == 1)
          _buildJobPostsContent()
        else if (_selectedTabIndex == 2)
            _buildBranchesContent()
          else if (_selectedTabIndex == 3)
              _buildFollowersContent(),
      ],
    );
  }

  Widget _buildCompanyTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTabButton('Posts', 0),
          _buildTabButton('Jobs', 1),
          _buildTabButton('Branches', 2),
          _buildTabButton('Followers', 3),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: TextButton(
        onPressed: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        style: TextButton.styleFrom(
          foregroundColor: isSelected ? Colors.blue : Colors.grey,
          backgroundColor: isSelected ? Colors.blue.shade50 : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Job Seeker content section with expandable sections
  Widget _buildJobSeekerContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Posts Section
        _buildSectionHeader('Posts', Icons.post_add_outlined),
        _buildPostsContent(),

        const SizedBox(height: 16),

        // Experience Section
        _buildExpandableSection(
          title: 'Work Experience',
          icon: Icons.work_outline,
          isExpanded: _showExperience,
          onToggle: () => setState(() => _showExperience = !_showExperience),
          content: _buildExperienceContent(),
          itemCount: _experience.length,
        ),

        const SizedBox(height: 16),

        // Education Section
        _buildExpandableSection(
          title: 'Education',
          icon: Icons.school_outlined,
          isExpanded: _showEducation,
          onToggle: () => setState(() => _showEducation = !_showEducation),
          content: _buildEducationContent(),
          itemCount: _education.length,
        ),

        const SizedBox(height: 16),

        // Skills Section
        _buildExpandableSection(
          title: 'Skills',
          icon: Icons.code_outlined,
          isExpanded: _showSkills,
          onToggle: () => setState(() => _showSkills = !_showSkills),
          content: _buildSkillsContent(),
          itemCount: _skills.length,
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
    required int itemCount,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Colors.blue),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (itemCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$itemCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
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
              if (exp['description'] != null && exp['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  exp['description'],
                  style: const TextStyle(fontSize: 13),
                ),
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
              if (edu['field_of_study'] != null && edu['field_of_study'].toString().isNotEmpty) ...[
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
              if (edu['description'] != null && edu['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  edu['description'],
                  style: const TextStyle(fontSize: 13),
                ),
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
          if (skillLevel == 'Beginner') levelColor = Colors.green;
          else if (skillLevel == 'Intermediate') levelColor = Colors.orange;
          else if (skillLevel == 'Advanced') levelColor = Colors.red;

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
                    style: TextStyle(
                      fontSize: 11,
                      color: levelColor,
                    ),
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
    final end = endDate != null && endDate.isNotEmpty ? _formatShortDate(endDate) : 'Present';
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
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No posts yet'),
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

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
              ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      post['post_type'] ?? 'post',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post['content'] ?? '',
                style: const TextStyle(fontSize: 14),
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
                ],
              ),
            ],
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
        child: const Center(
          child: Text('No active job posts'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _jobPosts.length,
      itemBuilder: (context, index) {
        final job = _jobPosts[index];

        // Format salary display
        String salaryDisplay = 'Not specified';
        final salaryMin = job['salary_min'];
        final salaryMax = job['salary_max'];
        if (salaryMin != null && salaryMax != null) {
          salaryDisplay = 'RM ${_formatSalary(salaryMin)} - RM ${_formatSalary(salaryMax)}';
        } else if (salaryMin != null) {
          salaryDisplay = 'From RM ${_formatSalary(salaryMin)}';
        } else if (salaryMax != null) {
          salaryDisplay = 'Up to RM ${_formatSalary(salaryMax)}';
        }

        final remoteOption = job['remote_option'] == true;
        final jobType = job['job_type'] ?? 'Not specified';
        final experienceLevel = job['experience_level'] ?? 'Not specified';
        final location = job['location'] ?? 'Location not specified';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job['job_title'] ?? 'Untitled Position',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.work_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    jobType,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (remoteOption) ...[
                Row(
                  children: [
                    Icon(Icons.wifi, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Remote',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    experienceLevel,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    salaryDisplay,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'Posted ${_formatDate(job['created_at'])}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
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

  Widget _buildBranchesContent() {
    if (_branches.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No branches found'),
        ),
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
            border: isHeadOffice ? Border.all(color: Colors.blue.shade200) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
              ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          branch['address'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (branch['city'] != null || branch['state'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.location_city, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${branch['city'] ?? ''}${branch['city'] != null && branch['state'] != null ? ', ' : ''}${branch['state'] ?? ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (branch['country'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.public, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        branch['country'],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              if (branch['phone'] != null && branch['phone'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        branch['phone'],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              if (branch['email'] != null && branch['email'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        branch['email'],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFollowersContent() {
    if (_followers.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No followers yet'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _followers.length,
      itemBuilder: (context, index) {
        final followerData = _followers[index];
        final user = followerData['users'] as Map<String, dynamic>?;

        if (user == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: user['profile_image_url'] != null
                    ? CachedNetworkImageProvider(user['profile_image_url'])
                    : null,
                child: user['profile_image_url'] == null
                    ? Icon(Icons.person, size: 24, color: Colors.blue)
                    : null,
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
                    Text(
                      'Follower',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_currentUserId != user['user_id'])
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewProfilePage(
                          userId: user['user_id'],
                          companyId: null,
                          name: user['fullname'],
                          avatarUrl: user['profile_image_url'],
                          isCompany: false,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('View'),
                ),
            ],
          ),
        );
      },
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