// lib/job/my_applications.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';
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
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadApplications();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
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
      final apps = await _appRepo.getMyApplications(forceRefresh: true);
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

  List<Map<String, dynamic>> get _allApps =>
      _applications.where((a) => a['status'] != 'withdrawn').toList();

  List<Map<String, dynamic>> get _pendingApps =>
      _applications.where((a) => a['status'] == 'pending').toList();

  List<Map<String, dynamic>> get _acceptedApps =>
      _applications.where((a) => a['status'] == 'accepted').toList();

  List<Map<String, dynamic>> get _rejectedApps =>
      _applications.where((a) => a['status'] == 'rejected').toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final allCount = _allApps.length;
    final pendingCount = _pendingApps.length;
    final acceptedCount = _acceptedApps.length;
    final rejectedCount = _rejectedApps.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Applications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatusTab('All', allCount, 0, Colors.blue),
                const SizedBox(width: 8),
                _buildStatusTab('Pending', pendingCount, 1, Colors.orange),
                const SizedBox(width: 8),
                _buildStatusTab('Accepted', acceptedCount, 2, Colors.green),
                const SizedBox(width: 8),
                _buildStatusTab('Rejected', rejectedCount, 3, Colors.red),
              ],
            ),
          ),
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
            onRefresh: _loadApplications,
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  final Map<String, dynamic> application;
  final Future<void> Function() onRefresh;

  const _ApplicationCard({
    required this.application,
    required this.onRefresh,
  });

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  final ApplicationRepository _appRepo = ApplicationRepository();
  bool _isExpanded = false;
  bool _isDescriptionExpanded = false;
  bool _isWithdrawing = false;

  Future<void> _withdrawApplication() async {
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
      setState(() => _isWithdrawing = true);
      try {
        final success = await _appRepo.withdrawApplication(widget.application['application_id']);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application withdrawn successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await widget.onRefresh();
          if (_isExpanded && mounted) {
            setState(() => _isExpanded = false);
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot withdraw this application at this time'),
              backgroundColor: Colors.orange,
            ),
          );
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
        if (mounted) {
          setState(() => _isWithdrawing = false);
        }
      }
    }
  }

  Future<void> _previewResume(String url, String fileName) async {
    final cleanUrl = url.trim();
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

  @override
  Widget build(BuildContext context) {
    final status = widget.application['status'] as String;

    if (status == 'withdrawn') {
      return const SizedBox.shrink();
    }

    final appliedAt = DateTime.tryParse(widget.application['applied_at'] ?? '');
    final appliedDate = appliedAt != null
        ? '${appliedAt.day}/${appliedAt.month}/${appliedAt.year}'
        : 'Unknown';
    final description = widget.application['description'] ?? '';
    final hasLongDescription = description.length > 100;
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

    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Company Logo/Icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isAccepted ? Icons.check_circle : Icons.work_outline,
                        color: getStatusColor(),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Job Info
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
                    // Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        getStatusText(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: getStatusColor(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[400],
                      size: 20,
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
                    // Location
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Text(
                          widget.application['location'] ?? 'Not specified',
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Salary
                    Row(
                      children: [
                        Icon(Icons.attach_money, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Text(
                          _formatSalary(widget.application['salary_min'], widget.application['salary_max']),
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Job Type
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Text(
                          widget.application['job_type'] ?? 'Full-time',
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Applied Date
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Text(
                          'Applied: $appliedDate',
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ],
                    ),
                    // Resume
                    if (widget.application['resume_url'] != null &&
                        widget.application['resume_url'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _previewResume(
                          widget.application['resume_url'],
                          widget.application['resume_file_name'] ?? 'Resume.pdf',
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
                                widget.application['resume_file_name'] ?? 'Resume.pdf',
                                style: TextStyle(
                                  color: const Color(0xFF2563EB),
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Job Description
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
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
                    // Withdraw Button
                    if (isPending && !_isWithdrawing) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _withdrawApplication,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Withdraw Application'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isPending && _isWithdrawing)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
          ],
        ),
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

// Resume Preview Dialog (same as in apply_for_job.dart)
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