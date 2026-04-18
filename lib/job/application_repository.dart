// lib/job/application_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/data/local_db.dart';

class ApplicationRepository {
  final SupabaseClient _sb = Supabase.instance.client;

  String? get _uid => _sb.auth.currentUser?.id;

  // ============================================================================
  // CHECK EXISTING APPLICATION (excluding withdrawn)
  // ============================================================================

  Future<bool> checkExistingApplication(String jobId, String userId) async {
    try {
      final existing = await _sb
          .from('job_application')
          .select()
          .eq('job_id', jobId)
          .eq('user_id', userId)
          .neq('status', 'withdrawn')  // Exclude withdrawn applications
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
    String? coverLetter,
  }) async {
    try {
      final existing = await checkExistingApplication(jobId, userId);
      if (existing) {
        throw Exception('You have already applied for this job');
      }

      final now = DateTime.now().toIso8601String();
      final Map<String, dynamic> data = {
        'job_id': jobId,
        'user_id': userId,
        'resume_url': resumeUrl,
        'status': 'pending',
        'applied_at': now,
        'updated_at': now,
      };

      if (coverLetter != null && coverLetter.isNotEmpty) {
        data['cover_letter'] = coverLetter;
      }

      final response = await _sb
          .from('job_application')
          .insert(data)
          .select()
          .single();

      await LocalDB.cacheJobApplication(response as Map<String, dynamic>, userId);

      debugPrint('Application submitted successfully for job: $jobId');
      return response;
    } catch (e) {
      debugPrint('Error applying for job: $e');
      rethrow;
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
            *,
            job_post!job_application_job_id_fkey (
              job_id,
              job_title,
              description,
              location,
              salary_min,
              salary_max,
              job_type!job_post_job_type_id_fkey (name),
              company_profile!job_post_company_id_fkey (
                company_name,
                logo_url,
                location as company_location
              )
            )
          ''')
          .eq('user_id', userId)
          .neq('status', 'withdrawn')  // Don't show withdrawn applications
          .order('applied_at', ascending: false);

      final applications = List<Map<String, dynamic>>.from(response);
      final processedApps = <Map<String, dynamic>>[];

      for (final app in applications) {
        final processed = _processApplicationWithJob(app);
        processedApps.add(processed);
      }

      await LocalDB.cacheJobApplications(processedApps, userId);
      debugPrint('Fetched ${processedApps.length} applications from server');
      return processedApps;
    } catch (e) {
      debugPrint('Error fetching applications: $e');
      return LocalDB.getCachedJobApplications(userId);
    }
  }

  Map<String, dynamic> _processApplicationWithJob(Map<String, dynamic> app) {
    final jobData = app['job_post'] as Map<String, dynamic>?;
    final companyData = jobData?['company_profile'] as Map<String, dynamic>?;
    final jobTypeData = jobData?['job_type'] as Map<String, dynamic>?;

    return {
      'application_id': app['application_id'],
      'job_id': app['job_id'],
      'user_id': app['user_id'],
      'resume_url': app['resume_url'],
      'resume_file_name': app['resume_file_name'],
      'cover_letter': app['cover_letter'],
      'status': app['status'],
      'applied_at': app['applied_at'],
      'updated_at': app['updated_at'],
      'job_title': jobData?['job_title'] ?? 'Unknown Position',
      'company_name': companyData?['company_name'] ?? 'Unknown Company',
      'company_logo': companyData?['logo_url'],
      'location': jobData?['location'] ?? companyData?['company_location'] ?? 'Not specified',
      'salary_min': jobData?['salary_min'],
      'salary_max': jobData?['salary_max'],
      'job_type': jobTypeData?['name'] ?? 'Not specified',
      'description': jobData?['description'] ?? '',
    };
  }

  // ============================================================================
  // WITHDRAW APPLICATION (soft delete - set status to withdrawn)
  // ============================================================================

  Future<bool> withdrawApplication(String applicationId) async {
    try {
      final current = await _sb
          .from('job_application')
          .select('status')
          .eq('application_id', applicationId)
          .single();

      if (current['status'] != 'pending') {
        throw Exception('Cannot withdraw application that is already ${current['status']}');
      }

      // Soft delete - update status to withdrawn instead of deleting
      await _sb
          .from('job_application')
          .update({
        'status': 'withdrawn',
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('application_id', applicationId);

      final userId = _uid;
      if (userId != null) {
        // Remove from cache so it doesn't show in list
        await LocalDB.deleteCachedJobApplication(applicationId, userId);
      }

      debugPrint('Application withdrawn: $applicationId');
      return true;
    } catch (e) {
      debugPrint('Error withdrawing application: $e');
      return false;
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
      return applicants.map((app) => _processApplicantData(app)).toList();
    } catch (e) {
      debugPrint('Error fetching applicants: $e');
      return [];
    }
  }

  Map<String, dynamic> _processApplicantData(Map<String, dynamic> app) {
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

      final userId = _uid;
      if (userId != null) {
        await LocalDB.updateCachedApplicationStatus(applicationId, newStatus);
      }

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