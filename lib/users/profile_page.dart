import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jobify/users/user_provider.dart';
import 'package:jobify/users/users.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/data/user_repository.dart';
import 'package:jobify/data/local_db.dart';
import 'package:jobify/job_post/job_post_service.dart';
import 'profile_page_widgets.dart';

/// Function:
/// - upload profile image
/// - edit personal/company info
/// - manage skill, education, experience (job seeker)
/// - manage branch (poster)
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

  String fullname = '';
  String phone = '';
  String profileImageUrl = '';

  String dateOfBirth = '';
  String gender = '';
  String address = '';
  String bio = '';

  String companyName = '';
  String companyDescription = '';
  String industry = '';
  String companySize = '';
  String? _companyId;
  String companyPhone = '';
  String companyEmail = '';

  /// data collection
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> skills = [];
  List<Map<String, dynamic>> educationList = [];
  List<Map<String, dynamic>> workList = [];

  /// Job categories for industry dropdown
  List<Map<String, dynamic>> _jobCategories = [];
  bool _isLoadingCategories = false;

  bool isLoading = true;
  bool isRefreshing = false;

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
    super.dispose();
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    if (email.isEmpty) return true;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Validate phone number format
  bool _isValidPhone(String phone) {
    if (phone.isEmpty)
      return true;
    final phoneRegex = RegExp(r'^[\+]?[0-9][0-9\s\-\(\)]{8,20}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Validate date format (YYYY-MM-DD)
  bool _isValidDateFormat(String date) {
    if (date.isEmpty) return true;
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegex.hasMatch(date)) return false;
    try {
      final parsedDate = DateTime.parse(date);
      final now = DateTime.now();
      if (parsedDate.isAfter(now)) return false;
      if (parsedDate.year < 1950) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load job category from supabase for industry dropdown
  Future<void> _loadJobCategories() async {
    if (_jobCategories.isNotEmpty) return;
    setState(() => _isLoadingCategories = true);
    try {
      final jobPostService = JobPostService();
      final categories = await jobPostService.fetchJobCategories();
      if (mounted) {
        setState(() {
          _jobCategories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading job categories: $e');
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  /// Load profile info
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
      await _loadJobCategories();
    } catch (e) {
      debugPrint('Error loading profile: $e');
      await _loadFromCacheOnly();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Fetch profile data from supabase
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
        await _fetchJobSeekerData();
      } else if (role == 'POSTER') {
        await _fetchEmployerData();
      }
      debugPrint('Fresh profile data loaded successfully');
    } catch (e) {
      debugPrint('Error fetching fresh data: $e');
    }
  }

  Future<void> _fetchJobSeekerData() async {
    if (userId == null) return;
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
    final skillData = await supabase
        .from('skills')
        .select()
        .eq('user_id', userId!)
        .order('skill_name', ascending: true);
    if (mounted) {
      setState(() => skills = List<Map<String, dynamic>>.from(skillData));
      await LocalDB.cacheSkills(userId!, skills);
    }
    final eduData = await supabase
        .from('education')
        .select()
        .eq('user_id', userId!)
        .order('start_date', ascending: false);
    if (mounted) {
      setState(() => educationList = List<Map<String, dynamic>>.from(eduData));
      await LocalDB.cacheEducation(userId!, educationList);
    }
    final workData = await supabase
        .from('experience')
        .select()
        .eq('user_id', userId!)
        .order('start_date', ascending: false);
    if (mounted) {
      setState(() => workList = List<Map<String, dynamic>>.from(workData));
      await LocalDB.cacheExperience(userId!, workList);
    }
  }

  Future<void> _fetchEmployerData() async {
    if (userId == null) return;
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
        profileImageUrl = profile['logo_url'] ?? '';
        _companyId = profile['company_id'];
      });
      await LocalDB.cacheCompanyProfile(userId!, profile);
    }
    if (_companyId != null) {
      final branchesData = await supabase
          .from('company_branch')
          .select()
          .eq('company_id', _companyId!)
          .order('is_head_office', ascending: false)
          .order('branch_name', ascending: true);
      if (mounted) {
        setState(() => branches = List<Map<String, dynamic>>.from(branchesData));
        await LocalDB.cacheBranches(_companyId!, branches);
      }
    }
  }

  /// Load data from local SQLite cache only
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
        await _loadJobSeekerCache();
      } else if (role == 'POSTER') {
        await _loadEmployerCache();
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    }
  }

  Future<void> _loadJobSeekerCache() async {
    if (userId == null) return;
    final cachedSkills = await LocalDB.getCachedSkills(userId!);
    final cachedEducation = await LocalDB.getCachedEducation(userId!);
    final cachedExperience = await LocalDB.getCachedExperience(userId!);
    if (mounted) {
      setState(() {
        skills = List<Map<String, dynamic>>.from(cachedSkills);
        educationList = List<Map<String, dynamic>>.from(cachedEducation);
        workList = List<Map<String, dynamic>>.from(cachedExperience);
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
  }

  Future<void> _loadEmployerCache() async {
    if (userId == null) return;
    final cachedProfile = await LocalDB.getCachedCompanyProfile(userId!);
    if (cachedProfile != null && mounted) {
      setState(() {
        companyName = cachedProfile['company_name'] ?? '';
        companyDescription = cachedProfile['company_description'] ?? '';
        industry = cachedProfile['industry'] ?? '';
        companySize = cachedProfile['company_size'] ?? '';
        profileImageUrl = cachedProfile['logo_url'] ?? '';
        _companyId = cachedProfile['company_id'];
      });
    }
    if (_companyId != null) {
      final cachedBranches = await LocalDB.getCachedBranches(_companyId!);
      if (mounted) {
        setState(() => branches = List<Map<String, dynamic>>.from(cachedBranches));
      }
    }
  }

  /// Refresh profile data
  Future<void> _refreshProfile() async {
    if (!mounted) return;
    setState(() => isRefreshing = true);
    await _fetchFreshData();
    await _loadJobCategories();
    if (mounted) setState(() => isRefreshing = false);
  }

  // Upload profile image
  Future<void> _uploadProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null && mounted && userId != null) {
        setState(() => isLoading = true);
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'profile_${userId!}_$timestamp.jpg';
        final storagePath = 'profile-images/$fileName';
        await supabase.storage.from('avatars').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
        final publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);
        await _userRepo.updateUser(userId!, {'profile_image_url': publicUrl});
        setState(() => profileImageUrl = publicUrl);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.updateProfileImage(publicUrl);
        await LocalDB.clearUserCache(userId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile image updated successfully!"), backgroundColor: Colors.green),
          );
        }
        await _refreshProfile();
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading image: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Upload company logo
  Future<void> _uploadCompanyLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null && mounted && userId != null) {
        setState(() => isLoading = true);
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'logo_${userId!}_$timestamp.jpg';
        final storagePath = 'company-logos/$fileName';
        await supabase.storage.from('company-logos').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
        final publicUrl = supabase.storage.from('company-logos').getPublicUrl(storagePath);
        await supabase
            .from('company_profile')
            .update({'logo_url': publicUrl})
            .eq('user_id', userId!);
        setState(() => profileImageUrl = publicUrl);
        await LocalDB.clearUserCache(userId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Company logo updated successfully!"), backgroundColor: Colors.green),
          );
        }
        await _refreshProfile();
      }
    } catch (e) {
      debugPrint('Error uploading logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading logo: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Branch Methods
  void _showAddBranchBottomSheet() {
    showAddBranchBottomSheet(
      context: context,
      branches: branches,
      companyId: _companyId,
      isValidPhone: _isValidPhone,
      isValidEmail: _isValidEmail,
      buildFormField: _buildFormField,
      inputDecoration: _inputDecoration,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
    );
  }

  void _showEditBranchBottomSheet(Map<String, dynamic> branch) {
    showEditBranchBottomSheet(
      context: context,
      branch: branch,
      branches: branches,
      isValidPhone: _isValidPhone,
      isValidEmail: _isValidEmail,
      buildFormField: _buildFormField,
      inputDecoration: _inputDecoration,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
    );
  }

  // Skills Methods
  void _showAddSkillBottomSheet() {
    showAddSkillBottomSheet(
      context: context,
      userId: userId,
      buildFormField: _buildFormField,
      inputDecoration: _inputDecoration,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
    );
  }

  void _showEditSkillBottomSheet(Map<String, dynamic> skill) {
    showEditSkillBottomSheet(
      context: context,
      skill: skill,
      userId: userId,
      buildFormField: _buildFormField,
      inputDecoration: _inputDecoration,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
    );
  }

  // Education Methods
  void _showAddEducationBottomSheet() {
    showAddEducationBottomSheet(
      context: context,
      userId: userId,
      isValidDateFormat: _isValidDateFormat,
      buildFormField: _buildFormField,
      inputDecoration: _inputDecoration,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
    );
  }

  void _showEditEducationBottomSheet(Map<String, dynamic> education) {
    showEditEducationBottomSheet(
      context: context,
      education: education,
      userId: userId,
      isValidDateFormat: _isValidDateFormat,
      buildFormField: _buildFormField,
      inputDecoration: _inputDecoration,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
    );
  }

  // Work Methods
  void _showAddWorkBottomSheet() {
    showAddWorkBottomSheet(
      context: context,
      userId: userId,
      isValidDateFormat: _isValidDateFormat,
      buildFormField: _buildFormField,
      inputDecoration: _inputDecoration,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
    );
  }

  void _showEditWorkBottomSheet(Map<String, dynamic> work) {
    showEditWorkBottomSheet(
      context: context,
      work: work,
      userId: userId,
      isValidDateFormat: _isValidDateFormat,
      buildFormField: _buildFormField,
      inputDecoration: _inputDecoration,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
    );
  }

  // Edit company details
  void _showEditCompanyInfoBottomSheet() {
    showEditCompanyInfoBottomSheet(
      context: context,
      companyName: companyName,
      industry: industry,
      companySize: companySize,
      jobCategories: _jobCategories,
      companySizeOptions: companySizeOptions,
      userId: userId,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
      inputDecoration: _inputDecoration,
      buildFormField: _buildFormField,
    );
  }

  void _showEditCompanyDescriptionBottomSheet() {
    showEditCompanyDescriptionBottomSheet(
      context: context,
      companyDescription: companyDescription,
      userId: userId,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
      buildFormField: _buildFormField,
    );
  }

  void _showEditPersonalInfoBottomSheet() {
    showEditPersonalInfoBottomSheet(
      context: context,
      fullname: fullname,
      phone: phone,
      dateOfBirth: dateOfBirth,
      address: address,
      bio: bio,
      gender: gender,
      role: role,
      userId: userId,
      onRefresh: _refreshProfile,
      userRepo: _userRepo,
      buildFormField: _buildFormField,
      buildDropdownField: _buildDropdownField,
    );
  }

  /// Delete methods
  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    await deleteBranch(context: context, branch: branch, userRepo: _userRepo, onRefresh: _refreshProfile);
  }

  Future<void> _deleteSkill(Map<String, dynamic> skill) async {
    await deleteSkill(context: context, skill: skill, userRepo: _userRepo, onRefresh: _refreshProfile);
  }

  Future<void> _deleteEducation(Map<String, dynamic> education) async {
    await deleteEducation(context: context, education: education, userRepo: _userRepo, onRefresh: _refreshProfile);
  }

  Future<void> _deleteWork(Map<String, dynamic> work) async {
    await deleteWork(context: context, work: work, userRepo: _userRepo, onRefresh: _refreshProfile);
  }

  // Form
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    String? hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value?.isEmpty == true ? null : value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isJobSeeker = role == 'JOB_SEEKER';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileHeader(
                isJobSeeker: isJobSeeker,
                profileImageUrl: profileImageUrl,
                fullname: fullname,
                companyName: companyName,
                userEmail: userEmail,
                role: role,
                onImageTap: isJobSeeker ? _uploadProfileImage : _uploadCompanyLogo,
              ),
              if (!isJobSeeker) ...[
                const SizedBox(height: 20),
                CompanyInfoCard(
                  companyName: companyName,
                  industry: industry,
                  companySize: companySize,
                  onEdit: _showEditCompanyInfoBottomSheet,
                ),
                const SizedBox(height: 15),
                BranchesCard(
                  branches: branches,
                  onAdd: _showAddBranchBottomSheet,
                  onEdit: _showEditBranchBottomSheet,
                  onDelete: _deleteBranch,
                ),
                const SizedBox(height: 15),
                CompanyDescriptionCard(
                  companyDescription: companyDescription,
                  onEdit: _showEditCompanyDescriptionBottomSheet,
                ),
              ],
              if (isJobSeeker) ...[
                const SizedBox(height: 15),
                PersonalInfoCard(
                  isJobSeeker: isJobSeeker,
                  fullname: fullname,
                  phone: phone,
                  userEmail: userEmail,
                  dateOfBirth: dateOfBirth,
                  gender: gender,
                  address: address,
                  bio: bio,
                  profileImageUrl: profileImageUrl,
                  onEdit: _showEditPersonalInfoBottomSheet,
                ),
                const SizedBox(height: 15),
                SkillsCard(
                  skills: skills,
                  onAdd: _showAddSkillBottomSheet,
                  onEdit: _showEditSkillBottomSheet,
                  onDelete: _deleteSkill,
                ),
                const SizedBox(height: 15),
                EducationCard(
                  educationList: educationList,
                  onAdd: _showAddEducationBottomSheet,
                  onEdit: _showEditEducationBottomSheet,
                  onDelete: _deleteEducation,
                ),
                const SizedBox(height: 15),
                WorkCard(
                  workList: workList,
                  onAdd: _showAddWorkBottomSheet,
                  onEdit: _showEditWorkBottomSheet,
                  onDelete: _deleteWork,
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}