import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:jobify/data/job_repository.dart';
import 'package:jobify/job_post/create_job_post.dart';
import 'package:jobify/data/local_db.dart';   // added for cache

class JobDetailEmployer extends StatefulWidget {
  final Map<String, dynamic> job;
  const JobDetailEmployer({super.key, required this.job});

  @override
  State<JobDetailEmployer> createState() => _JobDetailEmployerState();
}

class _JobDetailEmployerState extends State<JobDetailEmployer> {
  final JobRepository _jobRepo = JobRepository();
  late Map<String, dynamic> _job;
  bool _isLoading = false;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _job = Map.from(widget.job);
    _initYoutubePlayer();
    _loadFromCache();   // show cached data instantly
    _refresh();         // fetch fresh from Supabase
  }

  void _initYoutubePlayer() {
    final videoUrl = _job['video_url'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      final videoId = YoutubePlayer.convertUrlToId(videoUrl);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false),
        );
      }
    }
  }

  Future<void> _loadFromCache() async {
    final cached = await LocalDB.getCachedJobMapById(_job['job_id']);
    if (cached != null && mounted) {
      setState(() {
        _job = cached;
        _initYoutubePlayer();
      });
    }
  }

  Future<void> _refresh() async {
    final updated = await _jobRepo.fetchJobPostById(_job['job_id']);
    if (updated != null && mounted) {
      setState(() {
        _job = updated;
        _initYoutubePlayer();
      });
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = _job['status'] == 'active' ? 'closed' : 'active';
    await _jobRepo.updateJobPost(_job['job_id'], {'status': newStatus});
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Job ${newStatus == 'active' ? 'reopened' : 'closed'}')),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('This cannot be undone. Delete this job?'),
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
      setState(() => _isLoading = true);
      await _jobRepo.deleteJobPost(_job['job_id']);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _job['status'] == 'active';
    final List<String> imageUrls = (_job['image_urls'] as List? ?? [])
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList();
    final hasVideo = _youtubeController != null;
    final viewCount = _job['view_count'] ?? 0;
    final appCount = _job['application_count'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_job['job_title'] ?? 'Job Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateJobPost(existingJob: _job)),
              );
              if (result == true) _refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Employer notice banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business_center, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You are viewing this job as an employer.',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

              // Main card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Job title
                      Text(
                        _job['job_title'] ?? 'Untitled',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // Company & location row
                      Row(
                        children: [
                          Icon(Icons.business, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            _job['company_profile']?['company_name'] ?? _job['company_name'] ?? 'Company',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                          Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _job['location'] ?? 'Unknown',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Info chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_job['salary_min'] != null && _job['salary_max'] != null)
                            _infoChip(Icons.attach_money, '${_job['salary_min']} - ${_job['salary_max']} MYR'),
                          _infoChip(Icons.work_outline, _job['job_type'] ?? 'Full-time'),
                          _infoChip(Icons.trending_up, _job['experience_level'] ?? 'Junior'),
                          if (_job['remote_option'] == true) _infoChip(Icons.wifi, 'Remote'),
                          _infoChip(Icons.sell_outlined, _job['job_category'] ?? 'General'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stats row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(Icons.visibility, '$viewCount', 'Views'),
                            Container(width: 1, height: 30, color: Colors.grey.shade300),
                            _statItem(Icons.description, '$appCount', 'Applications'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description
                      const Text('Job Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        _job['description'] ?? 'No description provided.',
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 20),

                      // Images
                      if (imageUrls.isNotEmpty) ...[
                        const Text('Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        CarouselSlider(
                          options: CarouselOptions(
                            height: 220,
                            enlargeCenterPage: true,
                            viewportFraction: 0.9,
                          ),
                          items: imageUrls.map((url) {
                            return Builder(
                              builder: (BuildContext context) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Video
                      if (hasVideo) ...[
                        const Text('Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        YoutubePlayer(controller: _youtubeController!),
                        const SizedBox(height: 16),
                      ],

                      const Divider(height: 32),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _toggleStatus,
                              icon: Icon(isActive ? Icons.close : Icons.refresh, size: 18),
                              label: Text(isActive ? 'Close Job' : 'Reopen Job'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isActive ? Colors.orange : Colors.green,
                                side: BorderSide(color: isActive ? Colors.orange : Colors.green),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _delete,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Delete Job'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}