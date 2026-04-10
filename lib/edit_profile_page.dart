import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<EditProfilePage> {
  final supabase = Supabase.instance.client;

  /// Basic user info
  String? userId;
  String? role;

  /// User controllers
  final fullnameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  /// Job seeker controllers
  final dobCtrl = TextEditingController();
  String? selectedGender;
  final addressCtrl = TextEditingController();
  final bioCtrl = TextEditingController();

  /// Company controllers
  final companyNameCtrl = TextEditingController();
  final companyDescCtrl = TextEditingController();
  final industryCtrl = TextEditingController();
  final companySizeCtrl = TextEditingController();
  final locationCtrl = TextEditingController();

  /// Skills
  List<Map<String, dynamic>> skills = [];

  /// Education
  List<Map<String, dynamic>> educationList = [];

  /// Work Experience
  List<Map<String, dynamic>> workList = [];

  final newSkillCtrl = TextEditingController();
  String? selectedSkillLevel;

  bool isLoading = true;
  bool isSaving = false;

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

    // Fetch from users table
    final userData = await supabase
        .from('users')
        .select()
        .eq('user_id', userId!)
        .single();

    role = userData['role'];
    fullnameCtrl.text = userData['fullname'] ?? '';
    phoneCtrl.text = userData['phone'] ?? '';

    /// Fetch from role-specific tables
    if (role == 'JOB_SEEKER') {
      final profile = await supabase
          .from('job_seeker_profile')
          .select()
          .eq('user_id', userId!)
          .maybeSingle();

      if (profile != null) {
        dobCtrl.text = profile['date_of_birth'] ?? '';
        selectedGender = profile['gender'];
        addressCtrl.text = profile['address'] ?? '';
        bioCtrl.text = profile['bio'] ?? '';
      }
    } else if (role == 'POSTER') {
      final profile = await supabase
          .from('company_profile')
          .select()
          .eq('user_id', userId!)
          .maybeSingle();

      if (profile != null) {
        companyNameCtrl.text = profile['company_name'] ?? '';
        companyDescCtrl.text = profile['company_description'] ?? '';
        industryCtrl.text = profile['industry'] ?? '';
        companySizeCtrl.text = profile['company_size'] ?? '';
        locationCtrl.text = profile['location'] ?? '';
      }
    }

    /// SKILLS - now with skill_level
    final skillData = await supabase
        .from('skills')
        .select()
        .eq('user_id', userId!);

    skills = List<Map<String, dynamic>>.from(skillData);

    /// EDUCATION
    final eduData = await supabase
        .from('education')
        .select()
        .eq('user_id', userId!);

    educationList = List<Map<String, dynamic>>.from(eduData);

    /// WORK EXPERIENCE (using experience table)
    final workData = await supabase
        .from('experience')
        .select()
        .eq('user_id', userId!);

    workList = List<Map<String, dynamic>>.from(workData);

    setState(() {
      isLoading = false;
    });
  }

  /// SKILL FUNCTIONS
  Future<void> insertSkill(String skill, String? level) async {
    await supabase.from('skills').insert({
      'user_id': userId,
      'skill_name': skill,
      'skill_level': level,
    }).select();
  }

  void addSkill() async {
    final skill = newSkillCtrl.text.trim();
    if (skill.isEmpty) return;

    setState(() => isSaving = true);
    try {
      final result = await insertSkill(skill, selectedSkillLevel);
      setState(() {
        skills.add({
          'skill_name': skill,
          'skill_level': selectedSkillLevel,
          'skill_id': DateTime.now().toString(), // temporary ID
        });
        newSkillCtrl.clear();
        selectedSkillLevel = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Skill added")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding skill: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> deleteSkill(String skillId) async {
    await supabase
        .from('skills')
        .delete()
        .eq('skill_id', skillId);
  }

  void removeSkill(int index) async {
    final skill = skills[index];
    setState(() => isSaving = true);
    try {
      await deleteSkill(skill['skill_id']);
      setState(() {
        skills.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Skill removed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error removing skill: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  /// EDUCATION FUNCTIONS
  Future<void> addEducation() async {
    final newEdu = {
      'user_id': userId,
      'institution_name': '',
      'qualification': '',
      'field_of_study': '',
      'start_date': DateTime.now().toIso8601String().split('T')[0],
      'end_date': null,
      'description': '',
    };

    setState(() => isSaving = true);
    try {
      final result = await supabase
          .from('education')
          .insert(newEdu)
          .select()
          .single();
      setState(() {
        educationList.add(result);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding education: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> updateEducation(int index, Map<String, dynamic> updatedData) async {
    final edu = educationList[index];
    setState(() => isSaving = true);
    try {
      await supabase
          .from('education')
          .update(updatedData)
          .eq('education_id', edu['education_id']);

      setState(() {
        educationList[index] = {...edu, ...updatedData};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Education updated")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating education: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> deleteEducation(int index) async {
    final edu = educationList[index];
    setState(() => isSaving = true);
    try {
      await supabase
          .from('education')
          .delete()
          .eq('education_id', edu['education_id']);

      setState(() {
        educationList.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Education removed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting education: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  /// WORK EXPERIENCE FUNCTIONS
  Future<void> addWork() async {
    final newWork = {
      'user_id': userId,
      'company_name': '',
      'job_title': '',
      'start_date': DateTime.now().toIso8601String().split('T')[0],
      'end_date': null,
      'description': '',
    };

    setState(() => isSaving = true);
    try {
      final result = await supabase
          .from('experience')
          .insert(newWork)
          .select()
          .single();
      setState(() {
        workList.add(result);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding work experience: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> updateWork(int index, Map<String, dynamic> updatedData) async {
    final work = workList[index];
    setState(() => isSaving = true);
    try {
      await supabase
          .from('experience')
          .update(updatedData)
          .eq('experience_id', work['experience_id']);

      setState(() {
        workList[index] = {...work, ...updatedData};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Work experience updated")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating work: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> deleteWork(int index) async {
    final work = workList[index];
    setState(() => isSaving = true);
    try {
      await supabase
          .from('experience')
          .delete()
          .eq('experience_id', work['experience_id']);

      setState(() {
        workList.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Work experience removed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting work: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  /// UPDATE PROFILE
  Future<void> updateProfile() async {
    if (userId == null) return;

    setState(() => isSaving = true);
    try {
      // Update users table
      await supabase.from('users').update({
        'fullname': fullnameCtrl.text,
        'phone': phoneCtrl.text,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId!);

      // Update role-specific tables
      if (role == 'JOB_SEEKER') {
        final existingProfile = await supabase
            .from('job_seeker_profile')
            .select()
            .eq('user_id', userId!)
            .maybeSingle();

        final profileData = {
          'date_of_birth': dobCtrl.text.isEmpty ? null : dobCtrl.text,
          'gender': selectedGender,
          'address': addressCtrl.text,
          'bio': bioCtrl.text,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (existingProfile == null) {
          await supabase.from('job_seeker_profile').insert({
            'user_id': userId,
            ...profileData,
          });
        } else {
          await supabase
              .from('job_seeker_profile')
              .update(profileData)
              .eq('user_id', userId!);
        }
      } else if (role == 'POSTER') {
        final existingProfile = await supabase
            .from('company_profile')
            .select()
            .eq('user_id', userId!)
            .maybeSingle();

        final profileData = {
          'company_name': companyNameCtrl.text,
          'company_description': companyDescCtrl.text,
          'industry': industryCtrl.text,
          'company_size': companySizeCtrl.text,
          'location': locationCtrl.text,
        };

        if (existingProfile == null) {
          await supabase.from('company_profile').insert({
            'user_id': userId,
            ...profileData,
          });
        } else {
          await supabase
              .from('company_profile')
              .update(profileData)
              .eq('user_id', userId!);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    fullnameCtrl.dispose();
    phoneCtrl.dispose();
    dobCtrl.dispose();
    addressCtrl.dispose();
    bioCtrl.dispose();
    companyNameCtrl.dispose();
    companyDescCtrl.dispose();
    industryCtrl.dispose();
    companySizeCtrl.dispose();
    locationCtrl.dispose();
    newSkillCtrl.dispose();
    super.dispose();
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
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),

                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
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
                        Stack(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person, size: 40, color: Colors.white),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(width: 15),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Profile Photo",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                            ),
                            Text("Upload your photo"),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  /// PERSONAL INFO
                  buildCard(
                    title: "Personal Information",
                    child: Column(
                      children: [
                        buildInput(fullnameCtrl, "Full Name"),
                        buildInput(phoneCtrl, "Phone Number"),
                        if (role == 'JOB_SEEKER') ...[
                          buildInput(dobCtrl, "Date of Birth (YYYY-MM-DD)"),
                          buildGenderDropdown(),
                          buildInput(addressCtrl, "Address"),
                          buildInput(bioCtrl, "Bio", maxLines: 3),
                        ],
                        if (role == 'POSTER') ...[
                          buildInput(companyNameCtrl, "Company Name"),
                          buildInput(companyDescCtrl, "Company Description", maxLines: 3),
                          buildInput(industryCtrl, "Industry"),
                          buildInput(companySizeCtrl, "Company Size"),
                          buildInput(locationCtrl, "Location"),
                        ],
                      ],
                    ),
                  ),

                  /// SKILLS
                  buildCard(
                    title: "Skills",
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skills.map((skill) {
                            final index = skills.indexOf(skill);
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
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => removeSkill(index),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: newSkillCtrl,
                                decoration: const InputDecoration(
                                  hintText: "Add skill",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: selectedSkillLevel,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                hint: const Text("Level"),
                                items: const [
                                  DropdownMenuItem(value: "Beginner", child: Text("Beginner")),
                                  DropdownMenuItem(value: "Intermediate", child: Text("Intermediate")),
                                  DropdownMenuItem(value: "Advanced", child: Text("Advanced")),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedSkillLevel = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: isSaving ? null : addSkill,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  /// EDUCATION (for job seekers only)
                  if (role == 'JOB_SEEKER')
                    buildCard(
                      title: "Education",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isSaving ? null : addEducation,
                              child: const Text("+ Add Education"),
                            ),
                          ),
                          if (educationList.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "No education added yet",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ...educationList.asMap().entries.map((entry) {
                            final index = entry.key;
                            final edu = entry.value;
                            return EducationCard(
                              education: edu,
                              onSave: (updatedData) => updateEducation(index, updatedData),
                              onDelete: () => deleteEducation(index),
                              isSaving: isSaving,
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                  /// WORK EXPERIENCE (for job seekers only)
                  if (role == 'JOB_SEEKER')
                    buildCard(
                      title: "Work Experience",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isSaving ? null : addWork,
                              child: const Text("+ Add Experience"),
                            ),
                          ),
                          if (workList.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "No work experience added yet",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ...workList.asMap().entries.map((entry) {
                            final index = entry.key;
                            final work = entry.value;
                            return WorkCard(
                              work: work,
                              onSave: (updatedData) => updateWork(index, updatedData),
                              onDelete: () => deleteWork(index),
                              isSaving: isSaving,
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                  /// RESUME
                  if (role == 'JOB_SEEKER')
                    buildCard(
                      title: "Resume",
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Implement file picker for resume upload
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Resume upload coming soon!")),
                            );
                          },
                          icon: const Icon(Icons.upload_file, size: 20),
                          label: const Text("Upload Resume (PDF)"),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        color: Colors.white,
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving ? null : updateProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text(
                "Save Changes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildGenderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: selectedGender,
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
            selectedGender = value;
          });
        },
      ),
    );
  }

  Widget buildCard({
    required String title,
    required Widget child,
  }) {
    return Container(
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget buildInput(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// Education Card Widget
class EducationCard extends StatefulWidget {
  final Map<String, dynamic> education;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onDelete;
  final bool isSaving;

  const EducationCard({
    super.key,
    required this.education,
    required this.onSave,
    required this.onDelete,
    required this.isSaving,
  });

  @override
  State<EducationCard> createState() => _EducationCardState();
}

class _EducationCardState extends State<EducationCard> {
  late TextEditingController institutionCtrl;
  late TextEditingController qualificationCtrl;
  late TextEditingController fieldCtrl;
  late TextEditingController startDateCtrl;
  late TextEditingController endDateCtrl;
  late TextEditingController descriptionCtrl;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    institutionCtrl = TextEditingController(text: widget.education['institution_name'] ?? '');
    qualificationCtrl = TextEditingController(text: widget.education['qualification'] ?? '');
    fieldCtrl = TextEditingController(text: widget.education['field_of_study'] ?? '');
    startDateCtrl = TextEditingController(text: widget.education['start_date'] ?? '');
    endDateCtrl = TextEditingController(text: widget.education['end_date'] ?? '');
    descriptionCtrl = TextEditingController(text: widget.education['description'] ?? '');
  }

  @override
  void dispose() {
    institutionCtrl.dispose();
    qualificationCtrl.dispose();
    fieldCtrl.dispose();
    startDateCtrl.dispose();
    endDateCtrl.dispose();
    descriptionCtrl.dispose();
    super.dispose();
  }

  void save() {
    widget.onSave({
      'institution_name': institutionCtrl.text,
      'qualification': qualificationCtrl.text,
      'field_of_study': fieldCtrl.text,
      'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
      'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
      'description': descriptionCtrl.text,
    });
    setState(() => isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (!isEditing) ...[
              ListTile(
                title: Text(institutionCtrl.text.isEmpty ? "New Education" : institutionCtrl.text),
                subtitle: Text(qualificationCtrl.text.isEmpty ? "Click edit to add details" : qualificationCtrl.text),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: widget.isSaving ? null : () => setState(() => isEditing = true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: widget.isSaving ? null : widget.onDelete,
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: institutionCtrl,
                decoration: const InputDecoration(labelText: "Institution Name"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qualificationCtrl,
                decoration: const InputDecoration(labelText: "Qualification"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fieldCtrl,
                decoration: const InputDecoration(labelText: "Field of Study"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: startDateCtrl,
                decoration: const InputDecoration(labelText: "Start Date (YYYY-MM-DD)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: endDateCtrl,
                decoration: const InputDecoration(labelText: "End Date (YYYY-MM-DD)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.isSaving ? null : () => setState(() => isEditing = false),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: widget.isSaving ? null : save,
                    child: const Text("Save"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Work Experience Card Widget
class WorkCard extends StatefulWidget {
  final Map<String, dynamic> work;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onDelete;
  final bool isSaving;

  const WorkCard({
    super.key,
    required this.work,
    required this.onSave,
    required this.onDelete,
    required this.isSaving,
  });

  @override
  State<WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<WorkCard> {
  late TextEditingController companyCtrl;
  late TextEditingController titleCtrl;
  late TextEditingController startDateCtrl;
  late TextEditingController endDateCtrl;
  late TextEditingController descriptionCtrl;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    companyCtrl = TextEditingController(text: widget.work['company_name'] ?? '');
    titleCtrl = TextEditingController(text: widget.work['job_title'] ?? '');
    startDateCtrl = TextEditingController(text: widget.work['start_date'] ?? '');
    endDateCtrl = TextEditingController(text: widget.work['end_date'] ?? '');
    descriptionCtrl = TextEditingController(text: widget.work['description'] ?? '');
  }

  @override
  void dispose() {
    companyCtrl.dispose();
    titleCtrl.dispose();
    startDateCtrl.dispose();
    endDateCtrl.dispose();
    descriptionCtrl.dispose();
    super.dispose();
  }

  void save() {
    widget.onSave({
      'company_name': companyCtrl.text,
      'job_title': titleCtrl.text,
      'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
      'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
      'description': descriptionCtrl.text,
    });
    setState(() => isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (!isEditing) ...[
              ListTile(
                title: Text(companyCtrl.text.isEmpty ? "New Experience" : companyCtrl.text),
                subtitle: Text(titleCtrl.text.isEmpty ? "Click edit to add details" : titleCtrl.text),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: widget.isSaving ? null : () => setState(() => isEditing = true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: widget.isSaving ? null : widget.onDelete,
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(labelText: "Company Name"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Job Title"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: startDateCtrl,
                decoration: const InputDecoration(labelText: "Start Date (YYYY-MM-DD)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: endDateCtrl,
                decoration: const InputDecoration(labelText: "End Date (YYYY-MM-DD)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.isSaving ? null : () => setState(() => isEditing = false),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: widget.isSaving ? null : save,
                    child: const Text("Save"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}