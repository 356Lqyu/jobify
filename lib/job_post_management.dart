import 'package:flutter/material.dart';
import 'package:jobify/job_post_service.dart';
import 'package:jobify/create_job_post.dart';
import 'package:jobify/job_detail_employer.dart';
import 'package:provider/provider.dart';
import 'package:jobify/user_provider.dart';
import 'package:jobify/user.dart';

class JobPostManagementPage extends StatefulWidget {
  const JobPostManagementPage({super.key});

  @override
  State<JobPostManagementPage> createState() => _JobPostManagementPageState();
}

class _JobPostManagementPageState extends State<JobPostManagementPage> {
  final JobPostService _service = JobPostService();
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;

  /*@override
  void initState() {
    super.initState();
    _loadJobs();
  }*/

  @override
  void initState() {
    super.initState();
    // Temporary: set a test user if none exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.currentUser == null) {
        final testUser = User(
          userId: '4b164b12-bde1-4ecb-b64d-062a0ad435e1',
          role: 'POSTER',
          fullname: 'Test Employer',
          email: 'ww@gmail.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        userProvider.setUser(testUser);
        // Now load jobs after user is set
        _loadJobs();
      } else {
        // User already exists, load jobs
        _loadJobs();
      }
    });
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final userId = Provider.of<UserProvider>(context, listen: false).userId;
      print("Using userId: $userId");
      final data = await _service.fetchMyJobPosts(userId: userId);
      print("Fetched ${data.length} jobs");
      setState(() => _jobs = data);
    } catch (e) {
      print("Error loading jobs: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleJobStatus(String jobId, bool isActive) async {
    final newStatus = isActive ? 'closed' : 'active';
    await _service.updateJobPost(jobId, {'status': newStatus});
    _loadJobs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Job ${newStatus == 'active' ? 'reopened' : 'closed'}')),
    );
  }

  Future<void> _deleteJob(String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteJobPost(jobId);
      _loadJobs();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<UserProvider>(context).role;
    if (role != 'POSTER') {
      return Scaffold(
        body: Center(child: Text('Access denied. Employers only.')),
      );
    }

    final activeCount = _jobs.where((j) => j['status'] == 'active').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Jobs'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        child: Column(
          children: [
            // Summary cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildSummaryCard('Active Jobs', activeCount, Icons.work, Colors.blue),
                  const SizedBox(width: 12),
                  _buildSummaryCard('Total Jobs', _jobs.length, Icons.list, Colors.grey),
                ],
              ),
            ),
            // Header with Post button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your Job Posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateJobPost()));
                      if (result == true) _loadJobs();
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Post a Job'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _jobs.isEmpty
                  ? const Center(child: Text('No job posts yet. Tap + to create one.'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _jobs.length,
                itemBuilder: (ctx, i) {
                  final job = _jobs[i];
                  final isActive = job['status'] == 'active';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  job['job_title'] ?? 'Untitled',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green.shade100 : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Closed',
                                  style: TextStyle(
                                    color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('${job['location']} • ${job['job_type']?['name'] ?? 'Full-time'}'),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _actionButton(
                                icon: Icons.visibility,
                                label: 'Details',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => JobDetailEmployer(job: job)),
                                ),
                              ),
                              if (isActive)
                                _actionButton(
                                  icon: Icons.close,
                                  label: 'Close',
                                  onTap: () => _toggleJobStatus(job['job_id'], true),
                                  color: Colors.orange,
                                )
                              else
                                _actionButton(
                                  icon: Icons.refresh,
                                  label: 'Reopen',
                                  onTap: () => _toggleJobStatus(job['job_id'], false),
                                  color: Colors.green,
                                ),
                              _actionButton(
                                icon: Icons.edit,
                                label: 'Edit',
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CreateJobPost(existingJob: job)),
                                  );
                                  if (result == true) _loadJobs();
                                },
                                color: Colors.blue,
                              ),
                              _actionButton(
                                icon: Icons.delete_outline,
                                label: 'Delete',
                                onTap: () => _deleteJob(job['job_id']),
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap, Color color = Colors.blue}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}