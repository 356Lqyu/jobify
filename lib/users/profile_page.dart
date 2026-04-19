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
import 'package:jobify/job_post/job_post_service.dart';
import 'package:jobify/data/location_service.dart';

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
  String? _companyId;
  String location = '';
  String companyPhone = '';
  String companyEmail = '';
  String websiteUrl = '';

  /// Branches
  List<Map<String, dynamic>> branches = [];

  /// Skills
  List<Map<String, dynamic>> skills = [];

  /// Education
  List<Map<String, dynamic>> educationList = [];

  /// Work Experience
  List<Map<String, dynamic>> workList = [];

  /// Resumes
  List<Map<String, dynamic>> resumes = [];

  /// Job categories for industry dropdown
  List<Map<String, dynamic>> _jobCategories = [];
  bool _isLoadingCategories = false;

  bool isLoading = true;
  bool isRefreshing = false;

  // Industry options (from first file, with dynamic categories as fallback)
  final List<String> fallbackIndustryOptions = [
    'Technology', 'Healthcare', 'Finance', 'Marketing', 'Retail',
    'Manufacturing', 'Education', 'Construction', 'Hospitality', 'Transportation',
    'Real Estate', 'Consulting', 'Legal', 'Entertainment', 'Agriculture',
    'Energy', 'Telecommunications', 'Other'
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
    super.dispose();
  }

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

        // Fetch resumes
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

        final skillData = await supabase
            .from('skills')
            .select()
            .eq('user_id', userId!)
            .order('skill_name', ascending: true);
        if (mounted) {
          setState(() {
            skills = List<Map<String, dynamic>>.from(skillData);
          });
          await LocalDB.cacheSkills(userId!, skills);
        }

        final eduData = await supabase
            .from('education')
            .select()
            .eq('user_id', userId!)
            .order('start_date', ascending: false);
        if (mounted) {
          setState(() {
            educationList = List<Map<String, dynamic>>.from(eduData);
          });
          await LocalDB.cacheEducation(userId!, educationList);
        }

        final workData = await supabase
            .from('experience')
            .select()
            .eq('user_id', userId!)
            .order('start_date', ascending: false);
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
            _companyId = profile['company_id'];
          });
          await LocalDB.cacheCompanyProfile(userId!, profile);
        }

        // Fetch branches
        if (_companyId != null) {
          final branchesData = await supabase
              .from('company_branch')
              .select()
              .eq('company_id', _companyId!)
              .order('is_head_office', ascending: false)
              .order('branch_name', ascending: true);
          if (mounted) {
            setState(() {
              branches = List<Map<String, dynamic>>.from(branchesData);
            });
            await LocalDB.cacheBranches(_companyId!, branches);
          }
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
            profileImageUrl = cachedProfile['logo_url'] ?? '';
            _companyId = cachedProfile['company_id'];
          });
        }

        if (_companyId != null) {
          final cachedBranches = await LocalDB.getCachedBranches(_companyId!);
          if (mounted) {
            setState(() {
              branches = List<Map<String, dynamic>>.from(cachedBranches);
            });
          }
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
        final bytes = file.bytes;
        final fileName = file.name;

        if (bytes != null) {
          setState(() => isLoading = true);

          final storagePath = 'resumes/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

          await supabase.storage.from('resumes').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

          final publicUrl = supabase.storage.from('resumes').getPublicUrl(storagePath);

          await _userRepo.addResume(userId!, publicUrl, fileName);
          await _refreshProfile();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Resume uploaded successfully!"), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading resume: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
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
                    const SnackBar(content: Text("Resume deleted"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error deleting resume: ${e.toString()}"), backgroundColor: Colors.red),
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

  Future<void> _downloadResume(Map<String, dynamic> resume) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Opening: ${resume['file_name']}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening resume: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  // ==================== COMPANY INFO EDIT ====================
  void _showEditCompanyInfoBottomSheet() {
    final TextEditingController companyNameCtrl = TextEditingController(text: companyName);
    final TextEditingController locationCtrl = TextEditingController(text: location);
    String tempIndustry = industry;
    String tempCompanySize = companySize;
    bool isSaving = false;

    final industryList = _jobCategories.isNotEmpty
        ? _jobCategories.map((c) => c['name'].toString()).toList()
        : fallbackIndustryOptions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBottom) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _buildHandleBar(),
                  _buildSheetHeader('Edit Company Information', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Company Name', controller: companyNameCtrl, icon: Icons.business_outlined),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            label: 'Industry',
                            value: tempIndustry.isNotEmpty ? tempIndustry : null,
                            items: industryList,
                            onChanged: (value) => setStateBottom(() => tempIndustry = value!),
                            icon: Icons.category_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            label: 'Company Size',
                            value: tempCompanySize.isNotEmpty ? tempCompanySize : null,
                            items: companySizeOptions,
                            onChanged: (value) => setStateBottom(() => tempCompanySize = value!),
                            icon: Icons.people_outline,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Location', controller: locationCtrl, icon: Icons.location_on_outlined),
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
                              setStateBottom(() => isSaving = true);
                              try {
                                final updates = <String, dynamic>{};
                                if (companyNameCtrl.text.trim() != companyName) {
                                  updates['company_name'] = companyNameCtrl.text.trim();
                                }
                                if (tempIndustry != industry) {
                                  updates['industry'] = tempIndustry;
                                }
                                if (tempCompanySize != companySize) {
                                  updates['company_size'] = tempCompanySize;
                                }
                                if (locationCtrl.text.trim() != location) {
                                  updates['location'] = locationCtrl.text.trim();
                                }
                                if (updates.isNotEmpty) {
                                  await _userRepo.updateCompanyProfile(userId!, updates);
                                }
                                await _refreshProfile();
                                _showSuccessSnackBar("Company information updated!");
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                _showErrorSnackBar(e.toString());
                              } finally {
                                setStateBottom(() => isSaving = false);
                              }
                            },
                            label: 'Save Changes',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHandleBar(),
              _buildSheetHeader('Edit Company Description', () => Navigator.pop(context)),
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
                      _buildSaveButton(
                        isSaving: false,
                        onSave: () async {
                          await _userRepo.updateCompanyProfile(userId!, {
                            'company_description': descCtrl.text.trim(),
                          });
                          await _refreshProfile();
                          _showSuccessSnackBar("Company description updated!");
                          if (mounted) Navigator.pop(context);
                        },
                        label: 'Save Description',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BRANCH METHODS ====================
  void _showAddBranchBottomSheet() {
    final TextEditingController branchNameCtrl = TextEditingController();
    final TextEditingController addressCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    bool isHeadOffice = false;
    bool isSaving = false;

    String selectedCountry = 'Malaysia';
    String selectedState = '';
    String? selectedCity;
    String selectedPostalCode = '';

    bool hasExistingHeadOffice = branches.any((b) => b['is_head_office'] == true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBottom) {
          List<String> availableCities = [];
          bool hasCities = false;
          if (selectedState.isNotEmpty) {
            availableCities = LocationService.getCitiesForState(selectedState);
            hasCities = availableCities.isNotEmpty;
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.96,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _buildHandleBar(),
                  _buildSheetHeader('Add Branch', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Branch Name *', controller: branchNameCtrl, icon: Icons.business_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Street Address *', controller: addressCtrl, icon: Icons.location_on_outlined, maxLines: 2),
                          const SizedBox(height: 16),
                          StateCitySelector(
                            initialCountry: selectedCountry,
                            initialState: selectedState,
                            initialCity: selectedCity,
                            onSelected: (country, state, city, postalCode) {
                              setStateBottom(() {
                                selectedCountry = country;
                                selectedState = state;
                                selectedCity = city;
                                selectedPostalCode = postalCode;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Phone', controller: phoneCtrl, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Email', controller: emailCtrl, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: isHeadOffice,
                                onChanged: (value) {
                                  if (value == true && hasExistingHeadOffice) {
                                    _showHeadOfficeWarningDialog(context, () {
                                      setStateBottom(() => isHeadOffice = true);
                                    });
                                  } else {
                                    setStateBottom(() => isHeadOffice = value ?? false);
                                  }
                                },
                              ),
                              const Text('This is the head office'),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
                              if (branchNameCtrl.text.trim().isEmpty) {
                                _showErrorSnackBar("Please enter branch name");
                                return;
                              }
                              if (addressCtrl.text.trim().isEmpty) {
                                _showErrorSnackBar("Please enter street address");
                                return;
                              }
                              if (selectedState.isEmpty) {
                                _showErrorSnackBar("Please select a state");
                                return;
                              }
                              if (hasCities && (selectedCity == null || selectedCity!.isEmpty)) {
                                _showErrorSnackBar("Please select a city from the list");
                                return;
                              }

                              setStateBottom(() => isSaving = true);
                              try {
                                final branchData = {
                                  'branch_name': branchNameCtrl.text.trim(),
                                  'address': addressCtrl.text.trim(),
                                  'city': selectedCity ?? (hasCities ? null : 'N/A'),
                                  'state': selectedState,
                                  'postal_code': selectedPostalCode.isNotEmpty ? selectedPostalCode : null,
                                  'country': selectedCountry,
                                  'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                  'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                  'is_head_office': isHeadOffice,
                                };

                                await _userRepo.addBranch(_companyId!, branchData);
                                await _refreshProfile();
                                _showSuccessSnackBar("Branch added successfully!");
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                _showErrorSnackBar(e.toString());
                              } finally {
                                setStateBottom(() => isSaving = false);
                              }
                            },
                            label: 'Add Branch',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditBranchBottomSheet(Map<String, dynamic> branch) {
    final TextEditingController branchNameCtrl = TextEditingController(text: branch['branch_name']);
    final TextEditingController addressCtrl = TextEditingController(text: branch['address']);
    final TextEditingController phoneCtrl = TextEditingController(text: branch['phone'] ?? '');
    final TextEditingController emailCtrl = TextEditingController(text: branch['email'] ?? '');
    bool isHeadOffice = branch['is_head_office'] == true;
    bool isSaving = false;

    String selectedCountry = branch['country'] ?? 'Malaysia';
    String selectedState = branch['state'] ?? '';
    String? selectedCity = branch['city'];
    String selectedPostalCode = branch['postal_code'] ?? '';

    if (selectedCity == '') selectedCity = null;

    bool hasExistingHeadOffice = branches.any((b) =>
    b['branch_id'] != branch['branch_id'] && b['is_head_office'] == true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBottom) {
          List<String> availableCities = [];
          bool hasCities = false;
          if (selectedState.isNotEmpty) {
            availableCities = LocationService.getCitiesForState(selectedState);
            hasCities = availableCities.isNotEmpty;
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.96,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _buildHandleBar(),
                  _buildSheetHeader('Edit Branch', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Branch Name *', controller: branchNameCtrl, icon: Icons.business_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Street Address *', controller: addressCtrl, icon: Icons.location_on_outlined, maxLines: 2),
                          const SizedBox(height: 16),
                          StateCitySelector(
                            initialCountry: selectedCountry,
                            initialState: selectedState,
                            initialCity: selectedCity,
                            onSelected: (country, state, city, postalCode) {
                              setStateBottom(() {
                                selectedCountry = country;
                                selectedState = state;
                                selectedCity = city;
                                selectedPostalCode = postalCode;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Phone', controller: phoneCtrl, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Email', controller: emailCtrl, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: isHeadOffice,
                                onChanged: (value) {
                                  if (value == true && hasExistingHeadOffice) {
                                    _showHeadOfficeWarningDialog(context, () {
                                      setStateBottom(() => isHeadOffice = true);
                                    });
                                  } else {
                                    setStateBottom(() => isHeadOffice = value ?? false);
                                  }
                                },
                              ),
                              const Text('This is the head office'),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
                              if (branchNameCtrl.text.trim().isEmpty) {
                                _showErrorSnackBar("Please enter branch name");
                                return;
                              }
                              if (addressCtrl.text.trim().isEmpty) {
                                _showErrorSnackBar("Please enter street address");
                                return;
                              }
                              if (selectedState.isEmpty) {
                                _showErrorSnackBar("Please select a state");
                                return;
                              }
                              if (hasCities && (selectedCity == null || selectedCity!.isEmpty)) {
                                _showErrorSnackBar("Please select a city from the list");
                                return;
                              }

                              setStateBottom(() => isSaving = true);
                              try {
                                final branchData = {
                                  'branch_name': branchNameCtrl.text.trim(),
                                  'address': addressCtrl.text.trim(),
                                  'city': selectedCity ?? (hasCities ? null : 'N/A'),
                                  'state': selectedState,
                                  'postal_code': selectedPostalCode,
                                  'country': selectedCountry,
                                  'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                  'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                  'is_head_office': isHeadOffice,
                                };

                                await _userRepo.updateBranch(branch['branch_id'], branchData);
                                await _refreshProfile();
                                _showSuccessSnackBar("Branch updated successfully!");
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                _showErrorSnackBar(e.toString());
                              } finally {
                                setStateBottom(() => isSaving = false);
                              }
                            },
                            label: 'Update Branch',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Branch"),
        content: Text("Are you sure you want to delete '${branch['branch_name']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _userRepo.deleteBranch(branch['branch_id']);
              await _refreshProfile();
              _showSuccessSnackBar("Branch deleted successfully!");
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
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
                  _buildHandleBar(),
                  _buildSheetHeader('Edit Personal Information', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Full Name', controller: fullnameCtrl, icon: Icons.person_outline),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Phone Number', controller: phoneCtrl, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                          if (role == 'JOB_SEEKER') ...[
                            const SizedBox(height: 16),
                            _buildFormField(label: 'Date of Birth', controller: dobCtrl, icon: Icons.cake_outlined, hintText: 'YYYY-MM-DD'),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              label: 'Gender',
                              value: selectedGender.isNotEmpty ? selectedGender : null,
                              items: const ['Male', 'Female'],
                              onChanged: (value) => setStateBottom(() => selectedGender = value!),
                              icon: Icons.people_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(label: 'Address', controller: addressCtrl, icon: Icons.location_on_outlined, maxLines: 2),
                            const SizedBox(height: 16),
                            _buildFormField(label: 'Bio', controller: bioCtrl, icon: Icons.description_outlined, maxLines: 3),
                          ],
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
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
                              _showSuccessSnackBar("Profile updated successfully!");
                              if (mounted) Navigator.pop(context);
                            },
                            label: 'Save Changes',
                          ),
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
                  _buildHandleBar(),
                  _buildSheetHeader('Add Skill', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Skill Name', controller: skillNameCtrl, icon: Icons.code_outlined),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            label: 'Skill Level',
                            value: selectedLevel,
                            items: const ['Beginner', 'Intermediate', 'Advanced'],
                            onChanged: (value) => setStateBottom(() => selectedLevel = value),
                            icon: Icons.trending_up_outlined,
                          ),
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
                              if (skillNameCtrl.text.trim().isEmpty) {
                                _showErrorSnackBar("Please enter skill name");
                                return;
                              }
                              setStateBottom(() => isSaving = true);
                              await _userRepo.addSkill(userId!, skillNameCtrl.text.trim(), selectedLevel);
                              await _refreshProfile();
                              _showSuccessSnackBar("Skill added");
                              if (mounted) Navigator.pop(context);
                            },
                            label: 'Add Skill',
                          ),
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
                  _buildHandleBar(),
                  _buildSheetHeader('Edit Skill', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Skill Name', controller: skillNameCtrl, icon: Icons.code_outlined),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            label: 'Skill Level',
                            value: selectedLevel,
                            items: const ['Beginner', 'Intermediate', 'Advanced'],
                            onChanged: (value) => setStateBottom(() => selectedLevel = value),
                            icon: Icons.trending_up_outlined,
                          ),
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
                              setStateBottom(() => isSaving = true);
                              await _userRepo.updateSkill(skill['skill_id'], skillNameCtrl.text.trim(), selectedLevel);
                              await _refreshProfile();
                              _showSuccessSnackBar("Skill updated");
                              if (mounted) Navigator.pop(context);
                            },
                            label: 'Update Skill',
                          ),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _userRepo.deleteSkill(skill['skill_id']);
              await _refreshProfile();
              _showSuccessSnackBar("Skill deleted");
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
                  _buildHandleBar(),
                  _buildSheetHeader('Add Education', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Institution Name', controller: institutionCtrl, icon: Icons.school_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Qualification', controller: qualificationCtrl, icon: Icons.verified_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Field of Study', controller: fieldCtrl, icon: Icons.category_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Start Date', controller: startDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD'),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'End Date', controller: endDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD (Leave empty if current)'),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Description', controller: descriptionCtrl, icon: Icons.description_outlined, maxLines: 3),
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
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
                              _showSuccessSnackBar("Education added");
                              if (mounted) Navigator.pop(context);
                            },
                            label: 'Add Education',
                          ),
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
                  _buildHandleBar(),
                  _buildSheetHeader('Edit Education', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Institution Name', controller: institutionCtrl, icon: Icons.school_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Qualification', controller: qualificationCtrl, icon: Icons.verified_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Field of Study', controller: fieldCtrl, icon: Icons.category_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Start Date', controller: startDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD'),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'End Date', controller: endDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD (Leave empty if current)'),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Description', controller: descriptionCtrl, icon: Icons.description_outlined, maxLines: 3),
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
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
                              _showSuccessSnackBar("Education updated");
                              if (mounted) Navigator.pop(context);
                            },
                            label: 'Update Education',
                          ),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _userRepo.deleteEducation(education['education_id']);
              await _refreshProfile();
              _showSuccessSnackBar("Education deleted");
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
                  _buildHandleBar(),
                  _buildSheetHeader('Add Work Experience', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Company Name', controller: companyCtrl, icon: Icons.business_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Job Title', controller: titleCtrl, icon: Icons.work_outline),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Start Date', controller: startDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD'),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'End Date', controller: endDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD (Leave empty if current)'),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Description', controller: descriptionCtrl, icon: Icons.description_outlined, maxLines: 3),
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
                              setStateBottom(() => isSaving = true);
                              await _userRepo.addExperience(userId!, {
                                'company_name': companyCtrl.text.trim(),
                                'job_title': titleCtrl.text.trim(),
                                'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
                                'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
                                'description': descriptionCtrl.text.trim(),
                              });
                              await _refreshProfile();
                              _showSuccessSnackBar("Work experience added");
                              if (mounted) Navigator.pop(context);
                            },
                            label: 'Add Experience',
                          ),
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
                  _buildHandleBar(),
                  _buildSheetHeader('Edit Work Experience', () => Navigator.pop(context)),
                  const Divider(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormField(label: 'Company Name', controller: companyCtrl, icon: Icons.business_outlined),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Job Title', controller: titleCtrl, icon: Icons.work_outline),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Start Date', controller: startDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD'),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'End Date', controller: endDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD (Leave empty if current)'),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'Description', controller: descriptionCtrl, icon: Icons.description_outlined, maxLines: 3),
                          const SizedBox(height: 24),
                          _buildSaveButton(
                            isSaving: isSaving,
                            onSave: () async {
                              setStateBottom(() => isSaving = true);
                              await _userRepo.updateExperience(work['experience_id'], {
                                'company_name': companyCtrl.text.trim(),
                                'job_title': titleCtrl.text.trim(),
                                'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
                                'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
                                'description': descriptionCtrl.text.trim(),
                              });
                              await _refreshProfile();
                              _showSuccessSnackBar("Work experience updated");
                              if (mounted) Navigator.pop(context);
                            },
                            label: 'Update Experience',
                          ),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _userRepo.deleteExperience(work['experience_id']);
              await _refreshProfile();
              _showSuccessSnackBar("Work experience deleted");
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER FORM WIDGETS ====================

  Widget _buildHandleBar() {
    return Padding(
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
    );
  }

  Widget _buildSheetHeader(String title, VoidCallback onCancel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

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
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSaveButton({required bool isSaving, required VoidCallback onSave, required String label}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isSaving ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $message"), backgroundColor: Colors.red),
    );
  }

  void _showHeadOfficeWarningDialog(BuildContext context, VoidCallback onProceed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Head Office Exists'),
        content: const Text(
          'You already have a head office branch. '
              'Setting this branch as head office will unmark the existing one.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onProceed();
            },
            child: const Text('Proceed'),
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
              _buildProfileHeader(isJobSeeker),

              if (!isJobSeeker) ...[
                const SizedBox(height: 20),
                _buildCompanyInfoCard(),
                const SizedBox(height: 15),
                _buildBranchesCard(),
                const SizedBox(height: 15),
                _buildCompanyDescriptionCard(),
                const SizedBox(height: 15),
              ],

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
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
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
                    : Icon(isJobSeeker ? Icons.person : Icons.business, size: 50, color: Colors.blue),
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
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                if (role != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isJobSeeker ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isJobSeeker ? Colors.green.shade200 : Colors.blue.shade200),
                    ),
                    child: Text(
                      isJobSeeker ? 'Job Seeker' : 'Employer',
                      style: TextStyle(
                        fontSize: 12,
                        color: isJobSeeker ? Colors.green.shade700 : Colors.blue.shade700,
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
      icon: Icons.business_outlined,
      onEdit: _showEditCompanyInfoBottomSheet,
      child: Column(
        children: [
          buildInfoRow("Company Name", companyName.isNotEmpty ? companyName : "Not set"),
          buildInfoRow("Industry", industry.isNotEmpty ? industry : "Not set"),
          buildInfoRow("Company Size", companySize.isNotEmpty ? companySize : "Not set"),
          buildInfoRow("Location", location.isNotEmpty ? location : "Not set"),
        ],
      ),
    );
  }

  // ==================== COMPANY DESCRIPTION CARD ====================
  Widget _buildCompanyDescriptionCard() {
    return buildCardWithEditButton(
      title: "About Company",
      icon: Icons.description_outlined,
      onEdit: _showEditCompanyDescriptionBottomSheet,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          companyDescription.isNotEmpty ? companyDescription : "No company description provided yet.",
          style: TextStyle(fontSize: 14, color: companyDescription.isNotEmpty ? Colors.black87 : Colors.grey, height: 1.5),
        ),
      ),
    );
  }

  // ==================== BRANCHES CARD ====================
  Widget _buildBranchesCard() {
    return buildCardWithAddButton(
      title: "Company Branches",
      icon: Icons.location_city_outlined,
      onAdd: _showAddBranchBottomSheet,
      child: branches.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No branches added yet. Tap + to add branches.", style: TextStyle(color: Colors.grey)),
      )
          : Column(children: branches.map((branch) => BranchItem(branch: branch, onEdit: () => _showEditBranchBottomSheet(branch), onDelete: () => _deleteBranch(branch))).toList()),
    );
  }

  // ==================== PERSONAL INFO CARD ====================
  Widget _buildPersonalInfoCard() {
    final bool isJobSeeker = role == 'JOB_SEEKER';

    return buildCardWithEditButton(
      title: isJobSeeker ? "Personal Information" : "Contact Person",
      icon: Icons.person_outline,
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
            backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
            child: profileImageUrl.isEmpty ? const Icon(Icons.person, size: 30, color: Colors.blue) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullname.isNotEmpty ? fullname : "No name set", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(phone.isNotEmpty ? phone : "No phone number", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 4),
                Text(userEmail ?? "No email", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
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
      icon: Icons.code_outlined,
      onAdd: _showAddSkillBottomSheet,
      child: skills.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No skills added yet. Tap + to add skills.", style: TextStyle(color: Colors.grey)),
      )
          : Column(children: skills.map((skill) => SkillItem(skill: skill, onEdit: () => _showEditSkillBottomSheet(skill), onDelete: () => _deleteSkill(skill))).toList()),
    );
  }

  // ==================== EDUCATION CARD ====================
  Widget _buildEducationCard() {
    return buildCardWithAddButton(
      title: "Education",
      icon: Icons.school_outlined,
      onAdd: _showAddEducationBottomSheet,
      child: educationList.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No education added yet. Tap + to add education.", style: TextStyle(color: Colors.grey)),
      )
          : Column(children: educationList.map((edu) => EducationItem(education: edu, onEdit: () => _showEditEducationBottomSheet(edu), onDelete: () => _deleteEducation(edu))).toList()),
    );
  }

  // ==================== WORK CARD ====================
  Widget _buildWorkCard() {
    return buildCardWithAddButton(
      title: "Work Experience",
      icon: Icons.work_outline,
      onAdd: _showAddWorkBottomSheet,
      child: workList.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No work experience added yet. Tap + to add experience.", style: TextStyle(color: Colors.grey)),
      )
          : Column(children: workList.map((work) => WorkItem(work: work, onEdit: () => _showEditWorkBottomSheet(work), onDelete: () => _deleteWork(work))).toList()),
    );
  }

  // ==================== RESUME CARD ====================
  Widget _buildResumeCard() {
    return buildCardWithAddButton(
      title: "Resume",
      icon: Icons.picture_as_pdf,
      onAdd: _uploadResume,
      child: resumes.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No resume uploaded yet. Tap + to upload resume.", style: TextStyle(color: Colors.grey)),
      )
          : Column(children: resumes.map((resume) => ResumeItem(resume: resume, onDelete: () => _deleteResume(resume), onDownload: () => _downloadResume(resume))).toList()),
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
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 14)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget buildCardWithEditButton({
    required String title,
    required IconData icon,
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(icon, color: Colors.blue, size: 22), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19))]),
              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: onEdit, tooltip: 'Edit $title'),
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
    required IconData icon,
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(icon, color: Colors.blue, size: 22), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19))]),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: onAdd, tooltip: 'Add $title'),
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
// SKILL ITEM WIDGET
// ============================================================================
class SkillItem extends StatelessWidget {
  final Map<String, dynamic> skill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SkillItem({super.key, required this.skill, required this.onEdit, required this.onDelete});

  Color getSkillLevelColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'beginner': return Colors.green;
      case 'intermediate': return Colors.orange;
      case 'advanced': return Colors.red;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skillLevel = skill['skill_level'];
    final hasLevel = skillLevel != null && skillLevel.toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Expanded(child: Text(skill['skill_name'] ?? 'Unknown Skill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (hasLevel) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: getSkillLevelColor(skillLevel).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(skillLevel, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: getSkillLevelColor(skillLevel))),
              ),
            ),
          ],
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
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

  const EducationItem({super.key, required this.education, required this.onEdit, required this.onDelete});

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
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(education['institution_name'] ?? 'Unknown Institution', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                if (education['qualification'] != null && education['qualification'].toString().isNotEmpty)
                  Text(education['qualification'], style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                const SizedBox(height: 4),
                if (education['start_date'] != null)
                  Text(
                    '${_formatDate(education['start_date'])}${education['end_date'] != null && education['end_date'].toString().isNotEmpty ? ' - ${_formatDate(education['end_date'])}' : ' - Present'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
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

  const WorkItem({super.key, required this.work, required this.onEdit, required this.onDelete});

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
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(work['job_title'] ?? 'Unknown Position', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(work['company_name'] ?? 'Unknown Company', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                const SizedBox(height: 4),
                if (work['start_date'] != null)
                  Text(
                    '${_formatDate(work['start_date'])}${work['end_date'] != null && work['end_date'].toString().isNotEmpty ? ' - ${_formatDate(work['end_date'])}' : ' - Present'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
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

  const ResumeItem({super.key, required this.resume, required this.onDelete, required this.onDownload});

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
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resume['file_name'] ?? 'Unknown File', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Uploaded: ${_formatDate(resume['uploaded_at'])}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                if (resume['is_default'] == true)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text('Default', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) { if (value == 'download') onDownload(); if (value == 'delete') onDelete(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'download', child: Row(children: [Icon(Icons.download, size: 18), SizedBox(width: 8), Text("Download")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BRANCH ITEM WIDGET
// ============================================================================
class BranchItem extends StatelessWidget {
  final Map<String, dynamic> branch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BranchItem({super.key, required this.branch, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: branch['is_head_office'] == true ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: branch['is_head_office'] == true ? Colors.blue.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(branch['branch_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (branch['is_head_office'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                        child: const Text('Head Office', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(branch['address'], style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 2),
                Text('${branch['city']}, ${branch['state']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                if (branch['country'] != null && branch['country'].toString().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(branch['country'], style: TextStyle(color: Colors.grey.shade500, fontSize: 11))),
                if (branch['postal_code'] != null && branch['postal_code'].toString().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text('Postal Code: ${branch['postal_code']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11))),
                if (branch['phone'] != null && branch['phone'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [Icon(Icons.phone, size: 12, color: Colors.grey.shade500), const SizedBox(width: 4), Text(branch['phone'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12))]),
                ],
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }
}