import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'package:jobify/social/social_feed_provider.dart';
import 'package:jobify/data/job_repository.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/discovery/job_details.dart';
import 'package:share_plus/share_plus.dart';

class DiscoveryJob extends StatefulWidget {
  final Users user;
  const DiscoveryJob({super.key, required this.user});

  @override
  State<DiscoveryJob> createState() => _DiscoveryJobState();
}

class _DiscoveryJobState extends State<DiscoveryJob>
    with WidgetsBindingObserver {
  late final JobProvider _provider;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = JobProvider(
      repository: JobRepository(),
      userId: widget.user.userId,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _provider.init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _debounce?.cancel();
    _provider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider.refresh();
    }
  }

  void refresh() => _provider.refresh();

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _provider.search(value.trim());
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: _provider,
        child: const _FilterSheet(),
      ),
    );
  }

  Future<void> _navigateToJobDetail(BuildContext context, JobPost job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailPage(job: job, currentUser: widget.user),
      ),
    );
    _provider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('Jobs Discovery',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Unified Header: Search Bar + Active Filters
              Material(
                color: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Search Bar & Filter Button Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search,
                                    size: 20,
                                    color: Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: const InputDecoration.collapsed(
                                        hintText: 'Search jobs, location…',
                                        hintStyle: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                      onChanged: (v) => _onSearchChanged(v),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Consumer<JobProvider>(
                            builder: (_, p, __) {
                              return GestureDetector(
                                onTap: _showFilterSheet,
                                child: Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: p.hasActiveFilters
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.tune_rounded,
                                    size: 20,
                                    color: p.hasActiveFilters
                                        ? Colors.white
                                        : Colors.blueGrey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // 2. Active Filter Chips Row
                    Consumer<JobProvider>(
                      builder: (_, p, __) {
                        if (!p.hasActiveFilters) return const SizedBox.shrink();
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Wrap(
                            alignment: WrapAlignment.start,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (p.jobTypeFilter != 'All')
                                _ActiveChip(
                                  label: p.jobTypeFilter,
                                  onRemove: () => p.setJobType('All'),
                                ),
                              if (p.expLevelFilter != 'All')
                                _ActiveChip(
                                  label: p.expLevelFilter,
                                  onRemove: () => p.setExpLevel('All'),
                                ),
                              if (p.locationFilter.isNotEmpty)
                                _ActiveChip(
                                  label: p.locationFilter,
                                  onRemove: () => p.setLocation(''),
                                ),
                              if (p.salaryMin != null)
                                _ActiveChip(
                                  label: 'Min RM ${p.salaryMin!.toStringAsFixed(0)}',
                                  onRemove: () => p.setSalaryMin(null),
                                ),
                              if (p.remoteOnly)
                                _ActiveChip(
                                  label: 'Remote',
                                  onRemove: () => p.setRemoteOnly(false),
                                ),
                              if (p.postDaysFilter > 0)
                                _ActiveChip(
                                  label: p.postDaysFilter == 1
                                      ? 'Last 24h'
                                      : 'Last ${p.postDaysFilter} Days',
                                  onRemove: () => p.setPostDays(0),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<JobProvider>(
                  builder: (_, prov, __) {
                    if (prov.isLoading && prov.jobs.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (prov.jobs.isEmpty) {
                      return _EmptyJobs();
                    }
                    return RefreshIndicator(
                      onRefresh: prov.refresh,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >=
                              n.metrics.maxScrollExtent - 200) {
                            prov.loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 20, bottom: 100),
                          itemCount:
                          prov.jobs.length + (prov.isLoading ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i >= prov.jobs.length) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            final job = prov.jobs[i];
                            return _JobCard(
                              job: job,
                              onSaveTap: () => prov.toggleSaveJob(job, ctx),
                              onTap: () => _navigateToJobDetail(ctx, job),
                              onShareTap: () {
                                final deepLink = 'https://jobify.app/job/${job.jobId}';
                                final text =
                                    '🚀 ${job.jobTitle} at ${job.companyName}\n'
                                    '📍 ${job.location}  •  💰 ${job.salaryDisplay}\n\n'
                                    'Check it out on Jobify:\n$deepLink';
                                Share.share(text, subject: '${job.jobTitle} — ${job.companyName}');
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// JOB CARD
class _JobCard extends StatelessWidget {
  final JobPost job;
  final VoidCallback onSaveTap;
  final VoidCallback onTap;
  final VoidCallback onShareTap;

  const _JobCard({
    required this.job,
    required this.onSaveTap,
    required this.onTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: job.companyLogoUrl != null
                        ? CachedNetworkImage(
                      imageUrl: job.companyLogoUrl!,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          _LogoBox(name: job.companyName),
                      errorWidget: (_, __, ___) =>
                          _LogoBox(name: job.companyName),
                    )
                        : _LogoBox(name: job.companyName),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.companyName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                        Text(
                          job.jobTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onShareTap,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.share_outlined,
                        size: 22,
                        color: Colors.blueGrey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onSaveTap,
                    child: Icon(
                      job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 22,
                      color: job.isSaved
                          ? const Color(0xFF2563EB)
                          : Colors.blueGrey.shade300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (job.jobType.isNotEmpty)
                    _JobTag(label: job.jobType, color: const Color(0xFF2563EB)),
                  if (job.experienceLevel.isNotEmpty)
                    _JobTag(
                      label: job.experienceLevel,
                      color: const Color(0xFF8B5CF6),
                    ),
                  if (job.remoteOption)
                    _JobTag(label: 'Remote', color: const Color(0xFF10B981)),
                  if (job.jobCategory.isNotEmpty)
                    _JobTag(
                      label: job.jobCategory,
                      color: const Color(0xFFF59E0B),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 3),
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
                  Text(
                    job.timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.attach_money,
                    size: 13,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    job.salaryDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.group_outlined,
                    size: 13,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${job.vacancyCount} vacancy',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
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
}

// FILTER SHEET
class _FilterSheet extends StatefulWidget {
  const _FilterSheet();
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  final _locationCtrl = TextEditingController();

  static const _jobTypes = [
    'All',
    'Full-time',
    'Part-time',
    'Contract',
    'Internship',
    'Freelance',
  ];

  static const _expLevels = [
    'All',
    'Fresh Graduate / Entry Level',
    'Junior (1-3 years)',
    'Mid-Level (3-5 years)',
    'Senior (5+ years)',
    'Manager / Executive',
  ];

  // Map strings to day integers
  static const _postTimes = {
    'All Time': 0,
    'Last 24h': 1,
    'Last 7 days': 7,
    'Last 14 days': 14,
    'Last 30 days': 30,
  };

  @override
  void initState() {
    super.initState();
    final p = context.read<JobProvider>();
    _locationCtrl.text = p.locationFilter;
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (_, prov, __) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Filter Jobs',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    if (prov.hasActiveFilters)
                      TextButton(
                        onPressed: () {
                          prov.clearFilters();
                          _locationCtrl.clear();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Clear all',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Job Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _jobTypes
                      .map(
                        (t) => _SelectableChip(
                      label: t,
                      selected: prov.jobTypeFilter == t,
                      onTap: () => prov.setJobType(t),
                    ),
                  )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Experience Level'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _expLevels
                      .map(
                        (l) => _SelectableChip(
                      label: l,
                      selected: prov.expLevelFilter == l,
                      onTap: () => prov.setExpLevel(l),
                    ),
                  )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Post Time'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _postTimes.entries
                      .map(
                        (e) => _SelectableChip(
                      label: e.key,
                      selected: prov.postDaysFilter == e.value,
                      onTap: () => prov.setPostDays(e.value),
                    ),
                  )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const _FilterLabel('Remote Only'),
                    const Spacer(),
                    Switch(
                      value: prov.remoteOnly,
                      activeColor: const Color(0xFF2563EB),
                      onChanged: prov.setRemoteOnly,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _FilterLabel('Location'),
                const SizedBox(height: 8),
                TextField(
                  controller: _locationCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Kuala Lumpur',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      prov.setLocation(_locationCtrl.text.trim());
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _JobTag extends StatelessWidget {
  final String label;
  final Color color;
  const _JobTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
    decoration: BoxDecoration(
      color: const Color(0xFFDBEAFE),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF1D4ED8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 14, color: Color(0xFF1D4ED8)),
        ),
      ],
    ),
  );
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.blueGrey,
        ),
      ),
    ),
  );
}

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 15,
      color: Colors.black87,
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
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _EmptyJobs extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.work_off_outlined,
            size: 56,
            color: Colors.blueGrey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            'No jobs found.\nTry adjusting your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 15),
          ),
        ],
      ),
    ),
  );
}