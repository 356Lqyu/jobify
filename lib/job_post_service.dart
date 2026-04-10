import 'package:supabase_flutter/supabase_flutter.dart';

class JobPostService {
  final supabase = Supabase.instance.client;

  // Fetch all job posts for the logged‑in employer
  Future<List<Map<String, dynamic>>> fetchMyJobPosts({String? userId}) async {
    final uid = userId ?? supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final response = await supabase
        .from('job_post')
        .select('''
          *,
          job_category(name),
          job_type(name),
          experience_level(name),
          company_profile(company_name)
        ''')
        .eq('created_by', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Fetch a single job post by ID (for editing/viewing)
  Future<Map<String, dynamic>?> fetchJobPostById(String jobId) async {
    final response = await supabase
        .from('job_post')
        .select('''
          *,
          job_category(name, job_category_id),
          job_type(name, job_type_id),
          experience_level(name, experience_level_id),
          company_profile(company_name, location, company_description, logo_url)
        ''')
        .eq('job_id', jobId)
        .maybeSingle();
    return response;
  }

  Future<List<Map<String, dynamic>>> fetchAllActiveJobs() async {
    final response = await supabase
        .from('job_post')
        .select('''
        *,
        job_category(name),
        job_type(name),
        experience_level(name),
        company_profile(company_name, logo_url)
      ''')
        .eq('status', 'active')
        .or('application_deadline.is.null,application_deadline.gt.now()')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Create a new job post
  Future<void> createJobPost(Map<String, dynamic> data) async {
    await supabase.from('job_post').insert(data);
  }

  // Update an existing job post
  Future<void> updateJobPost(String jobId, Map<String, dynamic> data) async {
    await supabase.from('job_post').update(data).eq('job_id', jobId);
  }

  // Delete a job post
  Future<void> deleteJobPost(String jobId) async {
    await supabase.from('job_post').delete().eq('job_id', jobId);
  }

  // ---------- Reference data (dropdowns) ----------
  Future<List<Map<String, dynamic>>> fetchJobCategories() async {
    final response = await supabase.from('job_category').select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchJobTypes() async {
    final response = await supabase.from('job_type').select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchExperienceLevels() async {
    final response = await supabase.from('experience_level').select();
    return List<Map<String, dynamic>>.from(response);
  }

  // Get the employer's company profile (needed for creating a job)
  Future<Map<String, dynamic>?> fetchMyCompanyProfile({String? userId}) async {
    final uid = userId ?? supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final response = await supabase
        .from('company_profile')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    return response;
  }


}