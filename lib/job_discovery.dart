import 'package:flutter/material.dart';
import 'package:jobify/user.dart';

/// Job Discovery page – job listing with filtering.
/// Layout scaffold only; wire Supabase data in next sprint.
class JobDiscoveryPage extends StatefulWidget {
  final User user;
  const JobDiscoveryPage({super.key, required this.user});

  @override
  State<JobDiscoveryPage> createState() => _JobDiscoveryPageState();
}

class _JobDiscoveryPageState extends State<JobDiscoveryPage> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Full-time', 'Part-time', 'Remote', 'Internship'];
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jobs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            Text('Find your next opportunity', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search jobs, companies...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Filter chips ─────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filters.length,
              itemBuilder: (context, i) {
                final selected = _filters[i] == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filters[i]),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedFilter = _filters[i]),
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // ── Job list ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _mockJobs.length,
              itemBuilder: (context, i) => _JobCard(job: _mockJobs[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mock job data ──────────────────────────────────────────────────────────

class _MockJob {
  final String companyInitials;
  final Color avatarColor;
  final String companyName;
  final String jobTitle;
  final String location;
  final String jobType;
  final String salaryRange;
  final String postedAgo;

  const _MockJob({
    required this.companyInitials,
    required this.avatarColor,
    required this.companyName,
    required this.jobTitle,
    required this.location,
    required this.jobType,
    required this.salaryRange,
    required this.postedAgo,
  });
}

final List<_MockJob> _mockJobs = [
  _MockJob(companyInitials: 'TS', avatarColor: Colors.indigo, companyName: 'Tech Solutions Inc.', jobTitle: 'Senior Frontend Developer', location: 'Kuala Lumpur', jobType: 'Full-time', salaryRange: 'RM 6,000 – 9,000', postedAgo: '2h ago'),
  _MockJob(companyInitials: 'DI', avatarColor: Colors.deepPurple, companyName: 'Digital Innovations', jobTitle: 'Product Manager', location: 'Remote', jobType: 'Remote', salaryRange: 'RM 8,000 – 12,000', postedAgo: '1d ago'),
  _MockJob(companyInitials: 'CA', avatarColor: Colors.teal, companyName: 'Creative Agency', jobTitle: 'UI/UX Designer', location: 'Petaling Jaya', jobType: 'Full-time', salaryRange: 'RM 4,500 – 6,500', postedAgo: '2d ago'),
  _MockJob(companyInitials: 'GS', avatarColor: Colors.orange, companyName: 'GreenStar Corp', jobTitle: 'Marketing Executive', location: 'Penang', jobType: 'Part-time', salaryRange: 'RM 2,500 – 3,500', postedAgo: '3d ago'),
];

// ── Job Card Widget ────────────────────────────────────────────────────────

class _JobCard extends StatefulWidget {
  final _MockJob job;
  const _JobCard({required this.job});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: widget.job.avatarColor,
                  child: Text(widget.job.companyInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.job.companyName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(widget.job.jobTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
                // Save / bookmark button (job seekers can save)
                IconButton(
                  icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border, color: _saved ? Colors.blue : Colors.grey),
                  onPressed: () => setState(() => _saved = !_saved),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _InfoChip(icon: Icons.location_on_outlined, label: widget.job.location),
                _InfoChip(icon: Icons.access_time, label: widget.job.jobType),
                _InfoChip(icon: Icons.attach_money, label: widget.job.salaryRange),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.job.postedAgo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ElevatedButton(
                  onPressed: () {
                    // TODO: navigate to job detail / apply page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}