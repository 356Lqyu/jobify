
// lib/job/my_applications.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'applicantion_respository.dart';
import 'applicantion_status.dart';

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ApplicationRepository _appRepo = ApplicationRepository();
  late TabController _tabController;

  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadApplications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apps = await _appRepo.getMyApplications(forceRefresh: true); // Force refresh
      setState(() {
        _applications = apps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _withdrawApplication(String applicationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Application'),
        content: const Text(
          'Are you sure you want to withdraw this application? You can apply again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final success = await _appRepo.withdrawApplication(applicationId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application withdrawn successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadApplications(); // Refresh the list
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to withdraw application'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _allApps => _applications;
  List<Map<String, dynamic>> get _pendingApps =>
      _applications.where((a) => a['status'] == 'pending').toList();
  List<Map<String, dynamic>> get _acceptedApps =>
      _applications.where((a) => a['status'] == 'accepted').toList();
  List<Map<String, dynamic>> get _rejectedApps =>
      _applications.where((a) => a['status'] == 'rejected').toList();

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Applications'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false, // Remove back button
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadApplications,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _applications.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No applications yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Apply for jobs to see them here',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildApplicationList(_allApps),
          _buildApplicationList(_pendingApps),
          _buildApplicationList(_acceptedApps),
          _buildApplicationList(_rejectedApps),
        ],
      ),
    );
  }

  Widget _buildApplicationList(List<Map<String, dynamic>> apps) {
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No applications in this category',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: apps.length,
        itemBuilder: (context, index) {
          final app = apps[index];
          return _ApplicationCard(
            application: app,
            onWithdraw: app['status'] == 'pending'
                ? () => _withdrawApplication(app['application_id'])
                : null,
            onRefresh: _loadApplications,
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  final Map<String, dynamic> application;
  final VoidCallback? onWithdraw;
  final VoidCallback onRefresh;

  const _ApplicationCard({
    required this.application,
    this.onWithdraw,
    required this.onRefresh,
  });

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  bool _isExpanded = false;
  bool _isDescriptionExpanded = false;

  Future<void> _viewResume(String url, String fileName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final cleanUrl = url.trim();
      final response = await http.get(Uri.parse(cleanUrl));

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) Navigator.pop(context);
        await OpenFile.open(file.path);
      } else {
        if (mounted) Navigator.pop(context);
        throw Exception('Failed to download resume');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening resume: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.application['status'] as String;
    final appliedAt = DateTime.tryParse(widget.application['applied_at'] ?? '');
    final appliedDate = appliedAt != null
        ? '${appliedAt.day}/${appliedAt.month}/${appliedAt.year}'
        : 'Unknown';
    final description = widget.application['description'] ?? '';
    final hasLongDescription = description.length > 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Header - Always visible
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.business, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.application['job_title'] ?? 'Position',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.application['company_name'] ?? 'Company',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ApplicationStatusChip(status: status),
                      const SizedBox(height: 4),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Details
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),

                  // Job Details
                  _buildDetailRow(Icons.location_on, 'Location',
                      widget.application['location'] ?? 'Not specified'),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.attach_money, 'Salary',
                      _formatSalary(widget.application['salary_min'], widget.application['salary_max'])),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.access_time, 'Job Type',
                      widget.application['job_type'] ?? 'Full-time'),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.calendar_today, 'Applied Date', appliedDate),

                  // Resume Link with Preview
                  if (widget.application['resume_url'] != null &&
                      widget.application['resume_url'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildDetailRow(
                        Icons.picture_as_pdf,
                        'Resume',
                        widget.application['resume_file_name'] ?? 'Resume.pdf',
                        isLink: true,
                        onTap: () => _viewResume(
                          widget.application['resume_url'],
                          widget.application['resume_file_name'] ?? 'Resume.pdf',
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Job Description (Collapsible)
                  if (description.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Job Description',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const Spacer(),
                            if (hasLongDescription)
                              TextButton(
                                onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                                child: Text(
                                  _isDescriptionExpanded ? 'Show Less' : 'Show More',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        AnimatedCrossFade(
                          firstChild: Text(
                            description,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondChild: Text(
                            description,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          crossFadeState: _isDescriptionExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                      ],
                    ),

                  if (widget.onWithdraw != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: widget.onWithdraw,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Withdraw Application'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {bool isLink = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: isLink ? onTap : null,
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 8),
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isLink ? const Color(0xFF2563EB) : Colors.grey[700],
                fontSize: 12,
                decoration: isLink ? TextDecoration.underline : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isLink)
            Icon(Icons.open_in_new, size: 14, color: const Color(0xFF2563EB)),
        ],
      ),
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
}