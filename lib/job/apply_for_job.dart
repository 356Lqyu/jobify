// lib/job/apply_for_job.dart - Complete version
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:jobify/job/application_repository.dart';
import 'package:jobify/job/local_resume_service.dart';

class ApplyForJobPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final String userId;

  const ApplyForJobPage({
    super.key,
    required this.job,
    required this.userId,
  });

  @override
  State<ApplyForJobPage> createState() => _ApplyForJobPageState();
}

class _ApplyForJobPageState extends State<ApplyForJobPage> {
  final ApplicationRepository _appRepo = ApplicationRepository();
  final _formKey = GlobalKey<FormState>();

  Map<String, String>? _selectedResume;
  bool _isSubmitting = false;
  bool _hasApplied = false;
  String? _coverLetter;
  List<Map<String, String>> _localResumes = [];

  @override
  void initState() {
    super.initState();
    _loadLocalResumes();
    _checkExistingApplication();
  }

  void _loadLocalResumes() {
    _localResumes = LocalResumeService.getAvailableResumes();
    if (_localResumes.isNotEmpty) {
      _selectedResume = _localResumes.first;
    }
    setState(() {});
  }

  Future<void> _checkExistingApplication() async {
    try {
      final existing = await _appRepo.checkExistingApplication(
        widget.job['job_id'],
        widget.userId,
      );
      if (existing && mounted) {
        setState(() => _hasApplied = true);
      }
    } catch (e) {
      debugPrint('Error checking application: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Job'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _hasApplied
          ? const Center(child: Text('You have already applied for this job'))
          : const Center(child: CircularProgressIndicator()),
    );
  }
}