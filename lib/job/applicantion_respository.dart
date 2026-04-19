// lib/job/applicantion_respository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/data/local_db.dart';

class ApplicationRepository {
  final SupabaseClient _sb = Supabase.instance.client;

  String? get _uid => _sb.auth.currentUser?.id;

  // ============================================================================
  // CHECK EXISTING APPLICATION
  // ============================================================================

  Future<bool> checkExistingApplication(String jobId, String userId) async {
    try {
      final existing = await _sb
          .from('job_application')
          .select()
          .eq('job_id', jobId)
          .eq('user_id', userId)
          .neq('status', 'withdrawn')
          .maybeSingle();
      return existing != null;
    } catch (e) {
      debugPrint('Error checking application: $e');
      return false;
    }
  }

  // ============================================================================
  // APPLY FOR JOB
  // ============================================================================

  Future<Map<String, dynamic>?> applyForJob({
    required String jobId,
    required String userId,
    required String resumeUrl,
    String? resumeFileName,
    String? coverLetter,
  }) async {
    try {
      // Check if already applied
      final existing = await checkExistingApplication(jobId, userId);
      if (existing) {
        throw Exception('You have already applied for this job');
      }

      final now = DateTime.now().toIso8601String();
      final Map<String, dynamic> data = {
        'job_id': jobId,
        'user_id': userId,
        'resume_url': resumeUrl,
        'resume_file_name': resumeFileName ?? 'Resume.pdf',
        'cover_letter': coverLetter,
        'status': 'pending',
        'applied_at': now,
        'updated_at': now,
      };

      final response = await _sb
          .from('job_application')
          .insert(data)
          .select()
          .single();

      // Increment application count on job post
      try {
        final jobData = await _sb
            .from('job_post')
            .select('application_count')
            .eq('job_id', jobId)
            .maybeSingle();

        final currentCount = (jobData?['application_count'] as int?) ?? 0;

        await _sb
            .from('job_post')
            .update({'application_count': currentCount + 1})
            .eq('job_id', jobId);
      } catch (e) {
        debugPrint('Error updating application count: $e');
      }

      // Get job details for the response
      final jobDetails = await _getJobDetails(jobId);

      if (jobDetails != null) {
        final applicationWithJob = {
          ...response as Map<String, dynamic>,
          'job_title': jobDetails['job_title'] ?? 'Unknown Position',
          'company_name': jobDetails['company_profile']?['company_name'] ??
              jobDetails['company_name'] ?? 'Unknown Company',
          'company_logo': jobDetails['company_profile']?['logo_url'],
          'location': jobDetails['location'] ?? 'Not specified',
          'salary_min': jobDetails['salary_min'],
          'salary_max': jobDetails['salary_max'],
          'job_type': jobDetails['job_type']?['name'] ?? 'Not specified',
          'description': jobDetails['description'] ?? '',
        };

        await LocalDB.cacheJobApplication(applicationWithJob, userId);
        return applicationWithJob;
      }

      return response;
    } catch (e) {
      debugPrint('Error applying for job: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getJobDetails(String jobId) async {
    try {
      final response = await _sb
          .from('job_post')
          .select('''
            job_id,
            job_title,
            description,
            location,
            salary_min,
            salary_max,
            job_type:job_type_id(name),
            company_profile:company_id(
              company_name,
              logo_url
            )
          ''')
          .eq('job_id', jobId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching job details: $e');
      return null;
    }
  }

  // ============================================================================
  // GET MY APPLICATIONS
  // ============================================================================

  Future<List<Map<String, dynamic>>> getMyApplications({
    bool forceRefresh = false,
  }) async {
    final userId = _uid;
    if (userId == null) return [];

    // Try cache first
    if (!forceRefresh) {
      final cached = await LocalDB.getCachedJobApplications(userId);
      if (cached.isNotEmpty) {
        debugPrint('Returning ${cached.length} cached applications');
        return cached;
      }
    }

    try {
      final response = await _sb
          .from('job_application')
          .select('''
            application_id,
            job_id,
            user_id,
            resume_url,
            resume_file_name,
            cover_letter,
            status,
            applied_at,
            updated_at,
            job_post:job_id (
              job_id,
              job_title,
              description,
              location,
              salary_min,
              salary_max,
              job_type:job_type_id (
                name
              ),
              company_profile:company_id (
                company_name,
                logo_url
              )
            )
          ''')
          .eq('user_id', userId)
          .neq('status', 'withdrawn')
          .order('applied_at', ascending: false);

      debugPrint('Raw response from Supabase: ${response.length} records');

      final List<Map<String, dynamic>> applications = [];

      for (final app in response) {
        final jobData = app['job_post'] as Map<String, dynamic>?;

        if (jobData == null) {
          debugPrint('Warning: No job data found for application ${app['application_id']}');
          continue;
        }

        final companyData = jobData['company_profile'] as Map<String, dynamic>?;
        final jobTypeData = jobData['job_type'] as Map<String, dynamic>?;

        final processedApp = {
          'application_id': app['application_id'],
          'job_id': app['job_id'],
          'user_id': app['user_id'],
          'resume_url': app['resume_url'],
          'resume_file_name': app['resume_file_name'],
          'cover_letter': app['cover_letter'],
          'status': app['status'],
          'applied_at': app['applied_at'],
          'updated_at': app['updated_at'],
          'job_title': jobData['job_title'] ?? 'Unknown Position',
          'company_name': companyData?['company_name'] ?? 'Unknown Company',
          'company_logo': companyData?['logo_url'],
          'location': jobData['location'] ?? 'Not specified',
          'salary_min': jobData['salary_min'],
          'salary_max': jobData['salary_max'],
          'job_type': jobTypeData?['name'] ?? 'Not specified',
          'description': jobData['description'] ?? '',
        };

        debugPrint('Processed application: ${processedApp['job_title']} - ${processedApp['status']}');
        applications.add(processedApp);
      }

      await LocalDB.cacheJobApplications(applications, userId);
      debugPrint('Fetched ${applications.length} applications from server');

      return applications;
    } catch (e) {
      debugPrint('Error fetching applications: $e');
      return LocalDB.getCachedJobApplications(userId);
    }
  }

  // ============================================================================
  // WITHDRAW APPLICATION - HARD DELETE
  // ============================================================================

  Future<bool> withdrawApplication(String applicationId) async {
    try {
      debugPrint('=== WITHDRAW APPLICATION STARTED ===');
      debugPrint('Application ID: $applicationId');

      // First, check if application exists and get its status
      final existingApp = await _sb
          .from('job_application')
          .select('application_id, status, job_id')
          .eq('application_id', applicationId)
          .maybeSingle();

      debugPrint('Existing application: $existingApp');

      if (existingApp == null) {
        debugPrint('Application not found in database');
        return false;
      }

      if (existingApp['status'] != 'pending') {
        debugPrint('Cannot withdraw application with status: ${existingApp['status']}');
        return false;
      }

      final jobId = existingApp['job_id'];
      debugPrint('Job ID: $jobId');

      // HARD DELETE - Remove from database completely
      await _sb
          .from('job_application')
          .delete()
          .eq('application_id', applicationId);

      debugPrint('Delete request sent to Supabase');

      // Verify deletion
      final verifyDelete = await _sb
          .from('job_application')
          .select('application_id')
          .eq('application_id', applicationId)
          .maybeSingle();

      debugPrint('After deletion check: $verifyDelete');

      // Update application count on job post
      try {
        final jobData = await _sb
            .from('job_post')
            .select('application_count')
            .eq('job_id', jobId)
            .maybeSingle();

        final currentCount = (jobData?['application_count'] as int?) ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;

        await _sb
            .from('job_post')
            .update({'application_count': newCount})
            .eq('job_id', jobId);

        debugPrint('Updated application count from $currentCount to $newCount');
      } catch (e) {
        debugPrint('Error updating application count: $e');
      }

      // Clear local cache
      final userId = _uid;
      if (userId != null) {
        await LocalDB.deleteCachedJobApplication(applicationId, userId);
        debugPrint('Removed from local cache');
      }

      debugPrint('=== APPLICATION WITHDRAWN SUCCESSFULLY ===');
      return true;

    } catch (e) {
      debugPrint('Error in withdrawApplication: $e');
      return false;
    }
  }

  // ============================================================================
  // GET USER APPLICATION COUNT
  // ============================================================================

  Future<int> getUserApplicationCount(String userId) async {
    try {
      final response = await _sb
          .from('job_application')
          .select('application_id')
          .eq('user_id', userId)
          .neq('status', 'withdrawn');

      final List<dynamic> results = response as List<dynamic>;
      return results.length;
    } catch (e) {
      debugPrint('Error getting application count: $e');
      return 0;
    }
  }

  // ============================================================================
  // POSTER: GET APPLICANTS FOR A JOB
  // ============================================================================

  Future<List<Map<String, dynamic>>> getApplicantsForJob(String jobId) async {
    try {
      final response = await _sb
          .from('job_application')
          .select('''
            *,
            users!job_application_user_id_fkey (
              user_id,
              fullname,
              email,
              phone,
              profile_image_url,
              job_seeker_profile!job_seeker_profile_user_id_fkey (
                bio,
                address,
                date_of_birth,
                gender
              )
            )
          ''')
          .eq('job_id', jobId)
          .neq('status', 'withdrawn')
          .order('applied_at', ascending: false);

      final applicants = List<Map<String, dynamic>>.from(response);

      return applicants.map((app) {
        final userData = app['users'] as Map<String, dynamic>?;
        final profileData = userData?['job_seeker_profile'] as Map<String, dynamic>?;

        return {
          'application_id': app['application_id'],
          'job_id': app['job_id'],
          'status': app['status'],
          'applied_at': app['applied_at'],
          'updated_at': app['updated_at'],
          'resume_url': app['resume_url'],
          'resume_file_name': app['resume_file_name'],
          'cover_letter': app['cover_letter'],
          'user': {
            'user_id': userData?['user_id'],
            'fullname': userData?['fullname'] ?? 'Unknown',
            'email': userData?['email'] ?? '',
            'phone': userData?['phone'] ?? 'Not provided',
            'profile_image_url': userData?['profile_image_url'],
            'bio': profileData?['bio'] ?? 'No bio provided',
            'address': profileData?['address'] ?? 'Not specified',
            'date_of_birth': profileData?['date_of_birth'],
            'gender': profileData?['gender'],
          },
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching applicants: $e');
      return [];
    }
  }

  // ============================================================================
  // POSTER: UPDATE APPLICATION STATUS
  // ============================================================================

  Future<bool> updateApplicationStatus({
    required String applicationId,
    required String newStatus,
  }) async {
    try {
      final validStatuses = ['pending', 'accepted', 'rejected'];
      if (!validStatuses.contains(newStatus)) {
        throw Exception('Invalid status: $newStatus');
      }

      final updates = {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _sb
          .from('job_application')
          .update(updates)
          .eq('application_id', applicationId);

      await LocalDB.updateCachedApplicationStatus(applicationId, newStatus);

      debugPrint('Application $applicationId status updated to: $newStatus');
      return true;
    } catch (e) {
      debugPrint('Error updating application status: $e');
      return false;
    }
  }

  // ============================================================================
  // GET APPLICATION STATISTICS
  // ============================================================================

  Future<Map<String, int>> getApplicationStats(String jobId) async {
    try {
      final response = await _sb
          .from('job_application')
          .select('status')
          .eq('job_id', jobId)
          .neq('status', 'withdrawn');

      final apps = List<Map<String, dynamic>>.from(response);

      return {
        'total': apps.length,
        'pending': apps.where((a) => a['status'] == 'pending').length,
        'accepted': apps.where((a) => a['status'] == 'accepted').length,
        'rejected': apps.where((a) => a['status'] == 'rejected').length,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {'total': 0, 'pending': 0, 'accepted': 0, 'rejected': 0};
    }
  }
}