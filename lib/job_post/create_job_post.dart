import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jobify/job_post/job_post_service.dart';
import 'package:jobify/social/social_post_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateJobPost extends StatefulWidget {
  final Map<String, dynamic>? existingJob;
  final VoidCallback? onPostSuccess;
  final bool isModal;

  const CreateJobPost({
    super.key,
    this.existingJob,
    this.onPostSuccess,
    this.isModal = false,
  });

  @override
  State<CreateJobPost> createState() => _CreateJobPostState();
}

class _CreateJobPostState extends State<CreateJobPost> {
  final JobPostService _service = JobPostService();
  final _formKey = GlobalKey<FormState>();

  // Controllers for all text fields
  final _videoUrlController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minSalaryController = TextEditingController();
  final _maxSalaryController = TextEditingController();
  final _locationController = TextEditingController();
  final _vacancyController = TextEditingController();

  int _selectedPostType = 1; // 1 = Job Post
  late Map<String, dynamic> _formData;
  bool _isLoading = false;
  bool _isReferenceLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _jobTypes = [];
  List<Map<String, dynamic>> _expLevels = [];
  String? _error;

  Map<String, dynamic>? _selectedCategory;
  Map<String, dynamic>? _selectedJobType;
  Map<String, dynamic>? _selectedExpLevel;

  List<File> _imageFiles = [];
  List<String> _existingImageUrls = [];

  String? _userId;
  Map<String, dynamic>? _companyProfile;

  @override
  void initState() {
    super.initState();
    _initFormData();
    _loadUserAndReferences();
  }

  @override
  void dispose() {
    _videoUrlController.dispose();
    _jobTitleController.dispose();
    _descriptionController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _locationController.dispose();
    _vacancyController.dispose();
    super.dispose();
  }

  void _initFormData() {
    _formData = {
      'job_title': '',
      'description': '',
      'location': '',
      'remote_option': false,
      'salary_min': null,
      'salary_max': null,
      'vacancy_count': 1,
      'status': 'active',
      'application_deadline': null,
      'job_category_id': null,
      'job_type_id': null,
      'experience_level_id': null,
    };

    if (widget.existingJob != null) {
      // Populate controllers from existing job
      _jobTitleController.text = widget.existingJob!['job_title'] ?? '';
      _descriptionController.text = widget.existingJob!['description'] ?? '';
      _locationController.text = widget.existingJob!['location'] ?? '';
      _formData['remote_option'] = widget.existingJob!['remote_option'] ?? false;
      _minSalaryController.text = widget.existingJob!['salary_min']?.toString() ?? '';
      _maxSalaryController.text = widget.existingJob!['salary_max']?.toString() ?? '';
      _vacancyController.text = (widget.existingJob!['vacancy_count'] ?? 1).toString();
      _formData['status'] = widget.existingJob!['status'] ?? 'active';
      _formData['application_deadline'] = widget.existingJob!['application_deadline'];

      final category = widget.existingJob!['job_category_id'];
      _formData['job_category_id'] = category is Map
          ? category['job_category_id'].toString()
          : category?.toString();

      final type = widget.existingJob!['job_type_id'];
      _formData['job_type_id'] = type is Map
          ? type['job_type_id'].toString()
          : type?.toString();

      final level = widget.existingJob!['experience_level_id'];
      _formData['experience_level_id'] = level is Map
          ? level['experience_level_id'].toString()
          : level?.toString();

      _existingImageUrls = List<String>.from(widget.existingJob!['image_urls'] ?? []);
      _videoUrlController.text = widget.existingJob!['video_url'] ?? '';
    }
  }

  void _resetForm() {
    // Clear all text controllers
    _videoUrlController.clear();
    _jobTitleController.clear();
    _descriptionController.clear();
    _minSalaryController.clear();
    _maxSalaryController.clear();
    _locationController.clear();
    _vacancyController.text = '1';

    // Reset dropdown selections to first item
    _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
    _selectedJobType = _jobTypes.isNotEmpty ? _jobTypes.first : null;
    _selectedExpLevel = _expLevels.isNotEmpty ? _expLevels.first : null;

    // Clear images
    _imageFiles.clear();
    _existingImageUrls.clear();

    _formData = {
      'job_title': '',
      'description': '',
      'location': '',
      'remote_option': false,
      'salary_min': null,
      'salary_max': null,
      'vacancy_count': 1,
      'status': 'active',
      'application_deadline': null,
      'job_category_id': _selectedCategory?['job_category_id'],
      'job_type_id': _selectedJobType?['job_type_id'],
      'experience_level_id': _selectedExpLevel?['experience_level_id'],
    };

  }

  // ─── Validators ────────────────────────────────────────────────────────────
  String? _validateSalaryMin(String? value) {
    if (value == null || value.isEmpty) return null;
    final num = int.tryParse(value);
    if (num == null) return 'Must be a number';
    if (num < 0) return 'Must be positive';
    return null;
  }

  String? _validateSalaryMax(String? value) {
    if (value == null || value.isEmpty) return null;
    final num = int.tryParse(value);
    if (num == null) return 'Must be a number';
    if (num < 0) return 'Must be positive';
    final minStr = _minSalaryController.text;
    if (minStr.isNotEmpty) {
      final min = int.tryParse(minStr);
      if (min != null && num < min) return 'Max salary must be ≥ Min salary';
    }
    return null;
  }

  String? _validateVacancyCount(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final num = int.tryParse(value);
    if (num == null) return 'Must be a number';
    if (num < 1) return 'Must be at least 1';
    return null;
  }

  // ─── Load references ───────────────────────────────────────────────────────
  Future<void> _loadUserAndReferences() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) {
        setState(() {
          _error = "No active session. Please log in again.";
          _isReferenceLoading = false;
        });
        return;
      }

      _userId = session.user.id;
      final company = await _service.fetchMyCompanyProfile(userId: _userId);
      final categories = await _service.fetchJobCategories();
      final types = await _service.fetchJobTypes();
      final levels = await _service.fetchExperienceLevels();

      if (categories.isEmpty || types.isEmpty || levels.isEmpty) {
        setState(() {
          _error = "Reference data missing. Please check your database.";
          _isReferenceLoading = false;
        });
        return;
      }

      setState(() {
        _companyProfile = company;
        _categories = categories;
        _jobTypes = types;
        _expLevels = levels;

        if (widget.existingJob != null) {
          final targetCatId = _formData['job_category_id'];
          if (targetCatId != null) {
            _selectedCategory = _categories.firstWhere(
                  (c) => c['job_category_id'].toString() == targetCatId,
              orElse: () => _categories.first,
            );
          } else {
            _selectedCategory = _categories.first;
          }

          final targetTypeId = _formData['job_type_id'];
          if (targetTypeId != null) {
            _selectedJobType = _jobTypes.firstWhere(
                  (t) => t['job_type_id'].toString() == targetTypeId,
              orElse: () => _jobTypes.first,
            );
          } else {
            _selectedJobType = _jobTypes.first;
          }

          final targetLevelId = _formData['experience_level_id'];
          if (targetLevelId != null) {
            _selectedExpLevel = _expLevels.firstWhere(
                  (l) => l['experience_level_id'].toString() == targetLevelId,
              orElse: () => _expLevels.first,
            );
          } else {
            _selectedExpLevel = _expLevels.first;
          }
        } else {
          _selectedCategory = _categories.first;
          _selectedJobType = _jobTypes.first;
          _selectedExpLevel = _expLevels.first;
        }

        _formData['job_category_id'] = _selectedCategory?['job_category_id'];
        _formData['job_type_id'] = _selectedJobType?['job_type_id'];
        _formData['experience_level_id'] = _selectedExpLevel?['experience_level_id'];

        _isReferenceLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load data: $e";
        _isReferenceLoading = false;
      });
    }
  }

  // ─── Image upload ─────────────────────────────────────────────────────────
  Future<List<String>> _uploadImages() async {
    final List<String> uploadedUrls = [];
    final supabase = Supabase.instance.client;
    for (final file in _imageFiles) {
      final fileName = 'job_img_${DateTime.now().millisecondsSinceEpoch}_${file.path.hashCode}.jpg';
      final path = 'job_images/$fileName';
      await supabase.storage.from('job_gallery').upload(path, file);
      final url = supabase.storage.from('job_gallery').getPublicUrl(path);
      uploadedUrls.add(url);
    }
    return uploadedUrls;
  }

  // ─── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Gather data from controllers
    _formData['job_title'] = _jobTitleController.text.trim();
    _formData['description'] = _descriptionController.text.trim();
    _formData['location'] = _locationController.text.trim();
    _formData['salary_min'] = int.tryParse(_minSalaryController.text);
    _formData['salary_max'] = int.tryParse(_maxSalaryController.text);
    _formData['vacancy_count'] = int.tryParse(_vacancyController.text) ?? 1;
    _formData['job_category_id'] = _selectedCategory?['job_category_id'];
    _formData['job_type_id'] = _selectedJobType?['job_type_id'];
    _formData['experience_level_id'] = _selectedExpLevel?['experience_level_id'];

    setState(() => _isLoading = true);

    if (_userId == null || _companyProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing user or company profile.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (_formData['job_category_id'] == null ||
        _formData['job_type_id'] == null ||
        _formData['experience_level_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required dropdown fields.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final newImageUrls = await _uploadImages();
    final allImageUrls = [..._existingImageUrls, ...newImageUrls];

    final data = {
      ..._formData,
      'company_id': _companyProfile!['company_id'],
      'created_by': _userId,
      'image_urls': allImageUrls.isEmpty ? null : allImageUrls,
      'video_url': _videoUrlController.text.trim().isEmpty ? null : _videoUrlController.text.trim(),
    };

    try {
      if (widget.existingJob != null) {
        final jobId = widget.existingJob!['job_id'].toString();
        final updatedCount = await _service.updateJobPost(jobId, data);
        if (updatedCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update failed: job not found.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job updated')),
          );
        }
      } else {
        await _service.createJobPost(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job published')),
        );
        _resetForm();
      }

      if (widget.onPostSuccess != null) {
        widget.onPostSuccess!();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isReferenceLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    final totalImages = _imageFiles.length + _existingImageUrls.length;
    final canAddMore = totalImages < 5;

    // Modal mode (no AppBar, with handle & header)
    if (widget.isModal) {
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
                  const Text('Create Job Post',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Publish', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildJobPostForm(totalImages, canAddMore),
              ),
            ),
          ],
        ),
      );
    }

    // Full screen mode (with toggle buttons)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildToggleButton('Company Update', 0),
                const SizedBox(width: 12),
                _buildToggleButton('Job Post', 1),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _selectedPostType == 1
                  ? _buildJobPostForm(totalImages, canAddMore)
                  : _buildCompanyUpdateSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, int index) {
    final isSelected = _selectedPostType == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPostType = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyUpdateSection() {
    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.business_center, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text('Company Update', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Share news, announcements, or updates about your company.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SocialPostBottomSheet(
                        userId: _userId!,
                        authorName: _companyProfile?['company_name'] ?? 'Company',
                        authorAvatarUrl: _companyProfile?['logo_url'],
                      ),
                    );
                    if (widget.onPostSuccess != null) widget.onPostSuccess!();
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Create Company Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Job Post Form (core) ────────────────────────────────────────────────
  Widget _buildJobPostForm(int totalImages, bool canAddMore) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Images (unchanged)
              const Text('Images (max 5, first is cover)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._imageFiles.map((file) => Stack(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover)),
                      Positioned(
                        right: 0, top: 0,
                        child: InkWell(onTap: () => setState(() => _imageFiles.remove(file)), child: const Icon(Icons.cancel, color: Colors.red, size: 20)),
                      ),
                    ],
                  )),
                  ..._existingImageUrls.map((url) => Stack(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover)),
                      Positioned(
                        right: 0, top: 0,
                        child: InkWell(onTap: () => setState(() => _existingImageUrls.remove(url)), child: const Icon(Icons.cancel, color: Colors.red, size: 20)),
                      ),
                    ],
                  )),
                  if (canAddMore)
                    GestureDetector(
                      onTap: () async {
                        final result = await FilePicker.pickFiles(type: FileType.image, allowMultiple: true);
                        if (result != null) {
                          final newFiles = result.paths.map((p) => File(p!)).toList();
                          if (totalImages + newFiles.length <= 5) {
                            setState(() => _imageFiles.addAll(newFiles));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 images allowed')));
                          }
                        }
                      },
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Video URL
              _buildTextField(
                controller: _videoUrlController,
                label: 'Video URL',
                hintText: 'Paste YouTube or Vimeo link (optional)',
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Job Title
              _buildTextField(
                controller: _jobTitleController,
                label: 'Job Title *',
                hintText: 'e.g. Senior Flutter Developer',
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              _buildTextField(
                controller: _descriptionController,
                label: 'Job Description *',
                hintText: 'Describe the role, responsibilities, and requirements...',
                maxLines: 5,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Salary Row
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _minSalaryController,
                      label: 'Min Salary (MYR)',
                      hintText: 'e.g. 3000',
                      keyboardType: TextInputType.number,
                      validator: _validateSalaryMin,
                      onChanged: (_) => _formKey.currentState?.validate(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _maxSalaryController,
                      label: 'Max Salary (MYR)',
                      hintText: 'e.g. 5000',
                      keyboardType: TextInputType.number,
                      validator: _validateSalaryMax,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location
              _buildTextField(
                controller: _locationController,
                label: 'Location *',
                hintText: 'e.g. Kuala Lumpur, Remote, Hybrid',
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: _inputDecoration('Job Category *', hintText: 'Select category'),
                value: _selectedCategory,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c['name']))).toList(),
                onChanged: (v) => setState(() {
                  _selectedCategory = v;
                  _formData['job_category_id'] = v?['job_category_id'];
                }),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Job Type dropdown
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: _inputDecoration('Job Type *', hintText: 'Select job type'),
                value: _selectedJobType,
                items: _jobTypes.map((t) => DropdownMenuItem(value: t, child: Text(t['name']))).toList(),
                onChanged: (v) => setState(() {
                  _selectedJobType = v;
                  _formData['job_type_id'] = v?['job_type_id'];
                }),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Experience Level dropdown
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: _inputDecoration('Experience Level *', hintText: 'Select level'),
                value: _selectedExpLevel,
                items: _expLevels.map((l) => DropdownMenuItem(value: l, child: Text(l['name']))).toList(),
                onChanged: (v) => setState(() {
                  _selectedExpLevel = v;
                  _formData['experience_level_id'] = v?['experience_level_id'];
                }),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Remote option
              Row(
                children: [
                  Checkbox(
                    value: _formData['remote_option'],
                    onChanged: (v) => setState(() => _formData['remote_option'] = v ?? false),
                  ),
                  const Text('Remote option available'),
                ],
              ),
              const SizedBox(height: 16),

              // Vacancy count
              _buildTextField(
                controller: _vacancyController,
                label: 'Number of vacancies',
                hintText: 'e.g. 3',
                keyboardType: TextInputType.number,
                validator: _validateVacancyCount,
              ),
              const SizedBox(height: 16),

              // Deadline picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Application Deadline'),
                subtitle: Text(
                  _formData['application_deadline'] != null
                      ? _formData['application_deadline'].toString().split('T')[0]
                      : 'Not set',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _formData['application_deadline'] = date.toIso8601String());
                  }
                },
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.existingJob == null ? 'Publish Job' : 'Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: consistent text field (always uses a controller)
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label, hintText: hintText),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String label, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey.shade50,
      errorMaxLines: 3,
      errorStyle: const TextStyle(fontSize: 12, height: 1.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade500),
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
}