import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/data/location_service.dart';
import 'package:jobify/data/user_repository.dart';

/// Profile header
class ProfileHeader extends StatelessWidget {
  final bool isJobSeeker;
  final String profileImageUrl;
  final String fullname;
  final String companyName;
  final String? userEmail;
  final String? role;
  final VoidCallback onImageTap;

  const ProfileHeader({
    super.key,
    required this.isJobSeeker,
    required this.profileImageUrl,
    required this.fullname,
    required this.companyName,
    required this.userEmail,
    required this.role,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
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
                    placeholder: (_, __) => const CircularProgressIndicator(),
                    errorWidget: (_, __, ___) => Icon(
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
                  onTap: onImageTap,
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
                  isJobSeeker ? (fullname.isNotEmpty ? fullname : 'No name set') : (companyName.isNotEmpty ? companyName : 'No company name'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(userEmail ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
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
}

// Company Info
class CompanyInfoCard extends StatelessWidget {
  final String companyName;
  final String industry;
  final String companySize;
  final String phone;
  final VoidCallback onEdit;

  const CompanyInfoCard({
    super.key,
    required this.companyName,
    required this.industry,
    required this.companySize,
    required this.phone,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return buildCardWithEditButton(
      title: "Company Information",
      icon: Icons.business_outlined,
      onEdit: onEdit,
      child: Column(
        children: [
          buildInfoRow("Company Name", companyName.isNotEmpty ? companyName : "Not set"),
          buildInfoRow("Phone", phone.isNotEmpty ? phone : "Not set"),
          buildInfoRow("Industry", industry.isNotEmpty ? industry : "Not set"),
          buildInfoRow("Company Size", companySize.isNotEmpty ? companySize : "Not set"),
        ],
      ),
    );
  }
}

// Company Description
class CompanyDescriptionCard extends StatelessWidget {
  final String companyDescription;
  final VoidCallback onEdit;

  const CompanyDescriptionCard({
    super.key,
    required this.companyDescription,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return buildCardWithEditButton(
      title: "About Company",
      icon: Icons.description_outlined,
      onEdit: onEdit,
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
}

// Branch
class BranchesCard extends StatelessWidget {
  final List<Map<String, dynamic>> branches;
  final VoidCallback onAdd;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;

  const BranchesCard({
    super.key,
    required this.branches,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return buildCardWithAddButton(
      title: "Company Branches",
      icon: Icons.location_city_outlined,
      onAdd: onAdd,
      child: branches.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No branches added yet. Tap + to add branches.", style: TextStyle(color: Colors.grey)),
      )
          : Column(
        children: branches.map((branch) => BranchItem(branch: branch, onEdit: () => onEdit(branch), onDelete: () => onDelete(branch))).toList(),
      ),
    );
  }
}

// Personal info
class PersonalInfoCard extends StatelessWidget {
  final bool isJobSeeker;
  final String fullname;
  final String phone;
  final String? userEmail;
  final String dateOfBirth;
  final String gender;
  final String address;
  final String bio;
  final String profileImageUrl;
  final VoidCallback onEdit;

  const PersonalInfoCard({
    super.key,
    required this.isJobSeeker,
    required this.fullname,
    required this.phone,
    required this.userEmail,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.bio,
    required this.profileImageUrl,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return buildCardWithEditButton(
      title: isJobSeeker ? "Personal Information" : "Contact Person",
      icon: Icons.person_outline,
      onEdit: onEdit,
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
}

// Skills
class SkillsCard extends StatelessWidget {
  final List<Map<String, dynamic>> skills;
  final VoidCallback onAdd;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;

  const SkillsCard({
    super.key,
    required this.skills,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return buildCardWithAddButton(
      title: "Skills",
      icon: Icons.code_outlined,
      onAdd: onAdd,
      child: skills.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No skills added yet. Tap + to add skills.", style: TextStyle(color: Colors.grey)),
      )
          : Column(
        children: skills.map((skill) => SkillItem(skill: skill, onEdit: () => onEdit(skill), onDelete: () => onDelete(skill))).toList(),
      ),
    );
  }
}

// Education
class EducationCard extends StatelessWidget {
  final List<Map<String, dynamic>> educationList;
  final VoidCallback onAdd;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;

  const EducationCard({
    super.key,
    required this.educationList,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return buildCardWithAddButton(
      title: "Education",
      icon: Icons.school_outlined,
      onAdd: onAdd,
      child: educationList.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No education added yet. Tap + to add education.", style: TextStyle(color: Colors.grey)),
      )
          : Column(
        children: educationList.map((edu) => EducationItem(education: edu, onEdit: () => onEdit(edu), onDelete: () => onDelete(edu))).toList(),
      ),
    );
  }
}

// Work
class WorkCard extends StatelessWidget {
  final List<Map<String, dynamic>> workList;
  final VoidCallback onAdd;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;

  const WorkCard({
    super.key,
    required this.workList,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return buildCardWithAddButton(
      title: "Work Experience",
      icon: Icons.work_outline,
      onAdd: onAdd,
      child: workList.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No work experience added yet. Tap + to add experience.", style: TextStyle(color: Colors.grey)),
      )
          : Column(
        children: workList.map((work) => WorkItem(work: work, onEdit: () => onEdit(work), onDelete: () => onDelete(work))).toList(),
      ),
    );
  }
}

// Card widget
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
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 22),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
              ],
            ),
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
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 22),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
              ],
            ),
            IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: onAdd, tooltip: 'Add $title'),
          ],
        ),
        const SizedBox(height: 15),
        child,
      ],
    ),
  );
}

// Skill item
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
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }
}

// Education Item
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
    } catch (e) { return dateString; }
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
                    _formatDate(education['start_date']) + (education['end_date'] != null && education['end_date'].toString().isNotEmpty ? ' - ${_formatDate(education['end_date'])}' : ' - Present'),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }
}

// Work Item
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
    } catch (e) { return dateString; }
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
                    _formatDate(work['start_date']) + (work['end_date'] != null && work['end_date'].toString().isNotEmpty ? ' - ${_formatDate(work['end_date'])}' : ' - Present'),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }
}

// Branch Item
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
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }
}

// Add branch bottom sheet
Future<void> showAddBranchBottomSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> branches,
  required String? companyId,
  required bool Function(String) isValidPhone,
  required bool Function(String) isValidEmail,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
  required InputDecoration Function(String, {IconData? icon, String? hintText}) inputDecoration,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
}) async {
  final TextEditingController branchNameCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  bool isHeadOffice = false;
  bool isSaving = false;

  String? branchNameError;
  String? addressError;
  String? phoneError;
  String? emailError;

  String selectedCountry = 'Malaysia';
  String selectedState = '';
  String? selectedCity;
  String selectedPostalCode = '';

  bool hasExistingHeadOffice = branches.any((b) => b['is_head_office'] == true);

  await showModalBottomSheet(
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
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Add Branch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Branch Name *',
                              controller: branchNameCtrl,
                              icon: Icons.business_outlined,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    branchNameError = 'Branch name is required';
                                  } else {
                                    branchNameError = null;
                                  }
                                });
                              },
                            ),
                            if (branchNameError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(branchNameError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Street Address *',
                              controller: addressCtrl,
                              icon: Icons.location_on_outlined,
                              maxLines: 2,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    addressError = 'Street address is required';
                                  } else {
                                    addressError = null;
                                  }
                                });
                              },
                            ),
                            if (addressError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(addressError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Phone',
                              controller: phoneCtrl,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.isNotEmpty && !isValidPhone(value)) {
                                    phoneError = 'Please enter a valid phone number';
                                  } else {
                                    phoneError = null;
                                  }
                                });
                              },
                            ),
                            if (phoneError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(phoneError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Email',
                              controller: emailCtrl,
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.isNotEmpty && !isValidEmail(value)) {
                                    emailError = 'Please enter a valid email address';
                                  } else {
                                    emailError = null;
                                  }
                                });
                              },
                            ),
                            if (emailError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(emailError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: isHeadOffice,
                              onChanged: (value) {
                                if (value == true && hasExistingHeadOffice) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Head Office Exists'),
                                      content: const Text('You already have a head office branch. Setting this branch as head office will unmark the existing one.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            setStateBottom(() => isHeadOffice = true);
                                          },
                                          child: const Text('Proceed'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  setStateBottom(() => isHeadOffice = value ?? false);
                                }
                              },
                            ),
                            const Text('This is the head office'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              setStateBottom(() {
                                branchNameError = null;
                                addressError = null;
                                phoneError = null;
                                emailError = null;
                              });

                              bool isValid = true;

                              if (branchNameCtrl.text.trim().isEmpty) {
                                setStateBottom(() => branchNameError = 'Branch name is required');
                                isValid = false;
                              }
                              if (addressCtrl.text.trim().isEmpty) {
                                setStateBottom(() => addressError = 'Street address is required');
                                isValid = false;
                              }
                              if (selectedState.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Please select a state"), backgroundColor: Colors.red),
                                );
                                isValid = false;
                              }
                              if (hasCities && (selectedCity == null || selectedCity!.isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Please select a city from the list"), backgroundColor: Colors.red),
                                );
                                isValid = false;
                              }

                              final phoneValue = phoneCtrl.text.trim();
                              if (phoneValue.isNotEmpty && !isValidPhone(phoneValue)) {
                                setStateBottom(() => phoneError = 'Please enter a valid phone number');
                                isValid = false;
                              }

                              final emailValue = emailCtrl.text.trim();
                              if (emailValue.isNotEmpty && !isValidEmail(emailValue)) {
                                setStateBottom(() => emailError = 'Please enter a valid email address');
                                isValid = false;
                              }

                              if (!isValid) return;

                              setStateBottom(() => isSaving = true);
                              try {
                                final branchData = {
                                  'branch_name': branchNameCtrl.text.trim(),
                                  'address': addressCtrl.text.trim(),
                                  'city': selectedCity ?? (hasCities ? null : 'N/A'),
                                  'state': selectedState,
                                  'postal_code': selectedPostalCode.isNotEmpty ? selectedPostalCode : null,
                                  'country': selectedCountry,
                                  'phone': phoneValue.isEmpty ? null : phoneValue,
                                  'email': emailValue.isEmpty ? null : emailValue,
                                  'is_head_office': isHeadOffice,
                                };

                                await userRepo.addBranch(companyId!, branchData);
                                await onRefresh();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Branch added successfully!"), backgroundColor: Colors.green),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
                                );
                              } finally {
                                setStateBottom(() => isSaving = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Add Branch', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    ),
  );
}

// Edit branch bottom sheet
Future<void> showEditBranchBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> branch,
  required List<Map<String, dynamic>> branches,
  required bool Function(String) isValidPhone,
  required bool Function(String) isValidEmail,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
  required InputDecoration Function(String, {IconData? icon, String? hintText}) inputDecoration,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
}) async {
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

  bool hasExistingHeadOffice = branches.any((b) => b['branch_id'] != branch['branch_id'] && b['is_head_office'] == true);

  await showModalBottomSheet(
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
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Edit Branch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        buildFormField(label: 'Branch Name *', controller: branchNameCtrl, icon: Icons.business_outlined),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Street Address *', controller: addressCtrl, icon: Icons.location_on_outlined, maxLines: 2),
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
                        buildFormField(label: 'Phone', controller: phoneCtrl, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Email', controller: emailCtrl, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: isHeadOffice,
                              onChanged: (value) {
                                if (value == true && hasExistingHeadOffice) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Head Office Exists'),
                                      content: const Text('You already have another branch marked as head office. Setting this branch as head office will unmark the existing one.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            setStateBottom(() => isHeadOffice = true);
                                          },
                                          child: const Text('Proceed'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  setStateBottom(() => isHeadOffice = value ?? false);
                                }
                              },
                            ),
                            const Text('This is the head office'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
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

                                await userRepo.updateBranch(branch['branch_id'], branchData);
                                await onRefresh();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Branch updated successfully!"), backgroundColor: Colors.green),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
                                );
                              } finally {
                                setStateBottom(() => isSaving = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Update Branch', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    ),
  );
}

// Add skill bottom sheet
Future<void> showAddSkillBottomSheet({
  required BuildContext context,
  required String? userId,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
  required InputDecoration Function(String, {IconData? icon, String? hintText}) inputDecoration,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
}) async {
  final TextEditingController skillNameCtrl = TextEditingController();
  String? selectedLevel;
  bool isSaving = false;

  String? skillNameError;
  String? skillLevelError;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateBottom) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.8,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) => Container(
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
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Add Skill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Skill Name *',
                              controller: skillNameCtrl,
                              icon: Icons.code_outlined,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    skillNameError = 'Skill name is required';
                                  } else {
                                    skillNameError = null;
                                  }
                                });
                              },
                            ),
                            if (skillNameError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(skillNameError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedLevel,
                              decoration: inputDecoration('Skill Level *', icon: Icons.trending_up_outlined),
                              items: const [
                                DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                                DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate')),
                                DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                              ],
                              onChanged: (value) {
                                setStateBottom(() {
                                  selectedLevel = value;
                                  if (value != null && value.isNotEmpty) {
                                    skillLevelError = null;
                                  }
                                });
                              },
                            ),
                            if (skillLevelError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(skillLevelError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              setStateBottom(() {
                                skillNameError = null;
                                skillLevelError = null;
                              });

                              bool isValid = true;

                              if (skillNameCtrl.text.trim().isEmpty) {
                                setStateBottom(() => skillNameError = 'Skill name is required');
                                isValid = false;
                              }
                              if (selectedLevel == null || selectedLevel!.isEmpty) {
                                setStateBottom(() => skillLevelError = 'Please select a skill level');
                                isValid = false;
                              }

                              if (!isValid) return;

                              setStateBottom(() => isSaving = true);
                              await userRepo.addSkill(userId!, skillNameCtrl.text.trim(), selectedLevel);
                              await onRefresh();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Skill added"), backgroundColor: Colors.green),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Add Skill', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    ),
  );
}

// Edit branch bottom sheet
Future<void> showEditSkillBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> skill,
  required String? userId,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
  required InputDecoration Function(String, {IconData? icon, String? hintText}) inputDecoration,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
}) async {
  final TextEditingController skillNameCtrl = TextEditingController(text: skill['skill_name']);
  String? selectedLevel = skill['skill_level'];
  bool isSaving = false;

  String? skillNameError;
  String? skillLevelError;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateBottom) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.8,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) => Container(
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
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Edit Skill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Skill Name *',
                              controller: skillNameCtrl,
                              icon: Icons.code_outlined,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    skillNameError = 'Skill name is required';
                                  } else {
                                    skillNameError = null;
                                  }
                                });
                              },
                            ),
                            if (skillNameError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(skillNameError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedLevel,
                              decoration: inputDecoration('Skill Level *', icon: Icons.trending_up_outlined),
                              items: const [
                                DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                                DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate')),
                                DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                              ],
                              onChanged: (value) {
                                setStateBottom(() {
                                  selectedLevel = value;
                                  if (value != null && value.isNotEmpty) {
                                    skillLevelError = null;
                                  }
                                });
                              },
                            ),
                            if (skillLevelError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(skillLevelError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              setStateBottom(() {
                                skillNameError = null;
                                skillLevelError = null;
                              });

                              bool isValid = true;

                              if (skillNameCtrl.text.trim().isEmpty) {
                                setStateBottom(() => skillNameError = 'Skill name is required');
                                isValid = false;
                              }
                              if (selectedLevel == null || selectedLevel!.isEmpty) {
                                setStateBottom(() => skillLevelError = 'Please select a skill level');
                                isValid = false;
                              }

                              if (!isValid) return;

                              setStateBottom(() => isSaving = true);
                              await userRepo.updateSkill(skill['skill_id'], skillNameCtrl.text.trim(), selectedLevel);
                              await onRefresh();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Skill updated"), backgroundColor: Colors.green),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Update Skill', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    ),
  );
}

// Add education bottom sheet
Future<void> showAddEducationBottomSheet({
  required BuildContext context,
  required String? userId,
  required bool Function(String) isValidDateFormat,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
  required InputDecoration Function(String, {IconData? icon, String? hintText}) inputDecoration,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
}) async {
  final TextEditingController institutionCtrl = TextEditingController();
  final TextEditingController qualificationCtrl = TextEditingController();
  final TextEditingController fieldCtrl = TextEditingController();
  final TextEditingController startDateCtrl = TextEditingController();
  final TextEditingController endDateCtrl = TextEditingController();
  final TextEditingController descriptionCtrl = TextEditingController();
  bool isSaving = false;

  String? institutionError;
  String? qualificationError;
  String? startDateError;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateBottom) {
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
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Add Education', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Institution Name *',
                              controller: institutionCtrl,
                              icon: Icons.school_outlined,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    institutionError = 'Institution name is required';
                                  } else {
                                    institutionError = null;
                                  }
                                });
                              },
                            ),
                            if (institutionError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(institutionError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Qualification *',
                              controller: qualificationCtrl,
                              icon: Icons.verified_outlined,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    qualificationError = 'Qualification is required';
                                  } else {
                                    qualificationError = null;
                                  }
                                });
                              },
                            ),
                            if (qualificationError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(qualificationError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Field of Study', controller: fieldCtrl, icon: Icons.category_outlined),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Start Date *',
                              controller: startDateCtrl,
                              icon: Icons.calendar_today_outlined,
                              hintText: 'YYYY-MM-DD',
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    startDateError = 'Start date is required';
                                  } else if (!isValidDateFormat(value)) {
                                    startDateError = 'Please use YYYY-MM-DD format';
                                  } else {
                                    startDateError = null;
                                  }
                                });
                              },
                            ),
                            if (startDateError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(startDateError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        buildFormField(
                          label: 'End Date',
                          controller: endDateCtrl,
                          icon: Icons.calendar_today_outlined,
                          hintText: 'YYYY-MM-DD (Leave empty if current)',
                        ),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Description', controller: descriptionCtrl, icon: Icons.description_outlined, maxLines: 3),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              setStateBottom(() {
                                institutionError = null;
                                qualificationError = null;
                                startDateError = null;
                              });

                              bool isValid = true;

                              if (institutionCtrl.text.trim().isEmpty) {
                                setStateBottom(() => institutionError = 'Institution name is required');
                                isValid = false;
                              }
                              if (qualificationCtrl.text.trim().isEmpty) {
                                setStateBottom(() => qualificationError = 'Qualification is required');
                                isValid = false;
                              }

                              final startDate = startDateCtrl.text.trim();
                              if (startDate.isEmpty) {
                                setStateBottom(() => startDateError = 'Start date is required');
                                isValid = false;
                              } else if (!isValidDateFormat(startDate)) {
                                setStateBottom(() => startDateError = 'Please use YYYY-MM-DD format');
                                isValid = false;
                              }

                              if (!isValid) return;

                              setStateBottom(() => isSaving = true);
                              await userRepo.addEducation(userId!, {
                                'institution_name': institutionCtrl.text.trim(),
                                'qualification': qualificationCtrl.text.trim(),
                                'field_of_study': fieldCtrl.text.trim(),
                                'start_date': startDate.isEmpty ? null : startDate,
                                'end_date': endDateCtrl.text.trim().isEmpty ? null : endDateCtrl.text.trim(),
                                'description': descriptionCtrl.text.trim(),
                              });
                              await onRefresh();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Education added"), backgroundColor: Colors.green),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Add Education', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    ),
  );
}

// Edit education bottom sheet
Future<void> showEditEducationBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> education,
  required String? userId,
  required bool Function(String) isValidDateFormat,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
  required InputDecoration Function(String, {IconData? icon, String? hintText}) inputDecoration,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
}) async {
  final TextEditingController institutionCtrl = TextEditingController(text: education['institution_name'] ?? '');
  final TextEditingController qualificationCtrl = TextEditingController(text: education['qualification'] ?? '');
  final TextEditingController fieldCtrl = TextEditingController(text: education['field_of_study'] ?? '');
  final TextEditingController startDateCtrl = TextEditingController(text: education['start_date'] ?? '');
  final TextEditingController endDateCtrl = TextEditingController(text: education['end_date'] ?? '');
  final TextEditingController descriptionCtrl = TextEditingController(text: education['description'] ?? '');
  bool isSaving = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateBottom) {
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
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Edit Education', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        buildFormField(label: 'Institution Name', controller: institutionCtrl, icon: Icons.school_outlined),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Qualification', controller: qualificationCtrl, icon: Icons.verified_outlined),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Field of Study', controller: fieldCtrl, icon: Icons.category_outlined),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Start Date', controller: startDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD'),
                        const SizedBox(height: 16),
                        buildFormField(
                          label: 'End Date',
                          controller: endDateCtrl,
                          icon: Icons.calendar_today_outlined,
                          hintText: 'YYYY-MM-DD (Leave empty if current)',
                        ),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Description', controller: descriptionCtrl, icon: Icons.description_outlined, maxLines: 3),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              setStateBottom(() => isSaving = true);
                              await userRepo.updateEducation(education['education_id'], {
                                'institution_name': institutionCtrl.text.trim(),
                                'qualification': qualificationCtrl.text.trim(),
                                'field_of_study': fieldCtrl.text.trim(),
                                'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
                                'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
                                'description': descriptionCtrl.text.trim(),
                              });
                              await onRefresh();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Education updated"), backgroundColor: Colors.green),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Update Education', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    ),
  );
}

// Add work bottom sheet
Future<void> showAddWorkBottomSheet({
  required BuildContext context,
  required String? userId,
  required bool Function(String) isValidDateFormat,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
  required InputDecoration Function(String, {IconData? icon, String? hintText}) inputDecoration,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
}) async {
  final TextEditingController companyCtrl = TextEditingController();
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController startDateCtrl = TextEditingController();
  final TextEditingController endDateCtrl = TextEditingController();
  final TextEditingController descriptionCtrl = TextEditingController();
  bool isSaving = false;

  String? companyError;
  String? titleError;
  String? startDateError;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateBottom) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
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
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Add Work Experience', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Company Name *',
                              controller: companyCtrl,
                              icon: Icons.business_outlined,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    companyError = 'Company name is required';
                                  } else {
                                    companyError = null;
                                  }
                                });
                              },
                            ),
                            if (companyError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(companyError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Job Title *',
                              controller: titleCtrl,
                              icon: Icons.work_outline,
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    titleError = 'Job title is required';
                                  } else {
                                    titleError = null;
                                  }
                                });
                              },
                            ),
                            if (titleError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(titleError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildFormField(
                              label: 'Start Date *',
                              controller: startDateCtrl,
                              icon: Icons.calendar_today_outlined,
                              hintText: 'YYYY-MM-DD',
                              onChanged: (value) {
                                setStateBottom(() {
                                  if (value.trim().isEmpty) {
                                    startDateError = 'Start date is required';
                                  } else if (!isValidDateFormat(value)) {
                                    startDateError = 'Please use YYYY-MM-DD format';
                                  } else {
                                    startDateError = null;
                                  }
                                });
                              },
                            ),
                            if (startDateError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 12),
                                child: Text(startDateError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        buildFormField(
                          label: 'End Date',
                          controller: endDateCtrl,
                          icon: Icons.calendar_today_outlined,
                          hintText: 'YYYY-MM-DD (Leave empty if current)',
                        ),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Description', controller: descriptionCtrl, icon: Icons.description_outlined, maxLines: 3),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              setStateBottom(() {
                                companyError = null;
                                titleError = null;
                                startDateError = null;
                              });

                              bool isValid = true;

                              if (companyCtrl.text.trim().isEmpty) {
                                setStateBottom(() => companyError = 'Company name is required');
                                isValid = false;
                              }
                              if (titleCtrl.text.trim().isEmpty) {
                                setStateBottom(() => titleError = 'Job title is required');
                                isValid = false;
                              }

                              final startDate = startDateCtrl.text.trim();
                              if (startDate.isEmpty) {
                                setStateBottom(() => startDateError = 'Start date is required');
                                isValid = false;
                              } else if (!isValidDateFormat(startDate)) {
                                setStateBottom(() => startDateError = 'Please use YYYY-MM-DD format');
                                isValid = false;
                              }

                              if (!isValid) return;

                              setStateBottom(() => isSaving = true);
                              await userRepo.addExperience(userId!, {
                                'company_name': companyCtrl.text.trim(),
                                'job_title': titleCtrl.text.trim(),
                                'start_date': startDate.isEmpty ? null : startDate,
                                'end_date': endDateCtrl.text.trim().isEmpty ? null : endDateCtrl.text.trim(),
                                'description': descriptionCtrl.text.trim(),
                              });
                              await onRefresh();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Work experience added"), backgroundColor: Colors.green),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Add Experience', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    ),
  );
}

// Edit work bottom sheet
Future<void> showEditWorkBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> work,
  required String? userId,
  required bool Function(String) isValidDateFormat,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
  required InputDecoration Function(String, {IconData? icon, String? hintText}) inputDecoration,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
}) async {
  final TextEditingController companyCtrl = TextEditingController(text: work['company_name'] ?? '');
  final TextEditingController titleCtrl = TextEditingController(text: work['job_title'] ?? '');
  final TextEditingController startDateCtrl = TextEditingController(text: work['start_date'] ?? '');
  final TextEditingController endDateCtrl = TextEditingController(text: work['end_date'] ?? '');
  final TextEditingController descriptionCtrl = TextEditingController(text: work['description'] ?? '');
  bool isSaving = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateBottom) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
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
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Edit Work Experience', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        buildFormField(label: 'Company Name', controller: companyCtrl, icon: Icons.business_outlined),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Job Title', controller: titleCtrl, icon: Icons.work_outline),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Start Date', controller: startDateCtrl, icon: Icons.calendar_today_outlined, hintText: 'YYYY-MM-DD'),
                        const SizedBox(height: 16),
                        buildFormField(
                          label: 'End Date',
                          controller: endDateCtrl,
                          icon: Icons.calendar_today_outlined,
                          hintText: 'YYYY-MM-DD (Leave empty if current)',
                        ),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Description', controller: descriptionCtrl, icon: Icons.description_outlined, maxLines: 3),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              setStateBottom(() => isSaving = true);
                              await userRepo.updateExperience(work['experience_id'], {
                                'company_name': companyCtrl.text.trim(),
                                'job_title': titleCtrl.text.trim(),
                                'start_date': startDateCtrl.text.isEmpty ? null : startDateCtrl.text,
                                'end_date': endDateCtrl.text.isEmpty ? null : endDateCtrl.text,
                                'description': descriptionCtrl.text.trim(),
                              });
                              await onRefresh();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Work experience updated"), backgroundColor: Colors.green),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Update Experience', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    ),
  );
}

// Delete branch , skill , education , experience
Future<void> deleteBranch({
  required BuildContext context,
  required Map<String, dynamic> branch,
  required UserRepository userRepo,
  required Future<void> Function() onRefresh,
}) async {
  // Store the scaffold context before showing dialog
  final scaffoldContext = context;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Delete Branch"),
      content: Text("Are you sure you want to delete '${branch['branch_name']}'?"),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel")
        ),
        TextButton(
          onPressed: () async {
            // Close the dialog first
            Navigator.pop(dialogContext);

            try {
              await userRepo.deleteBranch(branch['branch_id']);
              await onRefresh();

              // Use the scaffold context to show SnackBar
              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  const SnackBar(
                    content: Text("Branch deleted successfully!"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text("Error deleting branch: ${e.toString()}"),
                    backgroundColor: Colors.red,
                  ),
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

Future<void> deleteSkill({
  required BuildContext context,
  required Map<String, dynamic> skill,
  required UserRepository userRepo,
  required Future<void> Function() onRefresh,
}) async {
  final scaffoldContext = context;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Delete Skill"),
      content: Text("Are you sure you want to delete '${skill['skill_name']}'?"),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel")
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);

            try {
              await userRepo.deleteSkill(skill['skill_id']);
              await onRefresh();

              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  const SnackBar(
                    content: Text("Skill deleted successfully!"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text("Error deleting skill: ${e.toString()}"),
                    backgroundColor: Colors.red,
                  ),
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


Future<void> deleteEducation({
  required BuildContext context,
  required Map<String, dynamic> education,
  required UserRepository userRepo,
  required Future<void> Function() onRefresh,
}) async {
  final scaffoldContext = context;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Delete Education"),
      content: const Text("Are you sure you want to delete this education record?"),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel")
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);

            try {
              await userRepo.deleteEducation(education['education_id']);
              await onRefresh();

              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  const SnackBar(
                    content: Text("Education deleted successfully!"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text("Error deleting education: ${e.toString()}"),
                    backgroundColor: Colors.red,
                  ),
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

Future<void> deleteWork({
  required BuildContext context,
  required Map<String, dynamic> work,
  required UserRepository userRepo,
  required Future<void> Function() onRefresh,
}) async {
  final scaffoldContext = context;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Delete Work Experience"),
      content: const Text("Are you sure you want to delete this work experience?"),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel")
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);

            try {
              await userRepo.deleteExperience(work['experience_id']);
              await onRefresh();

              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  const SnackBar(
                    content: Text("Work experience deleted successfully!"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text("Error deleting work experience: ${e.toString()}"),
                    backgroundColor: Colors.red,
                  ),
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

// ==================== EDIT COMPANY INFO BOTTOM SHEET ====================
Future<void> showEditCompanyInfoBottomSheet({
  required BuildContext context,
  required String companyName,
  required String industry,
  required String companySize,
  required String phone,
  required List<Map<String, dynamic>> jobCategories,
  required List<String> companySizeOptions,
  required String? userId,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
  required InputDecoration Function(String, {IconData? icon, String? hintText}) inputDecoration,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
}) async {
  final TextEditingController companyNameCtrl = TextEditingController(text: companyName);
  final TextEditingController phoneCtrl = TextEditingController(text: phone);
  String tempIndustry = industry;
  String tempCompanySize = companySize;
  bool isSaving = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateBottom) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.85,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) => Container(
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
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Edit Company Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        buildFormField(label: 'Company Name', controller: companyNameCtrl, icon: Icons.business_outlined),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Phone Number', controller: phoneCtrl, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),                        const SizedBox(height: 16),
                        if (jobCategories.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: tempIndustry.isNotEmpty ? tempIndustry : null,
                            decoration: inputDecoration('Industry', icon: Icons.category_outlined),
                            items: jobCategories.map<DropdownMenuItem<String>>((category) {
                              return DropdownMenuItem<String>(value: category['name'].toString(), child: Text(category['name'].toString()));
                            }).toList(),
                            onChanged: (value) => setStateBottom(() => tempIndustry = value!),
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: tempCompanySize.isNotEmpty ? tempCompanySize : null,
                          decoration: inputDecoration('Company Size', icon: Icons.people_outline),
                          items: companySizeOptions.map((size) => DropdownMenuItem(value: size, child: Text(size))).toList(),
                          onChanged: (value) => setStateBottom(() => tempCompanySize = value!),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
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
                                if (updates.isNotEmpty) {
                                  await userRepo.updateCompanyProfile(userId!, updates);
                                }
                                // Update phone in users table
                                if (phoneCtrl.text.trim() != phone) {
                                  await userRepo.updateUser(userId!, {'phone': phoneCtrl.text.trim()});
                                }
                                await onRefresh();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Company information updated!"), backgroundColor: Colors.green),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
                                );
                              } finally {
                                setStateBottom(() => isSaving = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    ),
  );
}

// ==================== EDIT COMPANY DESCRIPTION BOTTOM SHEET ====================
Future<void> showEditCompanyDescriptionBottomSheet({
  required BuildContext context,
  required String companyDescription,
  required String? userId,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
}) async {
  final TextEditingController descCtrl = TextEditingController(text: companyDescription);

  await showModalBottomSheet(
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
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Edit Company Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        buildFormField(label: 'Company Description', controller: descCtrl, icon: Icons.description_outlined, maxLines: 8),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              await userRepo.updateCompanyProfile(userId!, {'company_description': descCtrl.text.trim()});
                              await onRefresh();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Company description updated!"), backgroundColor: Colors.green),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Save Description', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
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

// ==================== EDIT PERSONAL INFO BOTTOM SHEET ====================
Future<void> showEditPersonalInfoBottomSheet({
  required BuildContext context,
  required String fullname,
  required String phone,
  required String dateOfBirth,
  required String address,
  required String bio,
  required String gender,
  required String? role,
  required String? userId,
  required Future<void> Function() onRefresh,
  required UserRepository userRepo,
  required Widget Function({required String label, required TextEditingController controller, IconData? icon, String? hintText, int maxLines, TextInputType keyboardType, void Function(String)? onChanged}) buildFormField,
  required Widget Function({required String label, required String? value, required List<String> items, required Function(String?) onChanged, IconData? icon}) buildDropdownField,
}) async {
  final TextEditingController fullnameCtrl = TextEditingController(text: fullname);
  final TextEditingController phoneCtrl = TextEditingController(text: phone);
  final TextEditingController dobCtrl = TextEditingController(text: dateOfBirth);
  final TextEditingController addressCtrl = TextEditingController(text: address);
  final TextEditingController bioCtrl = TextEditingController(text: bio);
  String selectedGender = gender;
  bool isSaving = false;

  await showModalBottomSheet(
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
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Text('Edit Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                        buildFormField(label: 'Full Name', controller: fullnameCtrl, icon: Icons.person_outline),
                        const SizedBox(height: 16),
                        buildFormField(label: 'Phone Number', controller: phoneCtrl, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                        if (role == 'JOB_SEEKER') ...[
                          const SizedBox(height: 16),
                          buildFormField(label: 'Date of Birth', controller: dobCtrl, icon: Icons.cake_outlined, hintText: 'YYYY-MM-DD'),
                          const SizedBox(height: 16),
                          buildDropdownField(
                            label: 'Gender',
                            value: selectedGender,
                            items: const ['Male', 'Female'],
                            onChanged: (value) => setStateBottom(() => selectedGender = value!),
                            icon: Icons.people_outline,
                          ),
                          const SizedBox(height: 16),
                          buildFormField(label: 'Address', controller: addressCtrl, icon: Icons.location_on_outlined, maxLines: 2),
                          const SizedBox(height: 16),
                          buildFormField(label: 'Bio', controller: bioCtrl, icon: Icons.description_outlined, maxLines: 3),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              setStateBottom(() => isSaving = true);
                              await userRepo.updateUser(userId!, {
                                'fullname': fullnameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                              });
                              if (role == 'JOB_SEEKER') {
                                await userRepo.updateJobSeekerProfile(userId!, {
                                  'date_of_birth': dobCtrl.text.isEmpty ? null : dobCtrl.text,
                                  'gender': selectedGender,
                                  'address': addressCtrl.text,
                                  'bio': bioCtrl.text,
                                });
                              }
                              await onRefresh();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
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