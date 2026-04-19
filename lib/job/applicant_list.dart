// lib/job/applicant_list.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'applicantion_respository.dart';
import 'applicantion_details.dart';

class ApplicantListPage extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const ApplicantListPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<ApplicantListPage> createState() => _ApplicantListPageState();
}

class _ApplicantListPageState extends State<ApplicantListPage>
    with SingleTickerProviderStateMixin {
  final ApplicationRepository _appRepo = ApplicationRepository();
  late TabController _tabController;

  List<Map<String, dynamic>> _applicants = [];
  bool _isLoading = true;
  Map<String, int> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final applicants = await _appRepo.getApplicantsForJob(widget.jobId);
      final stats = await _appRepo.getApplicationStats(widget.jobId);

      setState(() {
        _applicants = applicants;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading applicants: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _pendingApplicants =>
      _applicants.where((a) => a['status'] == 'pending').toList();

  List<Map<String, dynamic>> get _acceptedApplicants =>
      _applicants.where((a) => a['status'] == 'accepted').toList();

  List<Map<String, dynamic>> get _rejectedApplicants =>
      _applicants.where((a) => a['status'] == 'rejected').toList();

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingApplicants.length;
    final acceptedCount = _acceptedApplicants.length;
    final rejectedCount = _rejectedApplicants.length;
    final totalCount = _stats['total'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Applicants',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatusTab('Pending', pendingCount, 0, Colors.orange),
                const SizedBox(width: 8),
                _buildStatusTab('Accepted', acceptedCount, 1, Colors.green),
                const SizedBox(width: 8),
                _buildStatusTab('Rejected', rejectedCount, 2, Colors.red),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applicants.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No applicants yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your job posting to attract candidates',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildApplicantList(_pendingApplicants),
          _buildApplicantList(_acceptedApplicants),
          _buildApplicantList(_rejectedApplicants),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, int count, int index, Color color) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? color : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicantList(List<Map<String, dynamic>> applicants) {
    if (applicants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No applicants in this category',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: applicants.length,
        itemBuilder: (context, index) {
          final applicant = applicants[index];
          return _ApplicantCard(
            applicant: applicant,
            jobTitle: widget.jobTitle,
            onTap: () => _navigateToDetail(applicant),
          );
        },
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> applicant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplicantDetailPage(
          applicationId: applicant['application_id'],
          jobId: widget.jobId,
          applicant: applicant,
          onStatusChanged: _loadData,
        ),
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  final Map<String, dynamic> applicant;
  final String jobTitle;
  final VoidCallback onTap;

  const _ApplicantCard({
    required this.applicant,
    required this.jobTitle,
    required this.onTap,
  });

  void _previewResume(BuildContext context, String url, String fileName) {
    if (url.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => ResumePreviewDialog(
          resumeUrl: url,
          fileName: fileName,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No resume available')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'accepted':
        return 'ACCEPTED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = applicant['user'] as Map<String, dynamic>;
    final status = applicant['status'] as String;
    final statusColor = _getStatusColor(status);
    final appliedAt = DateTime.tryParse(applicant['applied_at'] ?? '');
    final appliedDate = appliedAt != null
        ? '${appliedAt.day}/${appliedAt.month}/${appliedAt.year}'
        : 'Unknown';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blue Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['fullname'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          jobTitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          user['email'] ?? '',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Applied Date
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        'Applied: $appliedDate',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  // Resume Button
                  if (applicant['resume_url'] != null && applicant['resume_url'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _previewResume(
                        context,
                        applicant['resume_url'],
                        applicant['resume_file_name'] ?? 'Resume.pdf',
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf, size: 16, color: Colors.red.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'View Resume',
                              style: TextStyle(
                                color: const Color(0xFF2563EB),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // View Details Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          color: const Color(0xFF2563EB),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16, color: const Color(0xFF2563EB)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// Resume Preview Dialog
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
      await OpenFilex.open(_pdfFile!.path);
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
                    child: Center(
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