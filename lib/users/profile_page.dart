import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jobify/users/user_provider.dart';
import 'package:jobify/users/users.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jobify/main.dart';
import 'package:jobify/data/user_repository.dart';
import 'package:jobify/data/local_db.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/data/job_repository.dart';

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

  /// Job categories for industry dropdown
  List<Map<String, dynamic>> _jobCategories = [];
  bool _isLoadingCategories = false;

  bool isLoading = true;
  bool isRefreshing = false;
  bool isEditingAbout = false;
  final TextEditingController _aboutController = TextEditingController();

  // Company size options (still hardcoded as these are standard)
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

  Future<void> _loadJobCategories() async {
    if (_jobCategories.isNotEmpty) return;

    setState(() => _isLoadingCategories = true);
    try {
      final jobRepo = JobRepository();
      final categories = await jobRepo.fetchJobCategories();
      if (mounted) {
        setState(() {
          _jobCategories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading job categories: $e');
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
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

      // Load job categories for industry dropdown
      await _loadJobCategories();

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
            profileImageUrl = profile['logo_url'] ?? '';
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
      } else if (role == 'POSTER') {
        final cachedProfile = await LocalDB.getCachedCompanyProfile(userId!);
        if (cachedProfile != null && mounted) {
          setState(() {
            companyName = cachedProfile['company_name'] ?? '';
            companyDescription = cachedProfile['company_description'] ?? '';
            industry = cachedProfile['industry'] ?? '';
            companySize = cachedProfile['company_size'] ?? '';
            location = cachedProfile['location'] ?? '';
            profileImageUrl = cachedProfile['logo_url'] ?? '';
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
    await _loadJobCategories();
    if (mounted) setState(() => isRefreshing = false);
  }

  // ==================== PROFILE IMAGE UPLOAD ====================
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
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );

        final publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);

        await _userRepo.updateUser(userId!, {
          'profile_image_url': publicUrl,
        });

        setState(() {
          profileImageUrl = publicUrl;
        });

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.updateProfileImage(publicUrl);

        await LocalDB.clearUserCache(userId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile image updated successfully!")),
          );
        }

        await _refreshProfile();
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading image: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
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
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );

        final publicUrl = supabase.storage.from('company-logos').getPublicUrl(storagePath);

        await supabase
            .from('company_profile')
            .update({'logo_url': publicUrl})
            .eq('user_id', userId!);

        setState(() {
          profileImageUrl = publicUrl;
        });

        await LocalDB.clearUserCache(userId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Company logo updated successfully!")),
          );
          Navigator.pop(context, true);
        }

        await _refreshProfile();
      }
    } catch (e) {
      debugPrint('Error uploading logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading logo: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ==================== COMPANY INFO EDIT ====================
  void _showEditCompanyInfoBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) {
            String selectedIndustry = industry;
            String selectedCompanySize = companySize;
            TextEditingController companyNameCtrl = TextEditingController(text: companyName);
            TextEditingController locationCtrl = TextEditingController(text: location);
            bool isSaving = false;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Edit Company Information',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(
                            label: 'Company Name',
                            controller: companyNameCtrl,
                            icon: Icons.business_outlined,
                          ),
                          const SizedBox(height: 16),

                          // Industry dropdown - Using job categories
                          if (_jobCategories.isEmpty && _isLoadingCategories)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: selectedIndustry.isNotEmpty ? selectedIndustry : null,
                              decoration: _inputDecoration('Industry', icon: Icons.category_outlined),
                              items: _jobCategories.map<DropdownMenuItem<String>>((category) {
                                return DropdownMenuItem<String>(
                                  value: category['name'].toString(),
                                  child: Text(category['name'].toString()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setStateBottom(() {
                                  selectedIndustry = value!;
                                });
                              },
                            ),

                          const SizedBox(height: 16),

                          // Company Size dropdown
                          DropdownButtonFormField<String>(
                            value: selectedCompanySize.isNotEmpty ? selectedCompanySize : null,
                            decoration: _inputDecoration('Company Size', icon: Icons.people_outline),
                            items: companySizeOptions.map((size) {
                              return DropdownMenuItem(
                                value: size,
                                child: Text(size),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setStateBottom(() {
                                selectedCompanySize = value!;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          _buildFormField(
                            label: 'Location',
                            controller: locationCtrl,
                            icon: Icons.location_on_outlined,
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                setStateBottom(() => isSaving = true);

                                // Update company name
                                if (companyNameCtrl.text.trim() != companyName) {
                                  await _userRepo.updateCompanyProfile(userId!, {
                                    'company_name': companyNameCtrl.text.trim(),
                                  });
                                }

                                // Update industry
                                if (selectedIndustry != industry) {
                                  await _userRepo.updateCompanyProfile(userId!, {
                                    'industry': selectedIndustry,
                                  });
                                }

                                // Update company size
                                if (selectedCompanySize != companySize) {
                                  await _userRepo.updateCompanyProfile(userId!, {
                                    'company_size': selectedCompanySize,
                                  });
                                }

                                // Update location
                                if (locationCtrl.text.trim() != location) {
                                  await _userRepo.updateCompanyProfile(userId!, {
                                    'location': locationCtrl.text.trim(),
                                  });
                                }

                                await _refreshProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Company information updated!")),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==================== COMPANY DESCRIPTION EDIT ====================
  void _showEditCompanyDescriptionBottomSheet() {
    final TextEditingController descCtrl = TextEditingController(text: companyDescription);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Edit Company Description',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(
                            label: 'Company Description',
                            controller: descCtrl,
                            icon: Icons.description_outlined,
                            maxLines: 8,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () async {
                                await _userRepo.updateCompanyProfile(userId!, {
                                  'company_description': descCtrl.text.trim(),
                                });
                                await _refreshProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Company description updated!")),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Save Description',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==================== PERSONAL INFO EDIT ====================
  void _showEditPersonalInfoBottomSheet() {
    final TextEditingController fullnameCtrl = TextEditingController(text: fullname);
    final TextEditingController phoneCtrl = TextEditingController(text: phone);
    final TextEditingController dobCtrl = TextEditingController(text: dateOfBirth);
    final TextEditingController addressCtrl = TextEditingController(text: address);
    final TextEditingController bioCtrl = TextEditingController(text: bio);
    String selectedGender = gender;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Edit Personal Information',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(
                            label: 'Full Name',
                            controller: fullnameCtrl,
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Phone Number',
                            controller: phoneCtrl,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          if (role == 'JOB_SEEKER') ...[
                            const SizedBox(height: 16),
                            _buildFormField(
                              label: 'Date of Birth',
                              controller: dobCtrl,
                              icon: Icons.cake_outlined,
                              hintText: 'YYYY-MM-DD',
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              label: 'Gender',
                              value: selectedGender,
                              items: const ['Male', 'Female'],
                              onChanged: (value) {
                                setStateBottom(() {
                                  selectedGender = value!;
                                });
                              },
                              icon: Icons.people_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              label: 'Address',
                              controller: addressCtrl,
                              icon: Icons.location_on_outlined,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              label: 'Bio',
                              controller: bioCtrl,
                              icon: Icons.description_outlined,
                              maxLines: 3,
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                setStateBottom(() => isSaving = true);
                                await _userRepo.updateUser(userId!, {
                                  'fullname': fullnameCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                });
                                if (role == 'JOB_SEEKER') {
                                  await _userRepo.updateJobSeekerProfile(userId!, {
                                    'date_of_birth': dobCtrl.text.isEmpty ? null : dobCtrl.text,
                                    'gender': selectedGender,
                                    'address': addressCtrl.text,
                                    'bio': bioCtrl.text,
                                  });
                                }
                                await _refreshProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Profile updated successfully!")),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==================== SKILL METHODS ====================
  void _showAddSkillBottomSheet() {
    final TextEditingController skillNameCtrl = TextEditingController();
    String? selectedLevel;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.8,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Add Skill',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(
                            label: 'Skill Name',
                            controller: skillNameCtrl,
                            icon: Icons.code_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            label: 'Skill Level',
                            value: selectedLevel,
                            items: const ['Beginner', 'Intermediate', 'Advanced'],
                            onChanged: (value) {
                              setStateBottom(() {
                                selectedLevel = value;
                              });
                            },
                            icon: Icons.trending_up_outlined,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                if (skillNameCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please enter skill name")),
                                  );
                                  return;
                                }
                                setStateBottom(() => isSaving = true);
                                await _userRepo.addSkill(userId!, skillNameCtrl.text.trim(), selectedLevel);
                                await _refreshProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Skill added")),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                'Add Skill',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditSkillBottomSheet(Map<String, dynamic> skill) {
    final TextEditingController skillNameCtrl = TextEditingController(text: skill['skill_name']);
    String? selectedLevel = skill['skill_level'];
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.8,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Edit Skill',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(
                            label: 'Skill Name',
                            controller: skillNameCtrl,
                            icon: Icons.code_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            label: 'Skill Level',
                            value: selectedLevel,
                            items: const ['Beginner', 'Intermediate', 'Advanced'],
                            onChanged: (value) {
                              setStateBottom(() {
                                selectedLevel = value;
                              });
                            },
                            icon: Icons.trending_up_outlined,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                setStateBottom(() => isSaving = true);
                                await _userRepo.updateSkill(skill['skill_id'], skillNameCtrl.text.trim(), selectedLevel);
                                await _refreshProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Skill updated")),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                'Update Skill',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
    final TextEditingController institutionCtrl = TextEditingController();
    final TextEditingController qualificationCtrl = TextEditingController();
    final TextEditingController fieldCtrl = TextEditingController();
    final TextEditingController startDateCtrl = TextEditingController();
    final TextEditingController endDateCtrl = TextEditingController();
    final TextEditingController descriptionCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Add Education',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(
                            label: 'Institution Name',
                            controller: institutionCtrl,
                            icon: Icons.school_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Qualification',
                            controller: qualificationCtrl,
                            icon: Icons.verified_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Field of Study',
                            controller: fieldCtrl,
                            icon: Icons.category_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Start Date',
                            controller: startDateCtrl,
                            icon: Icons.calendar_today_outlined,
                            hintText: 'YYYY-MM-DD',
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'End Date',
                            controller: endDateCtrl,
                            icon: Icons.calendar_today_outlined,
                            hintText: 'YYYY-MM-DD (Leave empty if current)',
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Description',
                            controller: descriptionCtrl,
                            icon: Icons.description_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                setStateBottom(() => isSaving = true);
                                await _userRepo.addEducation(userId!, {
                                  'institution_name': institutionCtrl.text.trim(),
                                  'qualification': qualificationCtrl.text.trim(),
                                  'field_of_study': fieldCtrl.text.trim(),
                                  'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
                                  'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
                                  'description': descriptionCtrl.text.trim(),
                                });
                                await _refreshProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Education added")),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                'Add Education',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditEducationBottomSheet(Map<String, dynamic> education) {
    final TextEditingController institutionCtrl = TextEditingController(text: education['institution_name'] ?? '');
    final TextEditingController qualificationCtrl = TextEditingController(text: education['qualification'] ?? '');
    final TextEditingController fieldCtrl = TextEditingController(text: education['field_of_study'] ?? '');
    final TextEditingController startDateCtrl = TextEditingController(text: education['start_date'] ?? '');
    final TextEditingController endDateCtrl = TextEditingController(text: education['end_date'] ?? '');
    final TextEditingController descriptionCtrl = TextEditingController(text: education['description'] ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Edit Education',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(
                            label: 'Institution Name',
                            controller: institutionCtrl,
                            icon: Icons.school_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Qualification',
                            controller: qualificationCtrl,
                            icon: Icons.verified_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Field of Study',
                            controller: fieldCtrl,
                            icon: Icons.category_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Start Date',
                            controller: startDateCtrl,
                            icon: Icons.calendar_today_outlined,
                            hintText: 'YYYY-MM-DD',
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'End Date',
                            controller: endDateCtrl,
                            icon: Icons.calendar_today_outlined,
                            hintText: 'YYYY-MM-DD (Leave empty if current)',
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Description',
                            controller: descriptionCtrl,
                            icon: Icons.description_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                setStateBottom(() => isSaving = true);
                                await _userRepo.updateEducation(education['education_id'], {
                                  'institution_name': institutionCtrl.text.trim(),
                                  'qualification': qualificationCtrl.text.trim(),
                                  'field_of_study': fieldCtrl.text.trim(),
                                  'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
                                  'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
                                  'description': descriptionCtrl.text.trim(),
                                });
                                await _refreshProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Education updated")),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                'Update Education',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
    final TextEditingController companyCtrl = TextEditingController();
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController startDateCtrl = TextEditingController();
    final TextEditingController endDateCtrl = TextEditingController();
    final TextEditingController descriptionCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Add Work Experience',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(
                            label: 'Company Name',
                            controller: companyCtrl,
                            icon: Icons.business_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Job Title',
                            controller: titleCtrl,
                            icon: Icons.work_outline,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Start Date',
                            controller: startDateCtrl,
                            icon: Icons.calendar_today_outlined,
                            hintText: 'YYYY-MM-DD',
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'End Date',
                            controller: endDateCtrl,
                            icon: Icons.calendar_today_outlined,
                            hintText: 'YYYY-MM-DD (Leave empty if current)',
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Description',
                            controller: descriptionCtrl,
                            icon: Icons.description_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                setStateBottom(() => isSaving = true);
                                await _userRepo.addExperience(userId!, {
                                  'company_name': companyCtrl.text.trim(),
                                  'job_title': titleCtrl.text.trim(),
                                  'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
                                  'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
                                  'description': descriptionCtrl.text.trim(),
                                });
                                await _refreshProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Work experience added")),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                'Add Experience',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditWorkBottomSheet(Map<String, dynamic> work) {
    final TextEditingController companyCtrl = TextEditingController(text: work['company_name'] ?? '');
    final TextEditingController titleCtrl = TextEditingController(text: work['job_title'] ?? '');
    final TextEditingController startDateCtrl = TextEditingController(text: work['start_date'] ?? '');
    final TextEditingController endDateCtrl = TextEditingController(text: work['end_date'] ?? '');
    final TextEditingController descriptionCtrl = TextEditingController(text: work['description'] ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Edit Work Experience',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(
                            label: 'Company Name',
                            controller: companyCtrl,
                            icon: Icons.business_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Job Title',
                            controller: titleCtrl,
                            icon: Icons.work_outline,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Start Date',
                            controller: startDateCtrl,
                            icon: Icons.calendar_today_outlined,
                            hintText: 'YYYY-MM-DD',
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'End Date',
                            controller: endDateCtrl,
                            icon: Icons.calendar_today_outlined,
                            hintText: 'YYYY-MM-DD (Leave empty if current)',
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Description',
                            controller: descriptionCtrl,
                            icon: Icons.description_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                setStateBottom(() => isSaving = true);
                                await _userRepo.updateExperience(work['experience_id'], {
                                  'company_name': companyCtrl.text.trim(),
                                  'job_title': titleCtrl.text.trim(),
                                  'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
                                  'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
                                  'description': descriptionCtrl.text.trim(),
                                });
                                await _refreshProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Work experience updated")),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                'Update Experience',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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

  // ==================== HELPER FORM WIDGETS ====================

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    String? hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              // PROFILE PHOTO SECTION
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
              ],

              const SizedBox(height: 20),
            ],
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
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                child: profileImageUrl.isNotEmpty
                    ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: profileImageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => Icon(
                      isJobSeeker ? Icons.person : Icons.business,
                      size: 50,
                      color: Colors.blue,
                    ),
                  ),
                )
                    : Icon(
                  isJobSeeker ? Icons.person : Icons.business,
                  size: 50,
                  color: Colors.blue,
                ),
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