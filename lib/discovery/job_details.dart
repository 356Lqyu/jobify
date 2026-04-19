import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/data/job_repository.dart';
import 'package:jobify/data/applicantion_respository.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/job/apply_for_job.dart';
import 'package:intl/intl.dart';

class JobDetailPage extends StatefulWidget {
  final JobPost job;
  final Users currentUser;

  const JobDetailPage({super.key, required this.job, required this.currentUser});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  final _repo = JobRepository();
  final _appRepo = ApplicationRepository();
  bool _isLoading = true;
  bool _isSaved = false;
  bool _hasApplied = false;
  bool _checkingApply = true;
  JobPost? _freshJob;

  bool get _isJobSeeker => widget.currentUser.role.toUpperCase() == 'JOB_SEEKER';

  @override
  void initState() {
    super.initState();
    _loadData();

    _isSaved = widget.job.isSaved;
    _fetchSavedState();
    if (_isJobSeeker) {
      _checkApplication();
    } else {
      setState(() => _checkingApply = false);
    }
  }

  Future<void> _loadData() async {
    print('Current user role: ${widget.currentUser.role}');
    print('_isJobSeeker: $_isJobSeeker');
    // 1. Increment view count (only for job seekers)
    if (_isJobSeeker) {
      await _repo.incrementViewCount(widget.job.jobId);
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // 2. Fetch the latest job data (includes updated view count)
    final updatedJob = await _repo.fetchJobById(widget.job.jobId);
    print('Fetched view_count: ${updatedJob?.viewCount}');
    if (updatedJob != null && mounted) {
      setState(() {
        _freshJob = updatedJob;
        _isSaved = updatedJob.isSaved;
      });
    }

    // 3. Check if the user has already applied (job seekers only)
    if (_isJobSeeker) {
      final applied = await _appRepo.checkExistingApplication(
        widget.job.jobId,
        widget.currentUser.userId,
      );
      if (mounted) setState(() {
        _hasApplied = applied;
        _checkingApply = false;
      });
    } else {
      setState(() => _checkingApply = false);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _loadData();
  }

  Future<void> _fetchSavedState() async {
    try {
      final saved = await _repo.isJobSaved(widget.job.jobId);
      if (mounted) setState(() => _isSaved = saved);
    } catch (e) {
      debugPrint('Error fetching saved state: $e');
    }
  }

  Future<void> _checkApplication() async {
    final applied = await _appRepo.checkExistingApplication(
      widget.job.jobId,
      widget.currentUser.userId,
    );
    if (mounted) setState(() { _hasApplied = applied; _checkingApply = false; });
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
    ).then((_) => _checkApplication());
  }

  void _toggleSave() async {
    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);
    await _repo.toggleSaveJob(widget.job.jobId, wasSaved);
    _fetchSavedState();
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Use fresh job data if available, otherwise fallback to the initial job
    final job = _freshJob ?? widget.job;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            pinned: true,
            title: const Text('Job Details',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            actions: [
              IconButton(
                icon: Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _isSaved ? const Color(0xFF2563EB) : Colors.blueGrey,
                ),
                onPressed: _toggleSave,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
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
                                width: 56, height: 56, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _LogoBox(name: job.companyName))
                                : _LogoBox(name: job.companyName),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(job.jobTitle,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        color: Colors.black87)),
                                const SizedBox(height: 3),
                                Text(job.companyName,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w600)),
                                if (job.companyIndustry != null) ...[
                                  const SizedBox(height: 2),
                                  Text(job.companyIndustry!,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.blueGrey)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(job.location,
                                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const Icon(Icons.attach_money, size: 14, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                          Text(job.salaryDisplay,
                              style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: [
                          if (job.jobType.isNotEmpty)
                            _Tag(label: job.jobType, color: const Color(0xFF2563EB)),
                          if (job.experienceLevel.isNotEmpty)
                            _Tag(label: job.experienceLevel, color: const Color(0xFF8B5CF6)),
                          if (job.jobCategory.isNotEmpty)
                            _Tag(label: job.jobCategory, color: const Color(0xFFF59E0B)),
                          if (job.remoteOption)
                            _Tag(label: 'Remote', color: const Color(0xFF10B981)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(icon: Icons.remove_red_eye_outlined, value: '${job.viewCount}', label: 'Views'),
                      _VertDivider(),
                      _StatItem(icon: Icons.send_outlined, value: '${job.applicationCount}', label: 'Applied'),
                      _VertDivider(),
                      _StatItem(icon: Icons.people_outline, value: '${job.vacancyCount}', label: 'Vacancies'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Job Description',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 10),
                      Text(job.description,
                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Details',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 12),
                      _DetailRow(icon: Icons.attach_money, label: 'Salary', value: job.salaryDisplay),
                      _DetailRow(icon: Icons.location_on_outlined, label: 'Location', value: job.location),
                      _DetailRow(icon: Icons.work_outline, label: 'Job Type', value: job.jobType),
                      _DetailRow(icon: Icons.bar_chart_outlined, label: 'Experience', value: job.experienceLevel),
                      _DetailRow(icon: Icons.category_outlined, label: 'Category', value: job.jobCategory),
                      if (job.applicationDeadline != null)
                        _DetailRow(
                            icon: Icons.event_outlined,
                            label: 'Deadline',
                            value: DateFormat('dd MMM yyyy').format(job.applicationDeadline!)),
                      _DetailRow(icon: Icons.access_time_outlined, label: 'Posted', value: job.timeAgo),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _checkingApply
          ? null
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _isJobSeeker
            ? _ApplyButton(hasApplied: _hasApplied, onTap: _hasApplied ? null : _openApplySheet)
            : _DisabledApplyButton(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPLY BUTTON VARIANTS
// ─────────────────────────────────────────────────────────────────────────────
class _ApplyButton extends StatelessWidget {
  final bool hasApplied;
  final VoidCallback? onTap;
  const _ApplyButton({required this.hasApplied, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: hasApplied ? Colors.grey.shade400 : const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 4,
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
  Widget build(BuildContext context) => Tooltip(
    message: 'Only job seekers can apply for jobs',
    child: SizedBox(
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
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
        ],
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
    ],
  );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(height: 36, width: 1, color: Colors.grey.shade200);
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 10),
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)),
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
    child: Text(label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _LogoBox extends StatelessWidget {
  final String name;
  const _LogoBox({required this.name});

  @override
  Widget build(BuildContext context) {
    const palette = [
      Color(0xFF6366F1), Color(0xFF2563EB), Color(0xFF10B981),
      Color(0xFFEC4899), Color(0xFFF59E0B),
    ];
    final color = name.isEmpty ? palette[0] : palette[name.codeUnitAt(0) % palette.length];
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
    );
  }
}