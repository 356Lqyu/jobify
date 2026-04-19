
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobApplicationService {
  final supabase = Supabase.instance.client;

  // Apply for a job
  Future<void> applyForJob({
    required String jobId,
    required String userId,
    required String resumeUrl,
    String? coverLetter,
  }) async {
    await supabase.from('job_application').insert({
      'job_id': jobId,
      'user_id': userId,
      'resume_url': resumeUrl,
      'cover_letter': coverLetter,
      'status': 'pending',
      'applied_at': DateTime.now().toIso8601String(),
    });

    // Increment application count on job post
    try {
      await supabase.rpc('increment_application_count', params: {
        'job_id': jobId,
      });
    } catch (e) {
      // If RPC doesn't exist, just continue
      debugPrint('Note: increment_application_count RPC not implemented: $e');
    }
  }

  // Get applications by job seeker
  Future<List<Map<String, dynamic>>> getMyApplications({required String userId}) async {
    final response = await supabase
        .from('job_application')
        .select('''
          *,
          job_post!inner (
            job_id,
            job_title,
            location,
            salary_min,
            salary_max,
            job_type:job_type(name),
            company_profile!inner (
              company_name,
              logo_url
            )
          )
        ''')
        .eq('user_id', userId)
        .order('applied_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get applicants for a specific job (for employers)
  Future<List<Map<String, dynamic>>> getApplicantsForJob({required String jobId}) async {
    final response = await supabase
        .from('job_application')
        .select('''
          *,
          user:users!inner (
            user_id,
            fullname,
            email,
            phone,
            profile_image_url,
            job_seeker_profile (
              bio,
              address,
              date_of_birth
            )
          ),
          resume:resume!inner (
            file_url,
            file_name
          )
        ''')
        .eq('job_id', jobId)
        .order('applied_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get all applicants for all jobs of an employer
  Future<List<Map<String, dynamic>>> getAllApplicantsForEmployer({required String userId}) async {
    // First get all jobs created by this employer
    final jobsResponse = await supabase
        .from('job_post')
        .select('job_id, job_title')
        .eq('created_by', userId);

    final jobIds = (jobsResponse as List).map((job) => job['job_id']).toList();

    if (jobIds.isEmpty) return [];

    // Then get all applications for those jobs
    final response = await supabase
        .from('job_application')
        .select('''
          *,
          job_post!inner (
            job_id,
            job_title,
            location
          ),
          user:users!inner (
            user_id,
            fullname,
            email,
            phone,
            profile_image_url,
            job_seeker_profile (
              bio,
              address
            )
          ),
          resume:resume!inner (
            file_url,
            file_name
          )
        ''')
        .inFilter('job_id', jobIds)
        .order('applied_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Update application status
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    await supabase
        .from('job_application')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('application_id', applicationId);
  }

  // Withdraw application
  Future<void> withdrawApplication({required String applicationId}) async {
    await supabase
        .from('job_application')
        .update({'status': 'withdrawn', 'updated_at': DateTime.now().toIso8601String()})
        .eq('application_id', applicationId);
  }

  // Check if user has already applied for a job
  Future<bool> hasApplied({required String jobId, required String userId}) async {
    final response = await supabase
        .from('job_application')
        .select('application_id')
        .eq('job_id', jobId)
        .eq('user_id', userId)
        .neq('status', 'withdrawn')
        .maybeSingle();

    return response != null;
  }

  // Get application count for a job
  Future<int> getApplicationCount({required String jobId}) async {
    final response = await supabase
        .from('job_application')
        .select('application_id')
        .eq('job_id', jobId);

    return response.length;
  }
}