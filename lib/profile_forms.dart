import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        // Add new skill
        await supabase.from('skills').insert({
          'user_id': widget.userId,
          'skill_name': _skillNameCtrl.text.trim(),
          'skill_level': _selectedLevel,
        });
      } else {
        // Update existing skill
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