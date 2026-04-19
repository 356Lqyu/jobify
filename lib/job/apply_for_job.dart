
// lib/job/apply_for_job.dart - Fixed URL and Collapsible Description
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'applicantion_respository.dart';

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
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasApplied = false;
  bool _isDescriptionExpanded = false;
  String? _selectedResumeId;
  String? _selectedResumeUrl;
  String? _selectedResumeName;
  final TextEditingController _coverLetterCtrl = TextEditingController();
  List<Map<String, dynamic>> _userResumes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _coverLetterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _checkExistingApplication(),
      _loadUserResumes(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _checkExistingApplication() async {
    try {
      final existing = await _appRepo.checkExistingApplication(
        widget.job['job_id'],
        widget.userId,
      );
      if (mounted) {
        setState(() => _hasApplied = existing);
      }
    } catch (e) {
      debugPrint('Error checking application: $e');
    }
  }

  Future<void> _loadUserResumes() async {
    try {
      final response = await supabase
          .from('resume')
          .select()
          .eq('user_id', widget.userId)
          .order('uploaded_at', ascending: false);

      setState(() {
        _userResumes = List<Map<String, dynamic>>.from(response);
        if (_userResumes.isNotEmpty) {
          _selectedResumeId = _userResumes.first['resume_id'];
          _selectedResumeUrl = _userResumes.first['file_url'];
          _selectedResumeName = _userResumes.first['file_name'];
        }
      });
    } catch (e) {
      debugPrint('Error loading resumes: $e');
    }
  }

  // Fixed URL handling - trim whitespace and encode properly
  Future<void> _previewResumeInDialog(String url, String fileName) async {
    // Clean the URL - trim whitespace and ensure it's valid
    String cleanUrl = url.trim();

    // Check if URL is valid
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid resume URL format')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ResumePreviewDialog(
        resumeUrl: cleanUrl,
        fileName: fileName,
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (_selectedResumeUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a resume to apply')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _appRepo.applyForJob(
        jobId: widget.job['job_id'],
        userId: widget.userId,
        resumeUrl: _selectedResumeUrl!.trim(),
        coverLetter: _coverLetterCtrl.text.trim().isEmpty
            ? null
            : _coverLetterCtrl.text.trim(),
      );

      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasApplied) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Apply for Job'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'You have already applied',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.job['job_title'] ?? 'for this position',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Apply for Job'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Details Card with Collapsible Description
            _buildJobDetailsCard(),

            const SizedBox(height: 20),

            // Resume Selection Section
            const Text(
              'Select Resume',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_userResumes.isEmpty)
              _buildNoResumesWidget()
            else
              _buildResumeList(),

            const SizedBox(height: 24),

            // Cover Letter Section
            const Text(
              'Cover Letter (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildCoverLetterField(),

            const SizedBox(height: 32),

            // Submit Button
            _buildSubmitButton(),

            const SizedBox(height: 16),

            // Info Note
            _buildInfoNote(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailsCard() {
    final description = widget.job['description'] ?? '';
    final hasLongDescription = description.length > 150;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.job['job_title'] ?? 'Position',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.job['company_name'] ?? 'Company',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Basic Info - Always visible
          _buildDetailRow(Icons.location_on, 'Location', widget.job['location'] ?? 'Not specified'),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.attach_money, 'Salary', _formatSalary(
            widget.job['salary_min'],
            widget.job['salary_max'],
          )),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.access_time, 'Job Type', widget.job['job_type'] ?? 'Full-time'),

          // Description - Collapsible
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.description, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  'Job Description',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                  icon: Icon(_isDescriptionExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: Text(_isDescriptionExpanded ? 'Show Less' : 'Show More'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedCrossFade(
              firstChild: Text(
                description,
                style: const TextStyle(fontSize: 13, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              secondChild: Text(
                description,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              crossFadeState: _isDescriptionExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumeList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: _userResumes.map((resume) {
          final isSelected = _selectedResumeId == resume['resume_id'];
          return InkWell(
            onTap: () {
              setState(() {
                _selectedResumeId = resume['resume_id'];
                _selectedResumeUrl = resume['file_url'];
                _selectedResumeName = resume['file_name'];
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB).withOpacity(0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: resume['resume_id'],
                    groupValue: _selectedResumeId,
                    onChanged: (value) {
                      setState(() {
                        _selectedResumeId = value;
                        _selectedResumeUrl = resume['file_url'];
                        _selectedResumeName = resume['file_name'];
                      });
                    },
                    activeColor: const Color(0xFF2563EB),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resume['file_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Uploaded: ${_formatDate(resume['uploaded_at'])}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.visibility, color: const Color(0xFF2563EB), size: 20),
                      onPressed: () => _previewResumeInDialog(resume['file_url'], resume['file_name']),
                      tooltip: 'Preview Resume',
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoResumesWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No resumes found',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Please upload a resume in your profile first',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.person, size: 18),
            label: const Text('Go to Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverLetterField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _coverLetterCtrl,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: 'Tell the employer why you\'re a good fit...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting || _userResumes.isEmpty ? null : _submitApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Text(
          'Submit Application',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You can withdraw your application before the employer reviews it.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isMultiline = false}) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  String _formatSalary(dynamic min, dynamic max) {
    if (min == null && max == null) return 'Not disclosed';
    if (min != null && max != null) {
      return 'RM ${_formatNumber(min)} - ${_formatNumber(max)}';
    }
    if (min != null) return 'From RM ${_formatNumber(min)}';
    return 'Up to RM ${_formatNumber(max)}';
  }

  String _formatNumber(dynamic value) {
    final num = value is int ? value.toDouble() : value as double;
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(0)}k';
    }
    return num.toStringAsFixed(0);
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}

// Resume Preview Dialog - Fixed URL handling
class ResumePreviewDialog extends StatefulWidget {
  final String resumeUrl;
  final String fileName;

  const ResumePreviewDialog({
    super.key,
    required this.resumeUrl,
    required this.fileName,
  });

  @override
  State<ResumePreviewDialog> createState() => _ResumePreviewDialogState();
}

class _ResumePreviewDialogState extends State<ResumePreviewDialog> {
  bool _isLoading = true;
  File? _pdfFile;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _downloadResume();
  }

  Future<void> _downloadResume() async {
    try {
      final cleanUrl = widget.resumeUrl.trim();
      debugPrint('Downloading resume from: $cleanUrl');

      final response = await http.get(Uri.parse(cleanUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${widget.fileName}');
        await file.writeAsBytes(response.bodyBytes);
        setState(() {
          _pdfFile = file;
          _isLoading = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to download');
      }
    } catch (e) {
      debugPrint('Error downloading resume: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openFullScreen() async {
    if (_pdfFile != null) {
      await OpenFile.open(_pdfFile!.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load resume',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else if (_pdfFile != null)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          size: 80,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'PDF Ready to View',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.fileName,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _openFullScreen,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open Full Screen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Text('Failed to load resume'),
                  ),
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}