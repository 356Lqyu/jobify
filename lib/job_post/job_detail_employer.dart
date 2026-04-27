import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jobify/data/job_repository.dart';
import 'package:jobify/job_post/create_job_post.dart';
import 'package:jobify/data/local_db.dart';
import 'package:jobify/job/applicant_list.dart';

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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _job = Map.from(widget.job);
    _initVideoPlayers();
    _loadFromCache();
    _refresh();
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  String? _extractDriveId(String url) {
    final RegExp regExp = RegExp(r'(?:file\/d\/|open\?id=)([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  void _initVideoPlayers() {
    final videoUrl = _job['video_url'] as String?;
    if (videoUrl == null || videoUrl.trim().isEmpty) return;

    // 1. Try YouTube First
    final videoId = YoutubePlayer.convertUrlToId(videoUrl);
    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false),
      );
      return;
    }

    // 2. Try Google Drive Second
    final driveId = _extractDriveId(videoUrl);
    if (driveId != null) {
      final directStreamUrl = 'https://drive.google.com/uc?export=download&id=$driveId';

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(directStreamUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _chewieController = ChewieController(
                videoPlayerController: _videoPlayerController!,
                autoPlay: false,
                looping: false,
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                errorBuilder: (context, errorMessage) {
                  return const Center(
                    child: Text(
                      'Error loading video. Ensure Drive link is public.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              );
            });
          }
        }).catchError((error) {
          debugPrint('Drive Video Error: $error');
        });
    }
  }

  Future<void> _loadFromCache() async {
    final cached = await LocalDB.getCachedJobMapById(_job['job_id']);
    if (cached != null && mounted) {
      setState(() {
        _job = cached;
        // Re-initialize if URL changed from cache
        if (_youtubeController == null && _videoPlayerController == null) {
          _initVideoPlayers();
        }
      });
    }
  }

  Future<void> _refresh({bool force = true}) async {
    setState(() => _isLoading = true);
    try {
      final updated = await _jobRepo.fetchJobPostById(_job['job_id']);
      if (updated != null && mounted) {
        setState(() {
          _job = updated;
          if (_youtubeController == null && _videoPlayerController == null) {
            _initVideoPlayers();
          }
        });
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = _job['status'] == 'active' ? 'closed' : 'active';
    await _jobRepo.updateJobPost(_job['job_id'], {'status': newStatus});
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job ${newStatus == 'active' ? 'reopened' : 'closed'}'),
          backgroundColor: Colors.green,
        ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _jobRepo.deleteJobPost(_job['job_id']);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        String errorMessage = 'Failed to delete job';
        if (e.toString().contains('23503') ||
            e.toString().contains('foreign key constraint')) {
          errorMessage =
          'Cannot delete this job because it has existing applications. Please close the job instead.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _job['status'] == 'active';
    final List<String> imageUrls = (_job['image_urls'] as List? ?? [])
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList();

    final videoUrl = _job['video_url'] as String?;
    final hasVideoUrl = videoUrl != null && videoUrl.trim().isNotEmpty;

    final viewCount = _job['view_count'] ?? 0;
    final appCount = _job['application_count'] ?? 0;
    final hasApplications = appCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _job['job_title'] ?? 'Job Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: hasApplications ? Colors.grey : Colors.white),
            onPressed: hasApplications
                ? null
                : () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateJobPost(existingJob: _job)),
              );
              if (result == true) {
                await LocalDB.deleteJobPost(_job['job_id']);
                await _refresh();
              }
            },
            tooltip: hasApplications
                ? 'Cannot edit a job with existing applications'
                : 'Edit this job',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business_center, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You are viewing this job as an employer.',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _job['job_title'] ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.business, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _job['company_profile']?['company_name'] ?? _job['company_name'] ?? 'Company',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _job['location'] ?? 'Unknown',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_job['salary_min'] != null && _job['salary_max'] != null)
                            _infoChip(
                              Icons.attach_money,
                              '${_job['salary_min']} - ${_job['salary_max']} MYR',
                            ),
                          _infoChip(
                            Icons.work_outline,
                            (_job['job_type_id'] as Map?)?['name'] ?? _job['job_type'] ?? 'Full-time',
                          ),
                          _infoChip(
                            Icons.trending_up,
                            (_job['experience_level_id'] as Map?)?['name'] ?? _job['experience_level'] ?? 'Junior',
                          ),
                          _infoChip(
                            Icons.sell_outlined,
                            (_job['job_category_id'] as Map?)?['name'] ?? _job['job_category'] ?? 'General',
                          ),
                          if (_job['location'] == 'Remote')
                            _infoChip(Icons.wifi, 'Remote'),
                          if (_job['location'] == 'Hybrid')
                            _infoChip(Icons.wifi, 'Hybrid'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(Icons.visibility, '$viewCount', 'Views'),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.grey.shade300,
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ApplicantListPage(
                                      jobId: _job['job_id'],
                                      jobTitle: _job['job_title'] ?? 'Position',
                                    ),
                                  ),
                                );
                              },
                              child: _statItem(
                                Icons.description,
                                '$appCount',
                                'Applications',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Job Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _job['description'] ?? 'No description provided.',
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      if (imageUrls.isNotEmpty) ...[
                        const Text(
                          'Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (hasVideoUrl) ...[
                        const Text(
                          'Video',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // HYBRID PLAYER RENDERER
                        if (_youtubeController != null)
                          YoutubePlayer(controller: _youtubeController!)
                        else if (_chewieController != null)
                          Container(
                            height: 200, // Fixed height or aspect ratio
                            color: Colors.black,
                            child: Chewie(controller: _chewieController!),
                          )
                        else if (_videoPlayerController != null && _chewieController == null)
                            const SizedBox(
                              height: 150,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            InkWell(
                              onTap: () async {
                                final Uri url = Uri.parse(videoUrl!);
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not launch video URL')),
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                  color: const Color(0xFF2563EB).withOpacity(0.05),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2563EB),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Watch Job Video',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            'Tap to open link',
                                            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.open_in_new, size: 18, color: Colors.blueGrey),
                                  ],
                                ),
                              ),
                            ),
                        const SizedBox(height: 16),
                      ],
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _toggleStatus,
                                icon: Icon(
                                  isActive ? Icons.close : Icons.refresh,
                                  size: 18,
                                ),
                                label: Text(
                                  isActive ? 'Close Job' : 'Reopen Job',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isActive
                                      ? Colors.orange
                                      : Colors.green,
                                  side: BorderSide(
                                    color: isActive
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Tooltip(
                              message: hasApplications
                                  ? 'Cannot delete a job with existing applications'
                                  : 'Delete this job',
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: hasApplications ? null : _delete,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Delete Job'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: hasApplications
                                        ? Colors.grey
                                        : Colors.red,
                                    side: BorderSide(
                                      color: hasApplications
                                          ? Colors.grey
                                          : Colors.red,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
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
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}