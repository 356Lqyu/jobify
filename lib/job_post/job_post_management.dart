import 'package:flutter/material.dart';
import 'package:jobify/data/job_repository.dart';
import 'package:jobify/job_post/create_job_post.dart';
import 'package:jobify/job_post/job_detail_employer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/data/local_db.dart';

class JobPostManagementPage extends StatefulWidget {
  const JobPostManagementPage({super.key});

  @override
  State<JobPostManagementPage> createState() => JobPostManagementPageState();
}

class JobPostManagementPageState extends State<JobPostManagementPage> {
  final JobRepository _jobRepo = JobRepository();
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String? _userId;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      setState(() => _isLoading = false);
      return;
    }
    _userId = session.user.id;
    print('Logged in user ID: $_userId');

    final userData = await supabase
        .from('users')
        .select('role')
        .eq('user_id', _userId!)
        .maybeSingle();
    if (userData != null) _userRole = userData['role'];
    print('User role: $_userRole');

    await loadJobs();
  }

  Future<void> loadJobs() async {
    if (_userId == null) return;

    // Show cached data immediately
    try {
      final cached = await LocalDB.getCachedJobMapsByUser(_userId!);
      if (cached.isNotEmpty) {
        print('Loaded ${cached.length} jobs from cache');
        setState(() => _jobs = cached);
      } else {
        print('No cached jobs found for user $_userId');
      }
    } catch (e) {
      print('Cache error: $e');
    }

    // Fetch fresh from Supabase and update cache
    setState(() => _isLoading = true);
    try {
      final fresh = await _jobRepo.fetchMyJobPosts(userId: _userId);
      print('Fetched ${fresh.length} jobs from Supabase');
      final flatJobs = fresh.map((job) => _flattenJobMap(job)).toList();
      setState(() => _jobs = flatJobs);
      // Update cache with flattened data
      await LocalDB.insertJobMaps(flatJobs);
    } catch (e) {
      print('Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Convert nested Supabase map (with job_type_id: {name: ...}) to flat map
  Map<String, dynamic> _flattenJobMap(Map<String, dynamic> job) {
    // Helper to safely get the 'name' from a nested object
    String getName(dynamic field) {
      if (field == null) return '';
      if (field is Map) return field['name']?.toString() ?? '';
      // If it's a String (just the ID), we can't get the name
      return '';
    }

    return {
      'job_id': job['job_id'],
      'company_id': job['company_id'],
      'created_by': job['created_by'],
      'job_title': job['job_title'],
      'description': job['description'],
      'location': job['location'],
      'remote_option': job['remote_option'] == true,
      'salary_min': job['salary_min'],
      'salary_max': job['salary_max'],
      'job_type': getName(job['job_type_id']),
      'job_category': getName(job['job_category_id']),
      'experience_level': getName(job['experience_level_id']),
      'vacancy_count': job['vacancy_count'],
      'application_deadline': job['application_deadline'],
      'status': job['status'],
      'view_count': job['view_count'],
      'application_count': job['application_count'],
      'created_at': job['created_at'],
      'image_urls': job['image_urls'] is String
          ? (job['image_urls'] as String).split(',')
          : (job['image_urls'] as List?) ?? [],
      'video_url': job['video_url'],
      'company_name': job['company_name'] ?? '',
      'company_logo_url': job['company_logo_url'],
      'company_industry': job['company_industry'],
      'is_saved': job['is_saved'] == true,
    };
  }
  Future<void> _toggleJobStatus(String jobId, bool isActive) async {
    final newStatus = isActive ? 'closed' : 'active';
    try {
      await _jobRepo.updateJobPost(jobId, {'status': newStatus});
      await loadJobs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job ${newStatus == 'active' ? 'reopened' : 'closed'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteJob(String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('This action cannot be undone. Delete this job?'),
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
      await _jobRepo.deleteJobPost(jobId);
      loadJobs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _jobs.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userId == null || _userRole?.toUpperCase() != 'POSTER') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _userId == null ? 'Please log in as an employer.' : 'Access denied. Employers only.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    final activeCount = _jobs.where((j) => j['status'] == 'active').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Jobs'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: loadJobs,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _buildSummaryCard('Active Jobs', activeCount, Icons.work_outline, Colors.blue),
                  const SizedBox(width: 12),
                  _buildSummaryCard('Total Jobs', _jobs.length, Icons.list_alt, Colors.grey.shade700),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Job Posts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => DraggableScrollableSheet(
                          initialChildSize: 0.88,
                          maxChildSize: 0.96,
                          minChildSize: 0.5,
                          expand: false,
                          builder: (_, scrollController) => CreateJobPost(
                            isModal: true,
                            onPostSuccess: () => Navigator.pop(context, true),
                          ),
                        ),
                      );
                      if (result == true) loadJobs();
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Post a Job'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _jobs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _jobs.length,
                itemBuilder: (ctx, i) {
                  final job = _jobs[i];
                  final isActive = job['status'] == 'active';
                  final List<String> imageUrls = List<String>.from(job['image_urls'] ?? []);
                  final thumbnail = imageUrls.isNotEmpty ? imageUrls.first : null;
                  return _buildJobCard(job, isActive, thumbnail);
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.05),
              color.withOpacity(0.02),
            ],
          ),
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, bool isActive, String? thumbnail) {
    final jobType = job['job_type'] ?? 'Full-time';
    final location = job['location'] ?? 'Unknown location';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thumbnail != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(thumbnail, width: 60, height: 60, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['job_title'] ?? 'Untitled',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.work_outline, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            jobType,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.visibility, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${job['view_count'] ?? 0} views',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.description, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${job['application_count'] ?? 0} applications',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Closed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.green.shade700 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(
                  icon: Icons.visibility_outlined,
                  label: 'Details',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => JobDetailEmployer(job: job)),
                  ),
                  color: Colors.blueGrey,
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
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreateJobPost(existingJob: job)),
                    );
                    if (result == true) loadJobs();
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
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No job posts yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the “Post a Job” button to create your first listing.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}