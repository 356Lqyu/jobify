// ═══════════════════════════════════════════════════════════════════════════
// job_repository.dart
// Supabase operations for job management + discovery listing.
// Falls back to SQLite cache on error.
// Reference tables cached locally. Saved jobs stored locally.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/social/post_feed_setting.dart';
import 'local_db.dart';
import 'feed_repository.dart';

class JobRepository {
  final SupabaseClient _sb = Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;

  // ══════════════════════════════════════════════════════════════════════════
  // REFERENCE DATA (cached locally, fetched once per session)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchJobCategories() async {
    try {
      final rows = await _sb.from('job_category').select() as List<dynamic>;
      final data = rows.cast<Map<String, dynamic>>();
      await LocalDB.cacheReferenceTable('job_category', data);
      return data;
    } catch (e) {
      debugPrint('fetchJobCategories error: $e');
      return await LocalDB.getCachedReferenceTable('job_category');
    }
  }

  Future<List<Map<String, dynamic>>> fetchJobTypes() async {
    try {
      final rows = await _sb.from('job_type').select() as List<dynamic>;
      final data = rows.cast<Map<String, dynamic>>();
      await LocalDB.cacheReferenceTable('job_type', data);
      return data;
    } catch (e) {
      debugPrint('fetchJobTypes error: $e');
      return await LocalDB.getCachedReferenceTable('job_type');
    }
  }

  Future<List<Map<String, dynamic>>> fetchExperienceLevels() async {
    try {
      final rows = await _sb.from('experience_level').select() as List<dynamic>;
      final data = rows.cast<Map<String, dynamic>>();
      await LocalDB.cacheReferenceTable('experience_level', data);
      return data;
    } catch (e) {
      debugPrint('fetchExperienceLevels error: $e');
      return await LocalDB.getCachedReferenceTable('experience_level');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCompanyBranches(String companyId, {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cached = await LocalDB.getCachedBranches(companyId);
        if (cached.isNotEmpty) return cached;
      }
      final data = await _sb
          .from('company_branch')
          .select()
          .eq('company_id', companyId);
      final branches = List<Map<String, dynamic>>.from(data);
      await LocalDB.cacheBranches(companyId, branches);
      return branches;
    } catch (e) {
      debugPrint('fetchCompanyBranches error: $e');
      return await LocalDB.getCachedBranches(companyId);
    }
  }

  Future<Map<String, dynamic>?> fetchBranchById(String branchId) async {
    try {
      return await _sb
          .from('company_branch')
          .select()
          .eq('branch_id', branchId)
          .maybeSingle();
    } catch (e) {
      debugPrint('fetchBranchById error: $e');
      return null;
    }
  }

  Future<void> prefetchReferenceData() async {
    await Future.wait([
      fetchJobCategories(),
      fetchJobTypes(),
      fetchExperienceLevels(),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMPANY PROFILE (needed for job creation)
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> fetchMyCompanyProfile({String? userId}) async {
    final uid = userId ?? _uid;
    if (uid == null) return null;
    try {
      return await _sb
          .from('company_profile')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
    } catch (e) {
      debugPrint('fetchMyCompanyProfile error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JOB POSTS – EMPLOYER MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchMyJobPosts({String? userId}) async {
    final uid = userId ?? _uid;
    if (uid == null) return [];
    try {
      final rows = await _sb
          .from('job_post')
          .select('''
          *,
          job_category_id(job_category_id, name),
          job_type_id(job_type_id, name),
          experience_level_id(experience_level_id, name)
        ''')
          .eq('created_by', uid)
          .order('created_at', ascending: false) as List<dynamic>;
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchMyJobPosts error: $e');
      // Fallback to cached flat maps
      return await LocalDB.getCachedJobMapsByUser(uid);
    }
  }

  Future<Map<String, dynamic>?> fetchJobPostById(String jobId) async {
    try {
      return await _sb
          .from('job_post')
          .select('''
            *,
            job_category_id(name, job_category_id),
            job_type_id(name, job_type_id),
            experience_level_id(name, experience_level_id),
            company_id(company_name, location, company_description, logo_url)
          ''')
          .eq('job_id', jobId)
          .maybeSingle();
    } catch (e) {
      debugPrint('fetchJobPostById error: $e');
      return null;
    }
  }

  /// Create a job post and optionally auto-create a social feed post
  Future<String?> createJobPost(Map<String, dynamic> data,
      {bool autoCreateSocialPost = true}) async {
    try {
      final resp = await _sb.from('job_post').insert(data).select().single();
      final jobId = resp['job_id'] as String;

      if (autoCreateSocialPost) {
        // Get company name for the social post
        final company = await fetchMyCompanyProfile(userId: data['created_by']);
        final companyName = company?['company_name'] ?? 'the company';
        final jobTitle = data['job_title'] ?? 'New Position';

        final feedRepo = FeedRepository();
        await feedRepo.autoCreateJobPost(
          userId: data['created_by'],
          companyId: data['company_id'],
          jobId: jobId,
          jobTitle: jobTitle,
          companyName: companyName,
        );
      }

      return jobId;
    } catch (e) {
      debugPrint('createJobPost error: $e');
      return null;
    }
  }

  Future<int> updateJobPost(String jobId, Map<String, dynamic> data) async {
    final resp = await _sb
        .from('job_post')
        .update(data)
        .eq('job_id', jobId)
        .select();
    await LocalDB.deleteJobPost(jobId);
    return resp.length;
  }

  Future<void> deleteJobPost(String jobId) async {
    await _sb.from('job_post').delete().eq('job_id', jobId);
    await LocalDB.deleteJobPost(jobId);
  }

  Future<void> incrementViewCount(String jobId) async {
    await _sb.rpc('increment_view_count', params: {'job_id_param': jobId});
  }

  Future<void> incrementApplicationCount(String jobId) async {
    await _sb.rpc('increment_application_count', params: {'job_id_param': jobId});
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JOB POSTS – DISCOVERY / LISTING (cached subset)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<JobPost>> fetchJobs({
    String? keyword,
    String? jobType,
    String? experienceLevel,
    String? location,
    double? salaryMin,
    bool remoteOnly = false,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      var query = _sb.from('job_post').select('''
        job_id, company_id, created_by, job_title, description,
        location, remote_option, salary_min, salary_max,
        vacancy_count, application_deadline, status,
        view_count, application_count, created_at,
        image_urls, video_url,
        company_profile!job_post_company_id_fkey ( company_name, logo_url, industry ),
        job_type!job_post_job_type_id_fkey ( name ),
        job_category!job_post_job_category_id_fkey ( name ),
        experience_level!job_post_experience_level_id_fkey ( name )
      ''').eq('status', 'active');

      if (remoteOnly) query = query.eq('remote_option', true);
      if (location != null && location.isNotEmpty) {
        query = query.ilike('location', '%$location%');
      }
      if (salaryMin != null) {
        query = query.gte('salary_max', salaryMin);
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1) as List<dynamic>;

      final savedIds = _uid != null
          ? (await LocalDB.getSavedJobIds(_uid!)).toSet()
          : <String>{};

      final jobs = <JobPost>[];
      for (final row in rows) {
        final r = row as Map<String, dynamic>;
        final compRow = r['company_profile'] as Map<String, dynamic>?;
        final jt = (r['job_type'] as Map<String, dynamic>?)?['name'] as String? ?? '';
        final jc = (r['job_category'] as Map<String, dynamic>?)?['name'] as String? ?? '';
        final el = (r['experience_level'] as Map<String, dynamic>?)?['name'] as String? ?? '';

        // Client‑side filters
        if (jobType != null && jobType != 'All' && jt != jobType) continue;
        if (experienceLevel != null && experienceLevel != 'All' && el != experienceLevel) continue;
        if (keyword != null && keyword.isNotEmpty) {
          final q = keyword.toLowerCase();
          final title = (r['job_title'] as String).toLowerCase();
          final cname = (compRow?['company_name'] as String? ?? '').toLowerCase();
          if (!title.contains(q) && !cname.contains(q)) continue;
        }

        final jid = r['job_id'] as String;
        jobs.add(JobPost.fromSupabase(
          r,
          companyName: compRow?['company_name'] as String? ?? '',
          companyLogoUrl: compRow?['logo_url'] as String?,
          companyIndustry: compRow?['industry'] as String?,
          jobType: jt,
          jobCategory: jc,
          experienceLevel: el,
          isSaved: savedIds.contains(jid),
        ));
      }

      await LocalDB.insertJobs(jobs);
      return jobs;
    } catch (e, st) {
      debugPrint('fetchJobs error: $e\n$st');
      return LocalDB.getCachedJobs(
        jobType: jobType == 'All' ? null : jobType,
        experienceLevel: experienceLevel == 'All' ? null : experienceLevel,
        salaryMin: salaryMin,
        keyword: keyword,
        remoteOnly: remoteOnly,
        limit: limit,
        offset: offset,
      );
    }
  }

  Future<JobPost?> fetchJobById(String jobId) async {
    try {
      final r = await _sb.from('job_post').select('''
        job_id, company_id, created_by, job_title, description,
        location, remote_option, salary_min, salary_max,
        vacancy_count, application_deadline, status,
        view_count, application_count, created_at,
        image_urls, video_url,
        company_profile!job_post_company_id_fkey ( company_name, logo_url, industry ),
        job_type!job_post_job_type_id_fkey ( name ),
        job_category!job_post_job_category_id_fkey ( name ),
        experience_level!job_post_experience_level_id_fkey ( name )
      ''').eq('job_id', jobId).maybeSingle();

      if (r == null) return null;

      final compRow = r['company_profile'] as Map<String, dynamic>?;
      return JobPost.fromSupabase(
        r,
        companyName: compRow?['company_name'] as String? ?? '',
        companyLogoUrl: compRow?['logo_url'] as String?,
        companyIndustry: compRow?['industry'] as String?,
        jobType: (r['job_type'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        jobCategory: (r['job_category'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        experienceLevel: (r['experience_level'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('fetchJobById error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVE JOB (LOCAL ONLY – can be extended to remote)
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> toggleSaveJob(String jobId, bool currentlySaved) async {
    if (_uid == null) return currentlySaved;
    final newSaved = !currentlySaved;
    try {
      await LocalDB.setJobSaved(jobId, newSaved, _uid!);
      return newSaved;
    } catch (e) {
      debugPrint('toggleSaveJob error: $e');
      return currentlySaved;
    }
  }
}