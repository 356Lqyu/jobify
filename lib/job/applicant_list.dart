

// lib/job/applicant_list.dart
import 'package:flutter/material.dart';
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
      final applicantsFuture = _appRepo.getApplicantsForJob(widget.jobId);
      final statsFuture = _appRepo.getApplicationStats(widget.jobId);

      final results = await Future.wait([applicantsFuture, statsFuture]);
      final applicants = results[0] as List<Map<String, dynamic>>;
      final stats = results[1] as Map<String, int>;

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.jobTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              '${_stats['total'] ?? 0} applicants',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2563EB),
          tabs: [
            Tab(text: 'Pending (${_pendingApplicants.length})'),
            Tab(text: 'Accepted (${_acceptedApplicants.length})'),
            Tab(text: 'Rejected (${_rejectedApplicants.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applicants.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No applicants yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
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
  final VoidCallback onTap;

  const _ApplicantCard({
    required this.applicant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = applicant['user'] as Map<String, dynamic>;
    final status = applicant['status'] as String;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
              backgroundImage: user['profile_image_url'] != null &&
                  user['profile_image_url'].toString().isNotEmpty
                  ? NetworkImage(user['profile_image_url'])
                  : null,
              child: user['profile_image_url'] == null
                  ? Text(
                _getInitials(user['fullname']),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['fullname'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(applicant['applied_at']),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(status),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
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
