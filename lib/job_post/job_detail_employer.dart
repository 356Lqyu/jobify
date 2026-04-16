import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:jobify/job_post/job_post_service.dart';
import 'package:jobify/job_post/create_job_post.dart';

class JobDetailEmployer extends StatefulWidget {
  final Map<String, dynamic> job;
  const JobDetailEmployer({super.key, required this.job});

  @override
  State<JobDetailEmployer> createState() => _JobDetailEmployerState();
}

class _JobDetailEmployerState extends State<JobDetailEmployer> {
  final JobPostService _service = JobPostService();
  late Map<String, dynamic> _job;
  bool _isLoading = false;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _job = Map.from(widget.job);
    _initYoutubePlayer();
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

  Future<void> _refresh() async {
    final updated = await _service.fetchJobPostById(_job['job_id']);
    if (updated != null) {
      setState(() {
        _job = updated;
        _initYoutubePlayer();
      });
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = _job['status'] == 'active' ? 'closed' : 'active';
    await _service.updateJobPost(_job['job_id'], {'status': newStatus});
    await _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Job ${newStatus == 'active' ? 'reopened' : 'closed'}')),
    );
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
      await _service.deleteJobPost(_job['job_id']);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _job['status'] == 'active';
    final List<String> imageUrls = List<String>.from(_job['image_urls'] ?? []);
    final hasVideo = _youtubeController != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_job['job_title'] ?? 'Job Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employer notice (stays at top)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'You are viewing this job as an employer.',
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 16),

              // Job title & company
              Text(_job['job_title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${_job['company_profile']?['company_name'] ?? 'Company'} • ${_job['location']}'),
              const SizedBox(height: 12),

              // Info chips
              Wrap(
                spacing: 8,
                children: [
                  if (_job['salary_min'] != null && _job['salary_max'] != null)
                    _infoChip(Icons.attach_money, '${_job['salary_min']} - ${_job['salary_max']} MYR'),
                  _infoChip(Icons.work, _job['job_type_id']?['name'] ?? 'Full-time'),
                  _infoChip(Icons.trending_up, _job['experience_level_id']?['name'] ?? 'Junior'),
                  if (_job['remote_option'] == true) _infoChip(Icons.wifi, 'Remote'),
                ],
              ),
              const SizedBox(height: 16),

              // Job description
              const Text('Job Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_job['description'] ?? 'No description provided.'),
              const SizedBox(height: 24),

              // ----- IMAGES SECTION (moved to bottom) -----
              if (imageUrls.isNotEmpty) ...[
                const Text('Images', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                CarouselSlider(
                  options: CarouselOptions(
                    height: 250,
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

              // ----- VIDEO SECTION (moved to bottom) -----
              if (hasVideo) ...[
                const Text('Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                YoutubePlayer(controller: _youtubeController!),
                const SizedBox(height: 16),
              ],

              // Action buttons (still at the very bottom)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleStatus,
                      icon: Icon(isActive ? Icons.close : Icons.refresh),
                      label: Text(isActive ? 'Close Job' : 'Reopen Job'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isActive ? Colors.orange : Colors.green,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Job'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
    );
  }
}