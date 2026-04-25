import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jobify/data/applicantion_respository.dart';

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

    final isPending = status == 'pending';
    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';

    Color getStatusColor() {
      if (isPending) return Colors.orange;
      if (isAccepted) return Colors.green;
      if (isRejected) return Colors.red;
      return Colors.grey;
    }

    String getStatusText() {
      if (isPending) return 'PENDING';
      if (isAccepted) return 'ACCEPTED';
      if (isRejected) return 'REJECTED';
      return status.toUpperCase();
    }

    String getStatusLabel() {
      if (isPending) return 'Under Review';
      if (isAccepted) return 'Application Accepted';
      if (isRejected) return 'Application Declined';
      return status.toUpperCase();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Applicant Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: true,

      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    getStatusColor().withOpacity(0.15),
                    getStatusColor().withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: getStatusColor().withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: getStatusColor().withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isPending ? Icons.access_time :
                      isAccepted ? Icons.check_circle : Icons.cancel,
                      color: getStatusColor(),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getStatusLabel(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: getStatusColor(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Applied on ${_formatDate(widget.applicant['applied_at'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: getStatusColor().withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      getStatusText(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Timeline Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Application Timeline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTimelineStep(
                    stepNumber: 1,
                    title: 'Application Submitted',
                    date: appliedAt,
                    isCompleted: true,
                    isLast: false,
                  ),
                  _buildTimelineStep(
                    stepNumber: 2,
                    title: 'Under Review',
                    date: isPending ? null : appliedAt,
                    isCompleted: !isPending,
                    isLast: false,
                  ),
                  _buildTimelineStep(
                    stepNumber: 3,
                    title: 'Final Decision',
                    date: isAccepted || isRejected ? updatedAt : null,
                    isCompleted: isAccepted || isRejected,
                    isLast: true,
                    customColor: isAccepted ? Colors.green : isRejected ? Colors.red : null,
                    customIcon: isAccepted ? Icons.check_circle : isRejected ? Icons.cancel : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Applicant Information Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Applicant Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    Icons.person,
                    'Full Name',
                    user['fullname'] ?? 'Not provided',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.email,
                    'Email',
                    user['email'] ?? 'Not provided',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.phone,
                    'Phone',
                    user['phone'] ?? 'Not provided',
                  ),
                  if (user['date_of_birth'] != null && user['date_of_birth'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.cake,
                      'Date of Birth',
                      user['date_of_birth'],
                    ),
                  ],
                  if (user['gender'] != null && user['gender'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.person_outline,
                      'Gender',
                      user['gender'],
                    ),
                  ],
                  if (user['address'] != null && user['address'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.location_on,
                      'Address',
                      user['address'],
                    ),
                  ],
                  if (user['bio'] != null && user['bio'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.description,
                      'Bio',
                      user['bio'],
                      isMultiline: true,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Resume Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Resume',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _openResume,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.applicant['resume_file_name'] ?? 'Resume.pdf',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.open_in_new,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : () => _updateStatus('rejected'),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _updateStatus('accepted'),
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
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

  Widget _buildTimelineStep({
    required int stepNumber,
    required String title,
    required DateTime? date,
    required bool isCompleted,
    required bool isLast,
    Color? customColor,
    IconData? customIcon,
  }) {
    final color = customColor ?? (isCompleted ? const Color(0xFF2563EB) : Colors.grey.shade400);
    final icon = customIcon ?? (isCompleted ? Icons.check_circle : Icons.access_time);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? const Color(0xFF1E293B) : Colors.grey.shade500,
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 8, bottom: 8),
            child: Container(
              width: 2,
              height: 30,
              color: isCompleted ? color.withOpacity(0.5) : Colors.grey.shade300,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isMultiline = false}) {
    return Row(
      crossAxisAlignment:
      isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
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
            const SnackBar(
              content: Text('Could not open resume'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No resume available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showStatusDialog(String newStatus) {
    final isAccept = newStatus == 'accepted';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isAccept ? Icons.check_circle : Icons.cancel,
              color: isAccept ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              isAccept ? 'Accept Application' : 'Reject Application',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isAccept
              ? 'Are you sure you want to accept this application? The applicant will be notified.'
              : 'Are you sure you want to reject this application? This action cannot be undone.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(newStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAccept ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
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
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        widget.onStatusChanged();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,

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

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}