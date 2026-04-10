import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;

  /// Basic user info
  String? userId;
  String? role;
  String? userEmail;

  /// User data
  String fullname = '';
  String phone = '';

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

  /// Skills
  List<Map<String, dynamic>> skills = [];

  /// Education
  List<Map<String, dynamic>> educationList = [];

  /// Work Experience
  List<Map<String, dynamic>> workList = [];

  /// Resume
  List<Map<String, dynamic>> resumes = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  /// FETCH PROFILE
  Future<void> fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    userId = user.id;
    userEmail = user.email;

    final userData = await supabase
        .from('users')
        .select()
        .eq('user_id', userId!)
        .single();

    role = userData['role'];
    fullname = userData['fullname'] ?? '';
    phone = userData['phone'] ?? '';

    if (role == 'JOB_SEEKER') {
      final profile = await supabase
          .from('job_seeker_profile')
          .select()
          .eq('user_id', userId!)
          .maybeSingle();

      if (profile != null) {
        dateOfBirth = profile['date_of_birth'] ?? '';
        gender = profile['gender'] ?? '';
        address = profile['address'] ?? '';
        bio = profile['bio'] ?? '';
      }

      // Fetch resumes
      final resumeData = await supabase
          .from('resume')
          .select()
          .eq('user_id', userId!);
      resumes = List<Map<String, dynamic>>.from(resumeData);
    } else if (role == 'POSTER') {
      final profile = await supabase
          .from('company_profile')
          .select()
          .eq('user_id', userId!)
          .maybeSingle();

      if (profile != null) {
        companyName = profile['company_name'] ?? '';
        companyDescription = profile['company_description'] ?? '';
        industry = profile['industry'] ?? '';
        companySize = profile['company_size'] ?? '';
        location = profile['location'] ?? '';
      }
    }

    final skillData = await supabase
        .from('skills')
        .select()
        .eq('user_id', userId!);
    skills = List<Map<String, dynamic>>.from(skillData);

    final eduData = await supabase
        .from('education')
        .select()
        .eq('user_id', userId!);
    educationList = List<Map<String, dynamic>>.from(eduData);

    final workData = await supabase
        .from('experience')
        .select()
        .eq('user_id', userId!);
    workList = List<Map<String, dynamic>>.from(workData);

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(25, 25, 25, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header with Back Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 30),

              /// PROFILE PHOTO SECTION
              Container(
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
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullname.isNotEmpty ? fullname : 'No name set',
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
                                color: role == 'JOB_SEEKER'
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: role == 'JOB_SEEKER'
                                      ? Colors.green.shade200
                                      : Colors.blue.shade200,
                                ),
                              ),
                              child: Text(
                                role == 'JOB_SEEKER' ? 'Job Seeker' : 'Employer',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: role == 'JOB_SEEKER'
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
              ),
              const SizedBox(height: 15),

              /// PERSONAL INFO with Edit Button
              buildCardWithEditButton(
                title: "Personal Information",
                onEdit: () => _showEditPersonalInfoBottomSheet(),
                child: Column(
                  children: [
                    buildInfoRow("Full Name", fullname.isNotEmpty ? fullname : "Not set"),
                    buildInfoRow("Phone Number", phone.isNotEmpty ? phone : "Not set"),
                    if (role == 'JOB_SEEKER') ...[
                      buildInfoRow("Date of Birth", dateOfBirth.isNotEmpty ? dateOfBirth : "Not set"),
                      buildInfoRow("Gender", gender.isNotEmpty ? gender : "Not set"),
                      buildInfoRow("Address", address.isNotEmpty ? address : "Not set"),
                      buildInfoRow("Bio", bio.isNotEmpty ? bio : "Not set", isMultiline: true),
                    ],
                    if (role == 'POSTER') ...[
                      buildInfoRow("Company Name", companyName.isNotEmpty ? companyName : "Not set"),
                      buildInfoRow(
                        "Company Description",
                        companyDescription.isNotEmpty ? companyDescription : "Not set",
                        isMultiline: true,
                      ),
                      buildInfoRow("Industry", industry.isNotEmpty ? industry : "Not set"),
                      buildInfoRow("Company Size", companySize.isNotEmpty ? companySize : "Not set"),
                      buildInfoRow("Location", location.isNotEmpty ? location : "Not set"),
                    ],
                  ],
                ),
              ),

              /// SKILLS
              if (role == 'JOB_SEEKER')
                buildCardWithAddButton(
                  title: "Skills",
                  onAdd: () => _showAddSkillBottomSheet(),
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
                ),

              /// EDUCATION
              if (role == 'JOB_SEEKER')
                buildCardWithAddButton(
                  title: "Education",
                  onAdd: () => _showAddEducationBottomSheet(),
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
                ),

              /// WORK EXPERIENCE
              if (role == 'JOB_SEEKER')
                buildCardWithAddButton(
                  title: "Work Experience",
                  onAdd: () => _showAddWorkBottomSheet(),
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
                ),

              /// RESUME
              if (role == 'JOB_SEEKER')
                buildCardWithAddButton(
                  title: "Resume",
                  onAdd: () => _uploadResume(),
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
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            buildNavItem(Icons.home_outlined, "Home", isActive: false),
            buildNavItem(Icons.work_outline, "Jobs", isActive: false),
            buildNavItem(Icons.description_outlined, "Applications", isActive: false),
            buildNavItem(Icons.person_outline, "Profile", isActive: true),
          ],
        ),
      ),
    );
  }

  // Personal Info Bottom Sheet
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
        onSuccess: () => fetchProfile(),
      ),
    );
  }

  // Resume Methods
  Future<void> _uploadResume() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        final file = result.files.first;
        final bytes = file.bytes;
        final fileName = file.name;

        if (bytes != null) {
          // Upload to Supabase Storage
          final storagePath = 'resumes/$userId/$fileName';
          await supabase.storage.from('resumes').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

          // Get public URL
          final publicUrl = supabase.storage.from('resumes').getPublicUrl(storagePath);

          // Save to resume table
          await supabase.from('resume').insert({
            'user_id': userId,
            'file_url': publicUrl,
            'file_name': fileName,
            'uploaded_at': DateTime.now().toIso8601String(),
            'is_default': resumes.isEmpty,
          });

          await fetchProfile();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Resume uploaded successfully!")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading resume: $e")),
      );
    }
  }

  Future<void> _deleteResume(Map<String, dynamic> resume) async {
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
                await supabase
                    .from('resume')
                    .delete()
                    .eq('resume_id', resume['resume_id']);

                await fetchProfile();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Resume deleted")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error deleting resume: $e")),
                );
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

  // Skill Methods
  void _showAddSkillBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SkillFormBottomSheet(
        userId: userId!,
        onSuccess: () => fetchProfile(),
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
        onSuccess: () => fetchProfile(),
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
              await supabase
                  .from('skills')
                  .delete()
                  .eq('skill_id', skill['skill_id']);
              await fetchProfile();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Skill deleted")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Education Methods
  void _showAddEducationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EducationFormBottomSheet(
        userId: userId!,
        onSuccess: () => fetchProfile(),
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
        onSuccess: () => fetchProfile(),
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
              await supabase
                  .from('education')
                  .delete()
                  .eq('education_id', education['education_id']);
              await fetchProfile();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Education deleted")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Work Experience Methods
  void _showAddWorkBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => WorkFormBottomSheet(
        userId: userId!,
        onSuccess: () => fetchProfile(),
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
        onSuccess: () => fetchProfile(),
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
              await supabase
                  .from('experience')
                  .delete()
                  .eq('experience_id', work['experience_id']);
              await fetchProfile();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Work experience deleted")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

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

  Widget buildNavItem(
      IconData icon,
      String label,
      {bool isActive = false}) {
    return InkWell(
      onTap: () {
        if (label == "Home") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AnimatedHomePage()),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 35,
            color: isActive ? Colors.blue : Colors.grey,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.blue : Colors.grey,
            ),
          )
        ],
      ),
    );
  }
}

// Personal Info Form Bottom Sheet
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
    required this.onSuccess,
  });

  @override
  State<PersonalInfoFormBottomSheet> createState() => _PersonalInfoFormBottomSheetState();
}

class _PersonalInfoFormBottomSheetState extends State<PersonalInfoFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullnameCtrl;
  late TextEditingController _phoneCtrl;

  // Job seeker controllers
  late TextEditingController _dobCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _bioCtrl;
  late String _selectedGender;

  // Company controllers
  late TextEditingController _companyNameCtrl;
  late TextEditingController _companyDescCtrl;
  late TextEditingController _industryCtrl;
  late TextEditingController _companySizeCtrl;
  late TextEditingController _locationCtrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullnameCtrl = TextEditingController(text: widget.fullname);
    _phoneCtrl = TextEditingController(text: widget.phone);

    if (widget.role == 'JOB_SEEKER') {
      _dobCtrl = TextEditingController(text: widget.dateOfBirth);
      _addressCtrl = TextEditingController(text: widget.address);
      _bioCtrl = TextEditingController(text: widget.bio);
      _selectedGender = widget.gender;
    } else {
      _companyNameCtrl = TextEditingController(text: widget.companyName);
      _companyDescCtrl = TextEditingController(text: widget.companyDescription);
      _industryCtrl = TextEditingController(text: widget.industry);
      _companySizeCtrl = TextEditingController(text: widget.companySize);
      _locationCtrl = TextEditingController(text: widget.location);
    }
  }

  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _phoneCtrl.dispose();
    if (widget.role == 'JOB_SEEKER') {
      _dobCtrl.dispose();
      _addressCtrl.dispose();
      _bioCtrl.dispose();
    } else {
      _companyNameCtrl.dispose();
      _companyDescCtrl.dispose();
      _industryCtrl.dispose();
      _companySizeCtrl.dispose();
      _locationCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Update users table
      await supabase.from('users').update({
        'fullname': _fullnameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', widget.userId);

      // Update role-specific tables
      if (widget.role == 'JOB_SEEKER') {
        final existingProfile = await supabase
            .from('job_seeker_profile')
            .select()
            .eq('user_id', widget.userId)
            .maybeSingle();

        final profileData = {
          'date_of_birth': _dobCtrl.text.isEmpty ? null : _dobCtrl.text,
          'gender': _selectedGender,
          'address': _addressCtrl.text,
          'bio': _bioCtrl.text,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (existingProfile == null) {
          await supabase.from('job_seeker_profile').insert({
            'user_id': widget.userId,
            ...profileData,
          });
        } else {
          await supabase
              .from('job_seeker_profile')
              .update(profileData)
              .eq('user_id', widget.userId);
        }
      } else {
        final existingProfile = await supabase
            .from('company_profile')
            .select()
            .eq('user_id', widget.userId)
            .maybeSingle();

        final profileData = {
          'company_name': _companyNameCtrl.text.trim(),
          'company_description': _companyDescCtrl.text.trim(),
          'industry': _industryCtrl.text.trim(),
          'company_size': _companySizeCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
        };

        if (existingProfile == null) {
          await supabase.from('company_profile').insert({
            'user_id': widget.userId,
            ...profileData,
          });
        } else {
          await supabase
              .from('company_profile')
              .update(profileData)
              .eq('user_id', widget.userId);
        }
      }

      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
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
                "Edit Personal Information",
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
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              if (widget.role == 'JOB_SEEKER') ...[
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
              ] else ...[
                TextFormField(
                  controller: _companyNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Company Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _companyDescCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Company Description",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _industryCtrl,
                  decoration: const InputDecoration(
                    labelText: "Industry",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _companySizeCtrl,
                  decoration: const InputDecoration(
                    labelText: "Company Size",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: "Location",
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

// Skill Form Bottom Sheet
class SkillFormBottomSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? skill;
  final VoidCallback onSuccess;

  const SkillFormBottomSheet({
    super.key,
    required this.userId,
    this.skill,
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
      final supabase = Supabase.instance.client;

      if (widget.skill == null) {
        await supabase.from('skills').insert({
          'user_id': widget.userId,
          'skill_name': _skillNameCtrl.text.trim(),
          'skill_level': _selectedLevel,
        });
      } else {
        await supabase
            .from('skills')
            .update({
          'skill_name': _skillNameCtrl.text.trim(),
          'skill_level': _selectedLevel,
        })
            .eq('skill_id', widget.skill!['skill_id']);
      }

      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.skill == null ? "Skill added" : "Skill updated"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
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

// Education Form Bottom Sheet
class EducationFormBottomSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? education;
  final VoidCallback onSuccess;

  const EducationFormBottomSheet({
    super.key,
    required this.userId,
    this.education,
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
      final supabase = Supabase.instance.client;
      final data = {
        'user_id': widget.userId,
        'institution_name': _institutionCtrl.text.trim(),
        'qualification': _qualificationCtrl.text.trim(),
        'field_of_study': _fieldCtrl.text.trim(),
        'start_date': _startDateCtrl.text.isEmpty ? null : _startDateCtrl.text,
        'end_date': _endDateCtrl.text.isEmpty ? null : _endDateCtrl.text,
        'description': _descriptionCtrl.text.trim(),
      };

      if (widget.education == null) {
        await supabase.from('education').insert(data);
      } else {
        await supabase
            .from('education')
            .update(data)
            .eq('education_id', widget.education!['education_id']);
      }

      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.education == null ? "Education added" : "Education updated"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
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

// Work Experience Form Bottom Sheet
class WorkFormBottomSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? work;
  final VoidCallback onSuccess;

  const WorkFormBottomSheet({
    super.key,
    required this.userId,
    this.work,
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
      final supabase = Supabase.instance.client;
      final data = {
        'user_id': widget.userId,
        'company_name': _companyCtrl.text.trim(),
        'job_title': _titleCtrl.text.trim(),
        'start_date': _startDateCtrl.text.isEmpty ? null : _startDateCtrl.text,
        'end_date': _endDateCtrl.text.isEmpty ? null : _endDateCtrl.text,
        'description': _descriptionCtrl.text.trim(),
      };

      if (widget.work == null) {
        await supabase.from('experience').insert(data);
      } else {
        await supabase
            .from('experience')
            .update(data)
            .eq('experience_id', widget.work!['experience_id']);
      }

      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.work == null ? "Work experience added" : "Work experience updated"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
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

// Skill Chip Widget
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
          if (skill['skill_level'] != null)
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

// Education Item Widget
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
                        (education['end_date'] != null
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

// Work Item Widget
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
                        (work['end_date'] != null
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

// Resume Item Widget
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