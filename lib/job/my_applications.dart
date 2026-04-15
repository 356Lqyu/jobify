// lib/job/my_applications.dart
import 'package:flutter/material.dart';
import 'package:jobify/job/application_repository.dart';
import 'package:jobify/job/application_status.dart';

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage>
    with SingleTickerProviderStateMixin {
  final ApplicationRepository _appRepo = ApplicationRepository();
  late TabController _tabController;

  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String? _error;

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
      final apps = await _appRepo.getMyApplications();
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
          'Are you sure you want to withdraw this application? This action cannot be undone.',
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
        await _loadApplications();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Applications'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
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
            const Icon(Icons.error_outline,
                size: 64, color: Colors.red),
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
            Icon(Icons.work_outline,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No applications yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
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
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> application;
  final VoidCallback? onWithdraw;

  const _ApplicationCard({
    required this.application,
    this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final status = application['status'] as String;
    final appliedAt = DateTime.tryParse(application['applied_at'] ?? '');
    final appliedDate = appliedAt != null
        ? '${appliedAt.day}/${appliedAt.month}/${appliedAt.year}'
        : 'Unknown';

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      application['job_title'] ?? 'Position',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application['company_name'] ?? 'Company',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              ApplicationStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  application['location'] ?? 'Location',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Applied: $appliedDate',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          if (application['salary_min'] != null ||
              application['salary_max'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.attach_money, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatSalary(
                      application['salary_min'],
                      application['salary_max'],
                    ),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          if (onWithdraw != null) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onWithdraw,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Withdraw'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatSalary(dynamic min, dynamic max) {
    if (min == null && max == null) return 'Salary not disclosed';
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