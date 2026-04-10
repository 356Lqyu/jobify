import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jobify/job_post_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateJobPost extends StatefulWidget {
  final Map<String, dynamic>? existingJob;
  const CreateJobPost({super.key, this.existingJob});

  @override
  State<CreateJobPost> createState() => _CreateJobPostState();
}

class _CreateJobPostState extends State<CreateJobPost> {
  final JobPostService _service = JobPostService();
  final _formKey = GlobalKey<FormState>();

  late Map<String, dynamic> _formData;
  bool _isLoading = false;
  bool _isReferenceLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _jobTypes = [];
  List<Map<String, dynamic>> _expLevels = [];
  String? _error;

  // Images (0 to 5)
  List<File> _imageFiles = [];
  List<String> _existingImageUrls = [];

  // Video URL
  final TextEditingController _videoUrlController = TextEditingController();

  String? _userId;
  Map<String, dynamic>? _companyProfile;

  @override
  void initState() {
    super.initState();
    _initFormData();
    _loadUserAndReferences();
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
      _formData = Map.from(widget.existingJob!);
      _existingImageUrls = List<String>.from(widget.existingJob!['image_urls'] ?? []);
      _videoUrlController.text = widget.existingJob!['video_url'] ?? '';
    }
  }

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
      setState(() => _companyProfile = company);
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
        _categories = categories;
        _jobTypes = types;
        _expLevels = levels;
        _isReferenceLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load data: $e";
        _isReferenceLoading = false;
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    final List<String> uploadedUrls = [];
    final supabase = Supabase.instance.client;
    for (final file in _imageFiles) {
      final fileName = 'job_img_${DateTime.now().millisecondsSinceEpoch}_${file.path.hashCode}.jpg';
      final path = 'job_images/$fileName';
      await supabase.storage.from('job_images').upload(path, file);
      final url = supabase.storage.from('job_images').getPublicUrl(path);
      uploadedUrls.add(url);
    }
    return uploadedUrls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    if (_userId == null || _companyProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing user or company profile.')),
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
        await _service.updateJobPost(widget.existingJob!['job_id'], data);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job updated')));
      } else {
        await _service.createJobPost(data);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job published')));
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingJob == null ? 'Post a New Job' : 'Edit Job'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Images (max 5, first is cover)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._imageFiles.map((file) => Stack(
                    children: [
                      Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
                      Positioned(
                        right: 0,
                        child: InkWell(
                          onTap: () => setState(() => _imageFiles.remove(file)),
                          child: const Icon(Icons.cancel, color: Colors.red),
                        ),
                      ),
                    ],
                  )),
                  ..._existingImageUrls.map((url) => Stack(
                    children: [
                      Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                      Positioned(
                        right: 0,
                        child: InkWell(
                          onTap: () => setState(() => _existingImageUrls.remove(url)),
                          child: const Icon(Icons.cancel, color: Colors.red),
                        ),
                      ),
                    ],
                  )),
                  if (canAddMore)
                    GestureDetector(
                      onTap: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.image,
                          allowMultiple: true,
                        );
                        if (result != null) {
                          final newFiles = result.paths.map((p) => File(p!)).toList();
                          if (totalImages + newFiles.length <= 5) {
                            setState(() => _imageFiles.addAll(newFiles));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Maximum 5 images allowed')),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.add_photo_alternate),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _videoUrlController,
                decoration: const InputDecoration(labelText: 'Video URL (YouTube, Vimeo, etc.)'),
              ),
              const SizedBox(height: 24),
              // ... rest of the form (job title, description, salary, etc.) unchanged
              TextFormField(
                initialValue: _formData['job_title'],
                decoration: const InputDecoration(labelText: 'Job Title *'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
                onSaved: (v) => _formData['job_title'] = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _formData['description'],
                decoration: const InputDecoration(labelText: 'Job Description *'),
                maxLines: 5,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
                onSaved: (v) => _formData['description'] = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData['salary_min']?.toString(),
                      decoration: const InputDecoration(labelText: 'Min Salary (MYR)'),
                      keyboardType: TextInputType.number,
                      onSaved: (v) => _formData['salary_min'] = int.tryParse(v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData['salary_max']?.toString(),
                      decoration: const InputDecoration(labelText: 'Max Salary (MYR)'),
                      keyboardType: TextInputType.number,
                      onSaved: (v) => _formData['salary_max'] = int.tryParse(v ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _formData['location'],
                decoration: const InputDecoration(labelText: 'Location *'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
                onSaved: (v) => _formData['location'] = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: 'Job Category *'),
                value: _categories.firstWhere(
                      (c) => c['job_category_id'] == _formData['job_category_id'],
                  orElse: () => _categories.first,
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c['name']))).toList(),
                onChanged: (v) => setState(() => _formData['job_category_id'] = v?['job_category_id']),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: 'Job Type *'),
                value: _jobTypes.firstWhere(
                      (t) => t['job_type_id'] == _formData['job_type_id'],
                  orElse: () => _jobTypes.first,
                ),
                items: _jobTypes.map((t) => DropdownMenuItem(value: t, child: Text(t['name']))).toList(),
                onChanged: (v) => setState(() => _formData['job_type_id'] = v?['job_type_id']),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: 'Experience Level *'),
                value: _expLevels.firstWhere(
                      (l) => l['experience_level_id'] == _formData['experience_level_id'],
                  orElse: () => _expLevels.first,
                ),
                items: _expLevels.map((l) => DropdownMenuItem(value: l, child: Text(l['name']))).toList(),
                onChanged: (v) => setState(() => _formData['experience_level_id'] = v?['experience_level_id']),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _formData['remote_option'],
                    onChanged: (v) => setState(() => _formData['remote_option'] = v ?? false),
                  ),
                  const Text('Remote option available'),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _formData['vacancy_count'].toString(),
                decoration: const InputDecoration(labelText: 'Number of vacancies'),
                keyboardType: TextInputType.number,
                onSaved: (v) => _formData['vacancy_count'] = int.tryParse(v ?? '1') ?? 1,
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Application Deadline'),
                subtitle: Text(_formData['application_deadline'] != null
                    ? _formData['application_deadline'].toString().split(' ')[0]
                    : 'Not set'),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
}