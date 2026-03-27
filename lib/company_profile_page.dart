import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyProfilePage extends StatefulWidget {
  final String companyId;

  const CompanyProfilePage({super.key, required this.companyId});

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  final supabase = Supabase.instance.client;

  bool isFollowing = false;
  bool isLoading = true;

  // Company Data
  String companyName = '';
  String industry = '';
  String description = '';
  String location = '';
  String size = '';
  String founded = '';

  int employeesCount = 0;
  int openJobsCount = 0;
  int followersCount = 0;

  // Mock lists for now; you can replace with Supabase query later
  List<Map<String, String>> jobs = [];
  List<Map<String, String>> posts = [];

  @override
  void initState() {
    super.initState();
    fetchCompanyProfile();
  }

  Future<void> fetchCompanyProfile() async {
    try {
      final companyData = await supabase
          .from('company_profile')
          .select()
          .eq('user_id', widget.companyId)
          .single();

      setState(() {
        companyName = companyData['company_name'] ?? '';
        industry = companyData['industry'] ?? '';
        description = companyData['company_description'] ?? '';
        location = companyData['location'] ?? '';
        size = companyData['company_size'] ?? '';
        founded = companyData['founded'] ?? '';

        employeesCount = companyData['employees_count'] ?? 0;
        openJobsCount = companyData['open_jobs_count'] ?? 0;
        followersCount = companyData['followers_count'] ?? 0;

        // Mock jobs and posts for UI
        jobs = [
          {'title': 'Senior Frontend Developer', 'location': 'Remote', 'type': 'Full-time'},
          {'title': 'Backend Engineer', 'location': 'New York, NY', 'type': 'Full-time'},
        ];
        posts = [
          {'content': 'Excited about our new launch!', 'time': '2 days ago'},
          {'content': 'Our team has grown to 200+!', 'time': '1 week ago'},
        ];

        isLoading = false;
      });
    } catch (e) {
      print('Error fetching company profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void toggleFollow() {
    setState(() {
      isFollowing = !isFollowing;
    });
  }

  Widget buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(companyName.isEmpty ? 'Company Profile' : companyName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// Company Header
            buildCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.business, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(companyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(industry, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? Colors.grey[300] : Colors.blue,
                              ),
                              child: Text(isFollowing ? 'Following' : 'Follow',
                                  style: TextStyle(color: isFollowing ? Colors.black : Colors.white)),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      buildStatItem(employeesCount.toString(), 'Employees'),
                      buildStatItem(openJobsCount.toString(), 'Open Jobs'),
                      buildStatItem(followersCount.toString(), 'Followers'),
                    ],
                  ),
                ],
              ),
            ),

            /// About
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('About', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description),
                  const SizedBox(height: 8),
                  Text('Location: $location', style: const TextStyle(color: Colors.grey)),
                  Text('Company Size: $size', style: const TextStyle(color: Colors.grey)),
                  Text('Founded: $founded', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),

            /// Open Positions
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Open Positions', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${jobs.length} jobs', style: const TextStyle(color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...jobs.map((job) => GestureDetector(
                    onTap: () {}, // Navigate to job detail
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(job['location']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(job['type']!, style: const TextStyle(color: Colors.blue, fontSize: 10)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),

            /// Recent Posts
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Posts', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...posts.map((post) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post['content']!),
                        const SizedBox(height: 4),
                        Text(post['time']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}