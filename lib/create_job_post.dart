import 'package:flutter/material.dart';
import 'package:jobify/job_post_service.dart';
import 'package:provider/provider.dart';
import 'package:jobify/user_provider.dart';

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
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _jobTypes = [];
  List<Map<String, dynamic>> _expLevels = [];

  @override
  void initState() {
    super.initState();
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
    }
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    final categories = await _service.fetchJobCategories();
    final types = await _service.fetchJobTypes();
    final levels = await _service.fetchExperienceLevels();
    setState(() {
      _categories = categories;
      _jobTypes = types;
      _expLevels = levels;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    final company = await _service.fetchMyCompanyProfile();
    if (company == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company profile not found. Please complete your company profile first.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final data = {
      ..._formData,
      'company_id': company['company_id'],
      'created_by': userId,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingJob == null ? 'Post a New Job' : 'Edit Job'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _categories.isEmpty || _jobTypes.isEmpty || _expLevels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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