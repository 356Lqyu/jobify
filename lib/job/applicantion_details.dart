// lib/job/applicantion_details.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'applicantion_respository.dart';
import 'applicantion_status.dart';

class ApplicantDetailPage extends StatefulWidget {
  final String applicationId;
  final String jobId;
  final Map<String, dynamic> applicant;
  final VoidCallback onStatusChanged;

  const ApplicantDetailPage({
    super.key,
    required this.applicationId,
    required this.jobId,
    required this.applicant,
    required this.onStatusChanged,
  });

  @override
  State<ApplicantDetailPage> createState() => _ApplicantDetailPageState();
}

class _ApplicantDetailPageState extends State<ApplicantDetailPage> {
  final ApplicationRepository _appRepo = ApplicationRepository();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.applicant['user'] as Map<String, dynamic>;
    final status = widget.applicant['status'] as String;
    final appliedAt = DateTime.tryParse(widget.applicant['applied_at'] ?? '');
    final updatedAt = DateTime.tryParse(widget.applicant['updated_at'] ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(user['fullname'] ?? 'Applicant Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          if (status == 'pending')
            PopupMenuButton<String>(
              onSelected: (value) => _showStatusDialog(value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'accepted',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Accept Application'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'rejected',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Reject Application'),
                    ],
                  ),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('Actions'),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ApplicationStatusTimeline(
              currentStatus: status,
              appliedAt: appliedAt,
              updatedAt: updatedAt,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
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
                  const Text(
                    'Applicant Information',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.person,
                    'Full Name',
                    user['fullname'] ?? 'Not provided',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.email,
                    'Email',
                    user['email'] ?? 'Not provided',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.phone,
                    'Phone',
                    user['phone'] ?? 'Not provided',
                  ),
                  const SizedBox(height: 12),
                  if (user['date_of_birth'] != null && user['date_of_birth'].toString().isNotEmpty)
                    _buildInfoRow(
                      Icons.cake,
                      'Date of Birth',
                      user['date_of_birth'],
                    ),
                  const SizedBox(height: 12),
                  if (user['gender'] != null && user['gender'].toString().isNotEmpty)
                    _buildInfoRow(
                      Icons.person_outline,
                      'Gender',
                      user['gender'],
                    ),
                  const SizedBox(height: 12),
                  if (user['address'] != null && user['address'].toString().isNotEmpty)
                    _buildInfoRow(
                      Icons.location_on,
                      'Address',
                      user['address'],
                    ),
                  const SizedBox(height: 12),
                  if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                    _buildInfoRow(
                      Icons.description,
                      'Bio',
                      user['bio'],
                      isMultiline: true,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
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
                  const Text(
                    'Resume',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf,
                              color: Colors.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.applicant['resume_file_name'] ??
                                    'Resume',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Uploaded: ${_formatDate(widget.applicant['applied_at'])}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _openResume,
                          icon: const Icon(Icons.open_in_new,
                              color: Color(0xFF2563EB)),
                          tooltip: 'Open Resume',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : () => _updateStatus('rejected'),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _updateStatus('accepted'),
                      icon: const Icon(Icons.check),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isMultiline = false}) {
    return Row(
      crossAxisAlignment:
      isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Future<void> _openResume() async {
    final resumeUrl = widget.applicant['resume_url'];
    if (resumeUrl != null && resumeUrl.toString().isNotEmpty) {
      final url = Uri.parse(resumeUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open resume')),
          );
        }
      }
    }
  }

  void _showStatusDialog(String newStatus) {
    final isAccept = newStatus == 'accepted';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAccept ? 'Accept Application' : 'Reject Application'),
        content: Text(
          isAccept
              ? 'Are you sure you want to accept this application? The applicant will be notified.'
              : 'Are you sure you want to reject this application? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(newStatus);
            },
            style: TextButton.styleFrom(
              foregroundColor: isAccept ? Colors.green : Colors.red,
            ),
            child: Text(isAccept ? 'Accept' : 'Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isProcessing = true);

    final success = await _appRepo.updateApplicationStatus(
      applicationId: widget.applicationId,
      newStatus: newStatus,
    );

    if (mounted) {
      setState(() => _isProcessing = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'accepted'
                  ? 'Application accepted successfully'
                  : 'Application rejected',
            ),
            backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.red,
          ),
        );
        widget.onStatusChanged();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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