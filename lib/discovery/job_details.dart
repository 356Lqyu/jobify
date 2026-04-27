import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/job_repository.dart';
import 'package:jobify/data/applicantion_respository.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/job/apply_for_job.dart';
import 'package:jobify/social/social_feed_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class JobDetailPage extends StatefulWidget {
  final JobPost job;
  final Users currentUser;

  const JobDetailPage({
    super.key,
    required this.job,
    required this.currentUser,
  });

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  final _repo = JobRepository();
  final _appRepo = ApplicationRepository();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasApplied = false;
  bool _checkingApply = true;
  JobPost? _freshJob;

  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  bool get _isJobSeeker =>
      widget.currentUser.role.toUpperCase() == 'JOB_SEEKER';

  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.job.isSaved;
    _initVideoPlayers(widget.job.videoUrl);
    _loadData();
    if (!_isJobSeeker) setState(() => _checkingApply = false);
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

  void _initVideoPlayers(String? videoUrl) {
    if (videoUrl == null || videoUrl.trim().isEmpty) return;

    // 1. Try YouTube
    final videoId = YoutubePlayer.convertUrlToId(videoUrl);
    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false),
      );
      return;
    }

    // 2. Try Google Drive
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

  Future<void> _loadData() async {
    if (_isJobSeeker) {
      await _repo.incrementViewCount(widget.job.jobId);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final updatedJob = await _repo.fetchJobById(widget.job.jobId);
    if (updatedJob != null && mounted) {
      setState(() {
        _freshJob = updatedJob;
        _isSaved = updatedJob.isSaved;
      });
    }

    if (_isJobSeeker) {
      final applied = await _appRepo.checkExistingApplication(
        widget.job.jobId,
        widget.currentUser.userId,
      );
      if (mounted) {
        setState(() {
          _hasApplied = applied;
          _checkingApply = false;
        });
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _openApplySheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplyForJobPage(
          job: {
            'job_id': widget.job.jobId,
            'job_title': widget.job.jobTitle,
            'company_name': widget.job.companyName,
            'location': widget.job.location,
            'description': widget.job.description,
            'job_type': widget.job.jobType,
            'salary_min': widget.job.salaryMin,
            'salary_max': widget.job.salaryMax,
          },
          userId: widget.currentUser.userId,
        ),
      ),
    ).then((_) async {
      final applied = await _appRepo.checkExistingApplication(
        widget.job.jobId,
        widget.currentUser.userId,
      );
      if (mounted) setState(() => _hasApplied = applied);
    });
  }

  Future<void> _toggleSave() async {
    if (_isSaving) return;
    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !wasSaved;
      _isSaving = true;
    });

    showFeedSnackBar(
      context,
      wasSaved ? 'Job unsaved' : 'Job saved',
      icon: wasSaved ? Icons.bookmark_outline : Icons.bookmark,
    );

    final result = await _repo.toggleSaveJob(widget.job.jobId, wasSaved);
    if (mounted) {
      setState(() => _isSaving = false);
      if (result == wasSaved) {
        setState(() => _isSaved = wasSaved);
        showFeedSnackBar(context, 'Failed to update save', isError: true);
      }
    }
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _freshJob == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final job = _freshJob ?? widget.job;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text(
              'Job Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            actions: [
              IconButton(
                iconSize: 26,
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () {
                  final jobToShare = _freshJob ?? widget.job;
                  final deepLink = 'https://jobify.app/job/${jobToShare.jobId}';

                  final shareText =
                      'Check out this job: ${jobToShare.jobTitle} at ${jobToShare.companyName}!\nLocation: ${jobToShare.location}\nSalary: ${jobToShare.salaryDisplay}\n\nLink: $deepLink';
                  Share.share(shareText);
                },
                tooltip: 'Share job',
              ),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    key: ValueKey(_isSaved),
                    color: Colors.white,
                  ),
                ),
                onPressed: _toggleSave,
                tooltip: _isSaved ? 'Unsave job' : 'Save job',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company header card
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: job.companyLogoUrl != null
                                  ? CachedNetworkImage(
                                imageUrl: job.companyLogoUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _LogoBox(name: job.companyName),
                              )
                                  : _LogoBox(name: job.companyName),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.jobTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    job.companyName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (job.companyIndustry != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      job.companyIndustry!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.blueGrey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                job.location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.attach_money,
                              size: 14,
                              color: Colors.blueGrey,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              job.salaryDisplay,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (job.jobType.isNotEmpty)
                              _Tag(
                                label: job.jobType,
                                color: const Color(0xFF2563EB),
                              ),
                            if (job.experienceLevel.isNotEmpty)
                              _Tag(
                                label: job.experienceLevel,
                                color: const Color(0xFF8B5CF6),
                              ),
                            if (job.jobCategory.isNotEmpty)
                              _Tag(
                                label: job.jobCategory,
                                color: const Color(0xFFF59E0B),
                              ),
                            if (job.remoteOption)
                              _Tag(
                                label: 'Remote',
                                color: const Color(0xFF10B981),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Stats Container
                  _buildCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            icon: Icons.remove_red_eye_outlined,
                            value: '${job.viewCount}',
                            label: 'Views',
                          ),
                        ),
                        _VertDivider(),
                        Expanded(
                          child: _StatItem(
                            icon: Icons.send_outlined,
                            value: '${job.applicationCount}',
                            label: 'Applied',
                          ),
                        ),
                        _VertDivider(),
                        Expanded(
                          child: _StatItem(
                            icon: Icons.people_outline,
                            value: '${job.vacancyCount}',
                            label: 'Vacancies',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Description
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Job Description',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          job.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Media Section
                  if (job.imageUrls.isNotEmpty || (job.videoUrl != null && job.videoUrl!.isNotEmpty))
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Media',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (job.imageUrls.isNotEmpty)
                            SizedBox(
                              height: 140,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: job.imageUrls.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: job.imageUrls[index],
                                      width: 200,
                                      height: 140,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey.shade100,
                                        width: 200,
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey.shade100,
                                        width: 200,
                                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                          if (job.imageUrls.isNotEmpty && (job.videoUrl != null && job.videoUrl!.isNotEmpty))
                            const SizedBox(height: 16),

                          // HYBRID PLAYER RENDERER
                          if (job.videoUrl != null && job.videoUrl!.isNotEmpty)
                            if (_youtubeController != null)
                              YoutubePlayer(controller: _youtubeController!)
                            else if (_chewieController != null)
                              Container(
                                height: 200,
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
                                    final Uri url = Uri.parse(job.videoUrl!);
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
                        ],
                      ),
                    ),

                  // Details
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.attach_money,
                          label: 'Salary',
                          value: job.salaryDisplay,
                        ),
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: job.location,
                        ),
                        _DetailRow(
                          icon: Icons.work_outline,
                          label: 'Job Type',
                          value: job.jobType,
                        ),
                        _DetailRow(
                          icon: Icons.bar_chart_outlined,
                          label: 'Experience',
                          value: job.experienceLevel,
                        ),
                        _DetailRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: job.jobCategory,
                        ),
                        if (job.applicationDeadline != null)
                          _DetailRow(
                            icon: Icons.event_outlined,
                            label: 'Deadline',
                            value: DateFormat(
                              'dd MMM yyyy',
                            ).format(job.applicationDeadline!),
                          ),
                        _DetailRow(
                          icon: Icons.access_time_outlined,
                          label: 'Posted',
                          value: job.timeAgo,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _checkingApply
          ? null
          : Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: _isJobSeeker
                ? _ApplyButton(
              hasApplied: _hasApplied,
              onTap: _hasApplied ? null : _openApplySheet,
            )
                : _DisabledApplyButton(),
          ),
        ),
      ),
    );
  }
}

// APPLY BUTTONS
class _ApplyButton extends StatelessWidget {
  final bool hasApplied;
  final VoidCallback? onTap;
  const _ApplyButton({required this.hasApplied, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: hasApplied
            ? Colors.grey.shade400
            : const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: hasApplied ? 0 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      child: Text(
        hasApplied ? '✓ Applied' : 'Apply Now',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
  );
}

class _DisabledApplyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: null,
      child: const Text(
        'Apply Now',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
  );
}

// SMALL WIDGETS
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 36, width: 1, color: Colors.grey.shade200);
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _LogoBox extends StatelessWidget {
  final String name;
  const _LogoBox({required this.name});

  @override
  Widget build(BuildContext context) {
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
    ];
    final color = name.isEmpty
        ? palette[0]
        : palette[name.codeUnitAt(0) % palette.length];
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}