import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jobify/users.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jobify/main.dart';
import 'package:jobify/data/user_repository.dart';
import 'package:jobify/data/local_db.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  late final UserRepository _userRepo;

  /// Basic user info
  String? userId;
  String? role;
  String? userEmail;

  /// User data
  String fullname = '';
  String phone = '';
  String profileImageUrl = '';

  /// Job seeker data
  String dateOfBirth = '';
  String gender = '';
  String address = '';
  String bio = '';

  /// Company data
  String companyName = '';
  String companyDescription = '';
  String industry = '';
  String companySize = '';
  String location = '';
  String companyPhone = '';
  String companyEmail = '';
  String websiteUrl = '';

  /// Skills
  List<Map<String, dynamic>> skills = [];

  /// Education
  List<Map<String, dynamic>> educationList = [];

  /// Work Experience
  List<Map<String, dynamic>> workList = [];

  /// Resume
  List<Map<String, dynamic>> resumes = [];

  bool isLoading = true;
  bool isRefreshing = false;
  bool isEditingAbout = false;
  final TextEditingController _aboutController = TextEditingController();

  // Industry options
  final List<String> industryOptions = [
    'Technology',
    'Healthcare',
    'Finance',
    'Marketing',
    'Retail',
    'Manufacturing',
    'Education',
    'Construction',
    'Hospitality',
    'Transportation',
    'Real Estate',
    'Consulting',
    'Legal',
    'Entertainment',
    'Agriculture',
    'Energy',
    'Telecommunications',
    'Other'
  ];

  // Company size options
  final List<String> companySizeOptions = [
    '1-10 employees',
    '11-50 employees',
    '51-200 employees',
    '201-500 employees',
    '500+ employees'
  ];

  @override
  void initState() {
    super.initState();
    _userRepo = UserRepository();
    _loadProfile();
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      userId = user.id;
      userEmail = user.email;

      debugPrint('Loading profile for user: $userId');

      await _loadFromCacheOnly();
      await _fetchFreshData();

    } catch (e) {
      debugPrint('Error loading profile: $e');
      await _loadFromCacheOnly();
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchFreshData() async {
    if (userId == null) return;

    try {
      debugPrint('Fetching fresh profile data from Supabase...');

      final userData = await supabase
          .from('users')
          .select()
          .eq('user_id', userId!)
          .single();

      final user = Users.fromJson(userData);
      await LocalDB.cacheUser(user);

      if (mounted) {
        setState(() {
          fullname = user.fullname;
          phone = user.phone ?? '';
          role = user.role;
          profileImageUrl = user.profileImageUrl ?? '';
        });
      }

      if (role == 'JOB_SEEKER') {
        final profile = await supabase
            .from('job_seeker_profile')
            .select()
            .eq('user_id', userId!)
            .maybeSingle();

        if (profile != null && mounted) {
          setState(() {
            dateOfBirth = profile['date_of_birth'] ?? '';
            gender = profile['gender'] ?? '';
            address = profile['address'] ?? '';
            bio = profile['bio'] ?? '';
          });
          await LocalDB.cacheJobSeekerProfile(userId!, profile);
        }

        final resumeData = await supabase
            .from('resume')
            .select()
            .eq('user_id', userId!);
        if (mounted) {
          setState(() {
            resumes = List<Map<String, dynamic>>.from(resumeData);
          });
          await LocalDB.cacheResumes(userId!, resumes);
        }

        // Fetch skills, education, experience
        final skillData = await supabase
            .from('skills')
            .select()
            .eq('user_id', userId!);
        if (mounted) {
          setState(() {
            skills = List<Map<String, dynamic>>.from(skillData);
          });
          await LocalDB.cacheSkills(userId!, skills);
        }

        final eduData = await supabase
            .from('education')
            .select()
            .eq('user_id', userId!);
        if (mounted) {
          setState(() {
            educationList = List<Map<String, dynamic>>.from(eduData);
          });
          await LocalDB.cacheEducation(userId!, educationList);
        }

        final workData = await supabase
            .from('experience')
            .select()
            .eq('user_id', userId!);
        if (mounted) {
          setState(() {
            workList = List<Map<String, dynamic>>.from(workData);
          });
          await LocalDB.cacheExperience(userId!, workList);
        }

      } else if (role == 'POSTER') {
        final profile = await supabase
            .from('company_profile')
            .select()
            .eq('user_id', userId!)
            .maybeSingle();

        if (profile != null && mounted) {
          setState(() {
            companyName = profile['company_name'] ?? '';
            companyDescription = profile['company_description'] ?? '';
            industry = profile['industry'] ?? '';
            companySize = profile['company_size'] ?? '';
            location = profile['location'] ?? '';
          });
          await LocalDB.cacheCompanyProfile(userId!, profile);
        }
      }

      debugPrint('Fresh profile data loaded successfully');

    } catch (e) {
      debugPrint('Error fetching fresh data: $e');
    }
  }

  Future<void> _loadFromCacheOnly() async {
    if (userId == null) return;

    try {
      debugPrint('Loading profile from cache...');

      final cachedUser = await LocalDB.getCachedUser(userId!);
      if (cachedUser != null && mounted) {
        setState(() {
          fullname = cachedUser.fullname;
          phone = cachedUser.phone ?? '';
          role = cachedUser.role;
          userEmail = cachedUser.email;
          profileImageUrl = cachedUser.profileImageUrl ?? '';
        });
      }


      if (role == 'JOB_SEEKER') {
        final cachedSkills = await LocalDB.getCachedSkills(userId!);
        final cachedEducation = await LocalDB.getCachedEducation(userId!);
        final cachedExperience = await LocalDB.getCachedExperience(userId!);
        final cachedResumes = await LocalDB.getCachedResumes(userId!);

        if (mounted) {
          setState(() {
            skills = List<Map<String, dynamic>>.from(cachedSkills);
            educationList = List<Map<String, dynamic>>.from(cachedEducation);
            workList = List<Map<String, dynamic>>.from(cachedExperience);
            resumes = List<Map<String, dynamic>>.from(cachedResumes);
          });
        }

        final cachedProfile = await LocalDB.getCachedJobSeekerProfile(userId!);
        if (cachedProfile != null && mounted) {
          setState(() {
            dateOfBirth = cachedProfile['date_of_birth'] ?? '';
            gender = cachedProfile['gender'] ?? '';
            address = cachedProfile['address'] ?? '';
            bio = cachedProfile['bio'] ?? '';
          });
        }
      } else if (role == 'POSTER') {
        final cachedProfile = await LocalDB.getCachedCompanyProfile(userId!);
        if (cachedProfile != null && mounted) {
          setState(() {
            companyName = cachedProfile['company_name'] ?? '';
            companyDescription = cachedProfile['company_description'] ?? '';
            industry = cachedProfile['industry'] ?? '';
            companySize = cachedProfile['company_size'] ?? '';
            location = cachedProfile['location'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    }
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;
    setState(() => isRefreshing = true);
    await _fetchFreshData();
    if (mounted) setState(() => isRefreshing = false);
  }

  // ==================== PROFILE IMAGE UPLOAD ====================
  Future<void> _uploadProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storagePath = 'profile_images/$userId/$fileName';

        // Upload to storage
        await supabase.storage.from('avatars').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );

        final publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);

        // Update users table
        await _userRepo.updateUser(userId!, {
          'profile_image_url': publicUrl,
        });

        await _refreshProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile image updated!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading image: $e")),
        );
      }
    }
  }

  // ==================== COMPANY LOGO UPLOAD ====================
  Future<void> _uploadCompanyLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        // Check if userId is not null
        if (userId == null) {
          throw Exception("User ID is null");
        }

        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storagePath = 'company_logos/$userId/$fileName';

        // Upload to storage
        await supabase.storage.from('company-logos').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );

        final publicUrl = supabase.storage.from('company-logos').getPublicUrl(storagePath);

        if (publicUrl != null) {
          // Update company_profile table - userId is now guaranteed non-null
          await supabase
              .from('company_profile')
              .update({'logo_url': publicUrl})
              .eq('user_id', userId!);  // userId is now String, not String?

          await _refreshProfile();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Company logo updated!")),
            );
          }
        } else {
          throw Exception("Failed to get public URL for uploaded logo");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading logo: $e")),
        );
      }
    }
  }

  // ==================== COMPANY INFO EDIT ====================
  void _showEditCompanyInfoBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CompanyInfoFormBottomSheet(
        userId: userId!,
        companyName: companyName,
        industry: industry,
        companySize: companySize,
        location: location,
        companyPhone: companyPhone,
        companyEmail: companyEmail,
        websiteUrl: websiteUrl,
        industryOptions: industryOptions,
        companySizeOptions: companySizeOptions,
        userRepository: _userRepo,
        onSuccess: () => _refreshProfile(),
      ),
    );
  }

  // ==================== COMPANY DESCRIPTION EDIT ====================
  void _showEditCompanyDescriptionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CompanyDescriptionFormBottomSheet(
        userId: userId!,
        companyDescription: companyDescription,
        userRepository: _userRepo,
        onSuccess: () => _refreshProfile(),
      ),
    );
  }

  // ==================== PERSONAL INFO EDIT ====================
  void _showEditPersonalInfoBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PersonalInfoFormBottomSheet(
        userId: userId!,
        role: role!,
        fullname: fullname,
        phone: phone,
        dateOfBirth: dateOfBirth,
        gender: gender,
        address: address,
        bio: bio,
        companyName: companyName,
        companyDescription: companyDescription,
        industry: industry,
        companySize: companySize,
        location: location,
        userRepository: _userRepo,
        onSuccess: () => _refreshProfile(),
      ),
    );
  }

  // ==================== RESUME METHODS ====================
  Future<void> _uploadResume() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait, profile is loading...")),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null && mounted) {
        final file = result.files.first;
        final bytes = file.bytes; // This is Uint8List
        final fileName = file.name;

        if (bytes != null) {
          final storagePath = 'resumes/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

          // Upload to storage - bytes is Uint8List which implements List<int>
          await supabase.storage.from('resumes').uploadBinary(
            storagePath,
            bytes,  // This works - Uint8List is a List<int>
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

          final publicUrl = supabase.storage.from('resumes').getPublicUrl(storagePath);

          await _userRepo.addResume(userId!, publicUrl, fileName);
          await _refreshProfile();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Resume uploaded successfully!")),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading resume: $e")),
        );
      }
    }
  }

  Future<void> _deleteResume(Map<String, dynamic> resume) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Resume"),
        content: Text("Are you sure you want to delete '${resume['file_name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final url = resume['file_url'] as String;
                final path = url.split('/resumes/').last;
                await supabase.storage.from('resumes').remove([path]);
                await _userRepo.deleteResume(resume['resume_id']);
                await _refreshProfile();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Resume deleted")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error deleting resume: $e")),
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ==================== SKILL METHODS ====================
  void _showAddSkillBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SkillFormBottomSheet(
        userId: userId!,
        userRepository: _userRepo,
        onSuccess: () => _refreshProfile(),
      ),
    );
  }

  void _showEditSkillBottomSheet(Map<String, dynamic> skill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SkillFormBottomSheet(
        userId: userId!,
        skill: skill,
        userRepository: _userRepo,
        onSuccess: () => _refreshProfile(),
      ),
    );
  }

  Future<void> _deleteSkill(Map<String, dynamic> skill) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Skill"),
        content: Text("Are you sure you want to delete '${skill['skill_name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _userRepo.deleteSkill(skill['skill_id']);
              await _refreshProfile();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Skill deleted")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ==================== EDUCATION METHODS ====================
  void _showAddEducationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EducationFormBottomSheet(
        userId: userId!,
        userRepository: _userRepo,
        onSuccess: () => _refreshProfile(),
      ),
    );
  }

  void _showEditEducationBottomSheet(Map<String, dynamic> education) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EducationFormBottomSheet(
        userId: userId!,
        education: education,
        userRepository: _userRepo,
        onSuccess: () => _refreshProfile(),
      ),
    );
  }

  Future<void> _deleteEducation(Map<String, dynamic> education) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Education"),
        content: const Text("Are you sure you want to delete this education record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _userRepo.deleteEducation(education['education_id']);
              await _refreshProfile();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Education deleted")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ==================== WORK METHODS ====================
  void _showAddWorkBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => WorkFormBottomSheet(
        userId: userId!,
        userRepository: _userRepo,
        onSuccess: () => _refreshProfile(),
      ),
    );
  }

  void _showEditWorkBottomSheet(Map<String, dynamic> work) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => WorkFormBottomSheet(
        userId: userId!,
        work: work,
        userRepository: _userRepo,
        onSuccess: () => _refreshProfile(),
      ),
    );
  }

  Future<void> _deleteWork(Map<String, dynamic> work) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Work Experience"),
        content: const Text("Are you sure you want to delete this work experience?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _userRepo.deleteExperience(work['experience_id']);
              await _refreshProfile();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Work experience deleted")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isJobSeeker = role == 'JOB_SEEKER';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(25, 25, 25, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Back Button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      'My Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 30),

                // PROFILE PHOTO SECTION (with upload icon)
                _buildProfileHeader(isJobSeeker),

                // COMPANY INFO (for Poster)
                if (!isJobSeeker) ...[
                  const SizedBox(height: 20),
                  _buildCompanyInfoCard(),
                  const SizedBox(height: 15),
                  _buildCompanyDescriptionCard(),
                  const SizedBox(height: 15),
                ],

                // PERSONAL INFO (for Job Seeker)
                if (isJobSeeker) ...[
                  const SizedBox(height: 15),
                  _buildPersonalInfoCard(),
                  const SizedBox(height: 15),
                  _buildSkillsCard(),
                  const SizedBox(height: 15),
                  _buildEducationCard(),
                  const SizedBox(height: 15),
                  _buildWorkCard(),
                  const SizedBox(height: 15),
                  _buildResumeCard(),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== PROFILE HEADER WIDGET ====================
  Widget _buildProfileHeader(bool isJobSeeker) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Image with Upload Icon
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: profileImageUrl.isEmpty
                    ? Icon(
                  isJobSeeker ? Icons.person : Icons.business,
                  size: 50,
                  color: Colors.blue,
                )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: isJobSeeker ? _uploadProfileImage : _uploadCompanyLogo,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isJobSeeker
                      ? (fullname.isNotEmpty ? fullname : 'No name set')
                      : (companyName.isNotEmpty ? companyName : 'No company name'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (role != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isJobSeeker
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isJobSeeker
                            ? Colors.green.shade200
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Text(
                      isJobSeeker ? 'Job Seeker' : 'Employer',
                      style: TextStyle(
                        fontSize: 12,
                        color: isJobSeeker
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== COMPANY INFO CARD ====================
  Widget _buildCompanyInfoCard() {
    return buildCardWithEditButton(
      title: "Company Information",
      onEdit: _showEditCompanyInfoBottomSheet,
      child: Column(
        children: [
          buildInfoRow("Company Name", companyName.isNotEmpty ? companyName : "Not set"),
          buildInfoRow("Industry", industry.isNotEmpty ? industry : "Not set"),
          buildInfoRow("Company Size", companySize.isNotEmpty ? companySize : "Not set"),
          buildInfoRow("Location", location.isNotEmpty ? location : "Not set"),
          buildInfoRow("Phone Number", phone.isNotEmpty ? phone : "Not set"),
        ],
      ),
    );
  }

  // ==================== COMPANY DESCRIPTION CARD ====================
  Widget _buildCompanyDescriptionCard() {
    return buildCardWithEditButton(
      title: "About Company",
      onEdit: _showEditCompanyDescriptionBottomSheet,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          companyDescription.isNotEmpty ? companyDescription : "No company description provided yet.",
          style: TextStyle(
            fontSize: 14,
            color: companyDescription.isNotEmpty ? Colors.black87 : Colors.grey,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  // ==================== PERSONAL INFO CARD ====================
  Widget _buildPersonalInfoCard() {
    final bool isJobSeeker = role == 'JOB_SEEKER';

    return buildCardWithEditButton(
      title: isJobSeeker ? "Personal Information" : "Contact Person",
      onEdit: _showEditPersonalInfoBottomSheet,
      child: isJobSeeker
          ? Column(
        children: [
          buildInfoRow("Full Name", fullname.isNotEmpty ? fullname : "Not set"),
          buildInfoRow("Phone Number", phone.isNotEmpty ? phone : "Not set"),
          buildInfoRow("Email", userEmail ?? "Not set"),
          buildInfoRow("Date of Birth", dateOfBirth.isNotEmpty ? dateOfBirth : "Not set"),
          buildInfoRow("Gender", gender.isNotEmpty ? gender : "Not set"),
          buildInfoRow("Address", address.isNotEmpty ? address : "Not set"),
          buildInfoRow("Bio", bio.isNotEmpty ? bio : "Not set", isMultiline: true),
        ],
      )
          : Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            backgroundImage: profileImageUrl.isNotEmpty
                ? NetworkImage(profileImageUrl)
                : null,
            child: profileImageUrl.isEmpty
                ? const Icon(Icons.person, size: 30, color: Colors.blue)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullname.isNotEmpty ? fullname : "No name set",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone.isNotEmpty ? phone : "No phone number",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail ?? "No email",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SKILLS CARD ====================
  Widget _buildSkillsCard() {
    return buildCardWithAddButton(
      title: "Skills",
      onAdd: _showAddSkillBottomSheet,
      child: skills.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "No skills added yet. Tap + to add skills.",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : Wrap(
        spacing: 8,
        runSpacing: 8,
        children: skills.map((skill) {
          return SkillChip(
            skill: skill,
            onEdit: () => _showEditSkillBottomSheet(skill),
            onDelete: () => _deleteSkill(skill),
          );
        }).toList(),
      ),
    );
  }

  // ==================== EDUCATION CARD ====================
  Widget _buildEducationCard() {
    return buildCardWithAddButton(
      title: "Education",
      onAdd: _showAddEducationBottomSheet,
      child: educationList.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "No education added yet. Tap + to add education.",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : Column(
        children: educationList.map((edu) {
          return EducationItem(
            education: edu,
            onEdit: () => _showEditEducationBottomSheet(edu),
            onDelete: () => _deleteEducation(edu),
          );
        }).toList(),
      ),
    );
  }

  // ==================== WORK CARD ====================
  Widget _buildWorkCard() {
    return buildCardWithAddButton(
      title: "Work Experience",
      onAdd: _showAddWorkBottomSheet,
      child: workList.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "No work experience added yet. Tap + to add experience.",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : Column(
        children: workList.map((work) {
          return WorkItem(
            work: work,
            onEdit: () => _showEditWorkBottomSheet(work),
            onDelete: () => _deleteWork(work),
          );
        }).toList(),
      ),
    );
  }

  // ==================== RESUME CARD ====================
  Widget _buildResumeCard() {
    return buildCardWithAddButton(
      title: "Resume",
      onAdd: _uploadResume,
      child: resumes.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "No resume uploaded yet. Tap + to upload resume.",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : Column(
        children: resumes.map((resume) {
          return ResumeItem(
            resume: resume,
            onDelete: () => _deleteResume(resume),
            onDownload: () => _downloadResume(resume),
          );
        }).toList(),
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget buildInfoRow(String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget buildCardWithEditButton({
    required String title,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: onEdit,
                tooltip: 'Edit $title',
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget buildCardWithAddButton({
    required String title,
    required VoidCallback onAdd,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: onAdd,
                tooltip: 'Add $title',
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Future<void> _downloadResume(Map<String, dynamic> resume) async {
    try {
      final url = resume['file_url'] as String;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opening: ${resume['file_name']}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening resume: $e")),
      );
    }
  }
}

// ==================== COMPANY INFO FORM BOTTOM SHEET ====================
class CompanyInfoFormBottomSheet extends StatefulWidget {
  final String userId;
  final String companyName;
  final String industry;
  final String companySize;
  final String location;
  final String companyPhone;
  final String companyEmail;
  final String websiteUrl;
  final List<String> industryOptions;
  final List<String> companySizeOptions;
  final UserRepository userRepository;
  final VoidCallback onSuccess;

  const CompanyInfoFormBottomSheet({
    super.key,
    required this.userId,
    required this.companyName,
    required this.industry,
    required this.companySize,
    required this.location,
    required this.companyPhone,
    required this.companyEmail,
    required this.websiteUrl,
    required this.industryOptions,
    required this.companySizeOptions,
    required this.userRepository,
    required this.onSuccess,
  });

  @override
  State<CompanyInfoFormBottomSheet> createState() => _CompanyInfoFormBottomSheetState();
}

class _CompanyInfoFormBottomSheetState extends State<CompanyInfoFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _companyNameCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _companyPhoneCtrl;
  late TextEditingController _companyEmailCtrl;
  late TextEditingController _websiteUrlCtrl;
  late String _selectedIndustry;
  late String _selectedCompanySize;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _companyNameCtrl = TextEditingController(text: widget.companyName);
    _locationCtrl = TextEditingController(text: widget.location);
    _companyPhoneCtrl = TextEditingController(text: widget.companyPhone);
    _companyEmailCtrl = TextEditingController(text: widget.companyEmail);
    _websiteUrlCtrl = TextEditingController(text: widget.websiteUrl);
    _selectedIndustry = widget.industry;
    _selectedCompanySize = widget.companySize;
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _locationCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyEmailCtrl.dispose();
    _websiteUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await widget.userRepository.updateCompanyProfile(widget.userId, {
        'company_name': _companyNameCtrl.text.trim(),
        'industry': _selectedIndustry,
        'company_size': _selectedCompanySize,
        'location': _locationCtrl.text.trim(),
      });

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Company info updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Edit Company Information",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _companyNameCtrl,
                decoration: const InputDecoration(
                  labelText: "Company Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter company name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedIndustry.isEmpty ? null : _selectedIndustry,
                decoration: const InputDecoration(
                  labelText: "Industry",
                  border: OutlineInputBorder(),
                ),
                items: widget.industryOptions.map((industry) {
                  return DropdownMenuItem(
                    value: industry,
                    child: Text(industry),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedIndustry = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCompanySize.isEmpty ? null : _selectedCompanySize,
                decoration: const InputDecoration(
                  labelText: "Company Size",
                  border: OutlineInputBorder(),
                ),
                items: widget.companySizeOptions.map((size) {
                  return DropdownMenuItem(
                    value: size,
                    child: Text(size),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCompanySize = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: "Location",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter location";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Save Changes"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== COMPANY DESCRIPTION FORM BOTTOM SHEET ====================
class CompanyDescriptionFormBottomSheet extends StatefulWidget {
  final String userId;
  final String companyDescription;
  final UserRepository userRepository;
  final VoidCallback onSuccess;

  const CompanyDescriptionFormBottomSheet({
    super.key,
    required this.userId,
    required this.companyDescription,
    required this.userRepository,
    required this.onSuccess,
  });

  @override
  State<CompanyDescriptionFormBottomSheet> createState() => _CompanyDescriptionFormBottomSheetState();
}

class _CompanyDescriptionFormBottomSheetState extends State<CompanyDescriptionFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descriptionCtrl = TextEditingController(text: widget.companyDescription);
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await widget.userRepository.updateCompanyProfile(widget.userId, {
        'company_description': _descriptionCtrl.text.trim(),
      });

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Company description updated!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Edit Company Description",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: "Company Description",
                  hintText: "Tell us about your company...",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Save Description"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PERSONAL INFO FORM BOTTOM SHEET ====================
class PersonalInfoFormBottomSheet extends StatefulWidget {
  final String userId;
  final String role;
  final String fullname;
  final String phone;
  final String dateOfBirth;
  final String gender;
  final String address;
  final String bio;
  final String companyName;
  final String companyDescription;
  final String industry;
  final String companySize;
  final String location;
  final UserRepository userRepository;
  final VoidCallback onSuccess;

  const PersonalInfoFormBottomSheet({
    super.key,
    required this.userId,
    required this.role,
    required this.fullname,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.bio,
    required this.companyName,
    required this.companyDescription,
    required this.industry,
    required this.companySize,
    required this.location,
    required this.userRepository,
    required this.onSuccess,
  });

  @override
  State<PersonalInfoFormBottomSheet> createState() => _PersonalInfoFormBottomSheetState();
}

class _PersonalInfoFormBottomSheetState extends State<PersonalInfoFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullnameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _bioCtrl;
  late String _selectedGender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullnameCtrl = TextEditingController(text: widget.fullname);
    _phoneCtrl = TextEditingController(text: widget.phone);
    _dobCtrl = TextEditingController(text: widget.dateOfBirth);
    _addressCtrl = TextEditingController(text: widget.address);
    _bioCtrl = TextEditingController(text: widget.bio);
    _selectedGender = widget.gender;
  }

  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await widget.userRepository.updateUser(widget.userId, {
        'fullname': _fullnameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });

      if (widget.role == 'JOB_SEEKER') {
        await widget.userRepository.updateJobSeekerProfile(widget.userId, {
          'date_of_birth': _dobCtrl.text.isEmpty ? null : _dobCtrl.text,
          'gender': _selectedGender,
          'address': _addressCtrl.text,
          'bio': _bioCtrl.text,
        });
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isJobSeeker = widget.role == 'JOB_SEEKER';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isJobSeeker ? "Edit Personal Information" : "Edit Contact Person",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _fullnameCtrl,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter full name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                ),
              ),

              if (isJobSeeker) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dobCtrl,
                  decoration: const InputDecoration(
                    labelText: "Date of Birth (YYYY-MM-DD)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedGender.isEmpty ? null : _selectedGender,
                  decoration: const InputDecoration(
                    labelText: "Gender",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "Male", child: Text("Male")),
                    DropdownMenuItem(value: "Female", child: Text("Female")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Address",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Bio",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Save Changes"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SKILL FORM BOTTOM SHEET
// ============================================================================

class SkillFormBottomSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? skill;
  final UserRepository userRepository;
  final VoidCallback onSuccess;

  const SkillFormBottomSheet({
    super.key,
    required this.userId,
    this.skill,
    required this.userRepository,
    required this.onSuccess,
  });

  @override
  State<SkillFormBottomSheet> createState() => _SkillFormBottomSheetState();
}

class _SkillFormBottomSheetState extends State<SkillFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _skillNameCtrl = TextEditingController();
  String? _selectedLevel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.skill != null) {
      _skillNameCtrl.text = widget.skill!['skill_name'] ?? '';
      _selectedLevel = widget.skill!['skill_level'];
    }
  }

  @override
  void dispose() {
    _skillNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (widget.skill == null) {
        await widget.userRepository.addSkill(widget.userId, _skillNameCtrl.text.trim(), _selectedLevel);
      } else {
        await widget.userRepository.updateSkill(widget.skill!['skill_id'], _skillNameCtrl.text.trim(), _selectedLevel);
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.skill == null ? "Skill added" : "Skill updated"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.skill == null ? "Add Skill" : "Edit Skill",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _skillNameCtrl,
                decoration: const InputDecoration(
                  labelText: "Skill Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter skill name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLevel,
                decoration: const InputDecoration(
                  labelText: "Skill Level",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "Beginner", child: Text("Beginner")),
                  DropdownMenuItem(value: "Intermediate", child: Text("Intermediate")),
                  DropdownMenuItem(value: "Advanced", child: Text("Advanced")),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(widget.skill == null ? "Add Skill" : "Update Skill"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EDUCATION FORM BOTTOM SHEET
// ============================================================================

class EducationFormBottomSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? education;
  final UserRepository userRepository;
  final VoidCallback onSuccess;

  const EducationFormBottomSheet({
    super.key,
    required this.userId,
    this.education,
    required this.userRepository,
    required this.onSuccess,
  });

  @override
  State<EducationFormBottomSheet> createState() => _EducationFormBottomSheetState();
}

class _EducationFormBottomSheetState extends State<EducationFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _institutionCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.education != null) {
      _institutionCtrl.text = widget.education!['institution_name'] ?? '';
      _qualificationCtrl.text = widget.education!['qualification'] ?? '';
      _fieldCtrl.text = widget.education!['field_of_study'] ?? '';
      _startDateCtrl.text = widget.education!['start_date'] ?? '';
      _endDateCtrl.text = widget.education!['end_date'] ?? '';
      _descriptionCtrl.text = widget.education!['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _institutionCtrl.dispose();
    _qualificationCtrl.dispose();
    _fieldCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'institution_name': _institutionCtrl.text.trim(),
        'qualification': _qualificationCtrl.text.trim(),
        'field_of_study': _fieldCtrl.text.trim(),
        'start_date': _startDateCtrl.text.isEmpty ? null : _startDateCtrl.text,
        'end_date': _endDateCtrl.text.isEmpty ? null : _endDateCtrl.text,
        'description': _descriptionCtrl.text.trim(),
      };

      if (widget.education == null) {
        await widget.userRepository.addEducation(widget.userId, data);
      } else {
        await widget.userRepository.updateEducation(widget.education!['education_id'], data);
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.education == null ? "Education added" : "Education updated"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.education == null ? "Add Education" : "Edit Education",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _institutionCtrl,
                decoration: const InputDecoration(
                  labelText: "Institution Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter institution name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qualificationCtrl,
                decoration: const InputDecoration(
                  labelText: "Qualification",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fieldCtrl,
                decoration: const InputDecoration(
                  labelText: "Field of Study",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startDateCtrl,
                decoration: const InputDecoration(
                  labelText: "Start Date (YYYY-MM-DD)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endDateCtrl,
                decoration: const InputDecoration(
                  labelText: "End Date (YYYY-MM-DD) (Leave empty if current)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(widget.education == null ? "Add Education" : "Update Education"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WORK FORM BOTTOM SHEET
// ============================================================================

class WorkFormBottomSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? work;
  final UserRepository userRepository;
  final VoidCallback onSuccess;

  const WorkFormBottomSheet({
    super.key,
    required this.userId,
    this.work,
    required this.userRepository,
    required this.onSuccess,
  });

  @override
  State<WorkFormBottomSheet> createState() => _WorkFormBottomSheetState();
}

class _WorkFormBottomSheetState extends State<WorkFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.work != null) {
      _companyCtrl.text = widget.work!['company_name'] ?? '';
      _titleCtrl.text = widget.work!['job_title'] ?? '';
      _startDateCtrl.text = widget.work!['start_date'] ?? '';
      _endDateCtrl.text = widget.work!['end_date'] ?? '';
      _descriptionCtrl.text = widget.work!['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _titleCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'company_name': _companyCtrl.text.trim(),
        'job_title': _titleCtrl.text.trim(),
        'start_date': _startDateCtrl.text.isEmpty ? null : _startDateCtrl.text,
        'end_date': _endDateCtrl.text.isEmpty ? null : _endDateCtrl.text,
        'description': _descriptionCtrl.text.trim(),
      };

      if (widget.work == null) {
        await widget.userRepository.addExperience(widget.userId, data);
      } else {
        await widget.userRepository.updateExperience(widget.work!['experience_id'], data);
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.work == null ? "Work experience added" : "Work experience updated"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.work == null ? "Add Work Experience" : "Edit Work Experience",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _companyCtrl,
                decoration: const InputDecoration(
                  labelText: "Company Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter company name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: "Job Title",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter job title";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startDateCtrl,
                decoration: const InputDecoration(
                  labelText: "Start Date (YYYY-MM-DD)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endDateCtrl,
                decoration: const InputDecoration(
                  labelText: "End Date (YYYY-MM-DD) (Leave empty if current)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(widget.work == null ? "Add Experience" : "Update Experience"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SKILL CHIP WIDGET
// ============================================================================

class SkillChip extends StatelessWidget {
  final Map<String, dynamic> skill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SkillChip({
    super.key,
    required this.skill,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(skill['skill_name']),
          if (skill['skill_level'] != null && skill['skill_level'].toString().isNotEmpty)
            Text(
              skill['skill_level'],
              style: const TextStyle(fontSize: 10),
            ),
        ],
      ),
      backgroundColor: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      deleteIcon: const Icon(Icons.more_vert, size: 18),
      onDeleted: () {
        showMenu(
          context: context,
          position: const RelativeRect.fromLTRB(100, 100, 0, 0),
          items: [
            PopupMenuItem(
              onTap: onEdit,
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text("Edit"),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: onDelete,
              child: const Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Delete", style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// EDUCATION ITEM WIDGET
// ============================================================================

class EducationItem extends StatelessWidget {
  final Map<String, dynamic> education;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EducationItem({
    super.key,
    required this.education,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  education['institution_name'] ?? 'Unknown Institution',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                if (education['qualification'] != null &&
                    education['qualification'].toString().isNotEmpty)
                  Text(
                    education['qualification'],
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 4),
                if (education['start_date'] != null)
                  Text(
                    _formatDate(education['start_date']) +
                        (education['end_date'] != null && education['end_date'].toString().isNotEmpty
                            ? ' - ${_formatDate(education['end_date'])}'
                            : ' - Present'),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text("Edit"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Delete", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WORK ITEM WIDGET
// ============================================================================

class WorkItem extends StatelessWidget {
  final Map<String, dynamic> work;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const WorkItem({
    super.key,
    required this.work,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work['job_title'] ?? 'Unknown Position',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  work['company_name'] ?? 'Unknown Company',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (work['start_date'] != null)
                  Text(
                    _formatDate(work['start_date']) +
                        (work['end_date'] != null && work['end_date'].toString().isNotEmpty
                            ? ' - ${_formatDate(work['end_date'])}'
                            : ' - Present'),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text("Edit"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Delete", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RESUME ITEM WIDGET
// ============================================================================

class ResumeItem extends StatelessWidget {
  final Map<String, dynamic> resume;
  final VoidCallback onDelete;
  final VoidCallback onDownload;

  const ResumeItem({
    super.key,
    required this.resume,
    required this.onDelete,
    required this.onDownload,
  });

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resume['file_name'] ?? 'Unknown File',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Uploaded: ${_formatDate(resume['uploaded_at'])}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (resume['is_default'] == true)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'download') onDownload();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18),
                    SizedBox(width: 8),
                    Text("Download"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Delete", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}