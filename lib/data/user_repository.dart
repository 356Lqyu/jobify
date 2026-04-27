import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/data/local_db.dart';

/// handle read and write user data to supabase & manage local SQLite cache
/// CRUD user profile , skill, education and experience
/// Try cache first (unless force refresh)
/// if forceRefresh = false , then will check local cache
/// else , fetch from supabase , then cache and return
class UserRepository {
  final SupabaseClient _sb = Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;    // get the current authenticated user id

  /// Get current user with cache-first strategy
  Future<Users?> getCurrentUser({bool forceRefresh = false}) async {
    final userId = _uid;
    if (userId == null)
      return null;


    if (!forceRefresh) {
      final cached = await LocalDB.getCachedUser(userId);
      if (cached != null) {
        debugPrint('Using cached user data for: $userId');
        return cached;
      }
    }

    // Fetch from Supabase
    try {
      debugPrint('Fetching user data from Supabase for: $userId');
      final data = await _sb
          .from('users')
          .select('user_id, role, profile_image_url, created_at, updated_at, email, fullname, phone')
          .eq('user_id', userId)
          .single();

      final user = Users.fromJson(data);

      // Cache for future request
      await LocalDB.cacheUser(user);
      debugPrint('Cached user data for: $userId');

      return user;
    } catch (e) {
      debugPrint('Error fetching user: $e');
      // if error then will fallback to expired cache (local db)
      return await LocalDB.getCachedUser(userId);
    }
  }

  /// Get complete profile (with all related data)
  /// Fetch user , skills , education , experience
  Future<CompleteUserProfile> getCompleteProfile({bool forceRefresh = false}) async {
    final userId = _uid;
    if (userId == null) throw Exception('User not logged in');

    final profile = CompleteUserProfile(userId: userId);

    // Try to load from cache first
    if (!forceRefresh) {
      final cachedUser = await LocalDB.getCachedUser(userId);
      if (cachedUser != null) {
        profile.user = cachedUser;
        profile.jobSeekerProfile = await LocalDB.getCachedJobSeekerProfile(userId);
        profile.companyProfile = await LocalDB.getCachedCompanyProfile(userId);
        profile.skills = await LocalDB.getCachedSkills(userId);
        profile.education = await LocalDB.getCachedEducation(userId);
        profile.experience = await LocalDB.getCachedExperience(userId);

        // If have cached user, then return immediately but refresh in background
        if (profile.user != null) {
          _refreshProfileInBackground(userId, profile);
          return profile;
        }
      }
    }
    // Fetch fresh from Supabase (force refresh)
    return await _fetchFreshProfile(userId);
  }

  /// Fetch complete user profile directly from supabase (no cache)
  Future<CompleteUserProfile> _fetchFreshProfile(String userId) async {
    final profile = CompleteUserProfile(userId: userId);

    // Fetch basic user info
    final userData = await _sb
        .from('users')
        .select()
        .eq('user_id', userId)
        .single();
    profile.user = Users.fromJson(userData);
    await LocalDB.cacheUser(profile.user!);

    // Fetch role-specific profile (job seeker / poster)
    if (profile.user!.role == 'JOB_SEEKER') {
      final jobSeekerData = await _sb
          .from('job_seeker_profile')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (jobSeekerData != null) {
        profile.jobSeekerProfile = Map<String, dynamic>.from(jobSeekerData);
        await LocalDB.cacheJobSeekerProfile(userId, profile.jobSeekerProfile!);
      }
    } else if (profile.user!.role == 'POSTER') {
      final companyData = await _sb
          .from('company_profile')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (companyData != null) {
        profile.companyProfile = Map<String, dynamic>.from(companyData);
        await LocalDB.cacheCompanyProfile(userId, profile.companyProfile!);
      }
    }

    // Fetch skills, education , work experience
    final skillsData = await _sb
        .from('skills')
        .select()
        .eq('user_id', userId);
    profile.skills = List<Map<String, dynamic>>.from(skillsData);
    await LocalDB.cacheSkills(userId, profile.skills);

    final educationData = await _sb
        .from('education')
        .select()
        .eq('user_id', userId);
    profile.education = List<Map<String, dynamic>>.from(educationData);
    await LocalDB.cacheEducation(userId, profile.education);

    final experienceData = await _sb
        .from('experience')
        .select()
        .eq('user_id', userId);
    profile.experience = List<Map<String, dynamic>>.from(experienceData);
    await LocalDB.cacheExperience(userId, profile.experience);

    return profile;
  }

  /// Perform background refresh of user profile data
  /// this run without awaiting , allow UI to show cached data immediately while fresh data load in background
  /// When refresh complete, then it will update current profile object
  Future<void> _refreshProfileInBackground(String userId, CompleteUserProfile currentProfile) async {
    try {
      final freshProfile = await _fetchFreshProfile(userId);
      currentProfile.updateFrom(freshProfile);
    } catch (e) {
      debugPrint('Background refresh failed: $e');
    }
  }

  /// All write operation will update/insert in supabase , then invalidate local cache by clearUserCache, then next read will fetch fresh data and recache
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await _sb
        .from('users')
        .update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('user_id', userId);

    /// Invalidate cache to force fetch on next read
    await LocalDB.clearUserCache(userId);
  }

  /// Update job seeker profile
  Future<void> updateJobSeekerProfile(String userId, Map<String, dynamic> updates) async {
    final existing = await _sb
        .from('job_seeker_profile')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    /// if not exist then insert ; else update
    if (existing == null) {
      await _sb.from('job_seeker_profile').insert({
        'user_id': userId,
        ...updates,
      });
    } else {
      await _sb
          .from('job_seeker_profile')
          .update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', userId);
    }

    // Invalidate cache
    await LocalDB.clearUserCache(userId);
  }

  /// Update company profile
  Future<void> updateCompanyProfile(String userId, Map<String, dynamic> updates) async {
    final existing = await _sb
        .from('company_profile')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await _sb.from('company_profile').insert({
        'user_id': userId,
        ...updates,
      });
    } else {
      await _sb
          .from('company_profile')
          .update(updates)
          .eq('user_id', userId);
    }

    // Invalidate cache
    await LocalDB.clearUserCache(userId);
  }

  // insert , update , delete for skill , education and work experience
  Future<void> addSkill(String userId, String skillName, String? skillLevel) async {
    await _sb.from('skills').insert({
      'user_id': userId,
      'skill_name': skillName,
      'skill_level': skillLevel,
    });
    await LocalDB.clearUserCache(userId);
  }

  Future<void> updateSkill(String skillId, String skillName, String? skillLevel) async {
    final userId = _uid;
    if (userId == null) return;
    await _sb
        .from('skills')
        .update({
      'skill_name': skillName,
      'skill_level': skillLevel,
    })
        .eq('skill_id', skillId);
    await LocalDB.clearUserCache(userId);
  }

  Future<void> deleteSkill(String skillId) async {
    final userId = _uid;
    if (userId == null) return;
    await _sb.from('skills').delete().eq('skill_id', skillId);
    await LocalDB.clearUserCache(userId);
  }

  Future<void> addEducation(String userId, Map<String, dynamic> education) async {
    await _sb.from('education').insert({
      'user_id': userId,
      ...education,
    });
    await LocalDB.clearUserCache(userId);
  }

  Future<void> updateEducation(String educationId, Map<String, dynamic> updates) async {
    final userId = _uid;
    if (userId == null) return;
    await _sb
        .from('education')
        .update(updates)
        .eq('education_id', educationId);
    await LocalDB.clearUserCache(userId);
  }

  Future<void> deleteEducation(String educationId) async {
    final userId = _uid;
    if (userId == null) return;
    await _sb.from('education').delete().eq('education_id', educationId);
    await LocalDB.clearUserCache(userId);
  }

  Future<void> addExperience(String userId, Map<String, dynamic> experience) async {
    await _sb.from('experience').insert({
      'user_id': userId,
      ...experience,
    });
    await LocalDB.clearUserCache(userId);
  }

  Future<void> updateExperience(String experienceId, Map<String, dynamic> updates) async {
    final userId = _uid;
    if (userId == null) return;
    await _sb
        .from('experience')
        .update(updates)
        .eq('experience_id', experienceId);
    await LocalDB.clearUserCache(userId);
  }

  Future<void> deleteExperience(String experienceId) async {
    final userId = _uid;
    if (userId == null) return;
    await _sb.from('experience').delete().eq('experience_id', experienceId);
    await LocalDB.clearUserCache(userId);
  }

  Future<void> addBranch(String companyId, Map<String, dynamic> branchData) async {
    final userId = _uid;
    if (userId == null) return;

    try {
      // If this branch is being marked as head office, unset any existing head office
      if (branchData['is_head_office'] == true) {
        await _sb
            .from('company_branch')
            .update({'is_head_office': false})
            .eq('company_id', companyId)
            .eq('is_head_office', true);
      }

      // Create a copy and remove any null values that should be null in DB
      final cleanedData = Map<String, dynamic>.from(branchData);

      // Only keep city if it's not null and not empty
      if (cleanedData['city'] == null || cleanedData['city'].toString().isEmpty) {
        cleanedData['city'] = null;
      }

      cleanedData.removeWhere((key, value) => value == null);

      debugPrint('Adding branch with cleaned data: $cleanedData');

      await _sb.from('company_branch').insert({
        'company_id': companyId,
        ...branchData,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await LocalDB.clearUserCache(userId);
    } catch (e) {
      debugPrint('Error adding branch: $e');
      rethrow;
    }
  }

  Future<void> updateBranch(String branchId, Map<String, dynamic> updates) async {
    final userId = _uid;
    if (userId == null) return;

    try {
      // First, get the company_id for this branch
      final branch = await _sb
          .from('company_branch')
          .select('company_id')
          .eq('branch_id', branchId)
          .maybeSingle();

      // If this branch is being marked as head office, unset any existing head office
      if (updates['is_head_office'] == true && branch != null) {
        await _sb
            .from('company_branch')
            .update({'is_head_office': false})
            .eq('company_id', branch['company_id'])
            .eq('is_head_office', true)
            .not('branch_id', 'eq', branchId); // Don't unset the current branch if it was already head office
      }

      await _sb
          .from('company_branch')
          .update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('branch_id', branchId);
      await LocalDB.clearUserCache(userId);
    } catch (e) {
      debugPrint('Error updating branch: $e');
      rethrow;
    }
  }

  Future<void> deleteBranch(String branchId) async {
    final userId = _uid;
    if (userId == null) return;

    try {
      await _sb.from('company_branch').delete().eq('branch_id', branchId);
      await LocalDB.clearUserCache(userId);
    } catch (e) {
      debugPrint('Error deleting branch: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBranches(String companyId) async {
    try {
      final response = await _sb
          .from('company_branch')
          .select()
          .eq('company_id', companyId)
          .order('is_head_office', ascending: false)
          .order('branch_name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching branches: $e');
      return [];
    }
  }

  // pre-cache all user data immediately after login
  Future<void> cacheFullProfileAfterLogin(String userId) async {
    try {
      debugPrint('Caching full profile for user: $userId');
      await _fetchFreshProfile(userId);
      debugPrint('Full profile cached successfully');
    } catch (e) {
      debugPrint('Error caching full profile: $e');
    }
  }
}

// Pass complete user data between screen
class CompleteUserProfile {
  final String userId;
  Users? user;
  Map<String, dynamic>? jobSeekerProfile;
  Map<String, dynamic>? companyProfile;
  List<Map<String, dynamic>> skills = [];
  List<Map<String, dynamic>> education = [];
  List<Map<String, dynamic>> experience = [];

  CompleteUserProfile({required this.userId});

  void updateFrom(CompleteUserProfile other) {
    user = other.user;
    jobSeekerProfile = other.jobSeekerProfile;
    companyProfile = other.companyProfile;
    skills = other.skills;
    education = other.education;
    experience = other.experience;
  }

  bool get isLoading => user == null;
}
