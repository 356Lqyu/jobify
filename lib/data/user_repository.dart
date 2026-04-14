// user_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobify/users.dart';
import 'package:jobify/data/local_db.dart';

class UserRepository {
  final SupabaseClient _sb = Supabase.instance.client;

  String? get _uid => _sb.auth.currentUser?.id;

  // User data - read with caching

  /// Get current user with cache-first strategy
  Future<Users?> getCurrentUser({bool forceRefresh = false}) async {
    final userId = _uid;
    if (userId == null) return null;

    // Try cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = await LocalDB.getCachedUser(userId);
      if (cached != null) {
        debugPrint(' Using cached user data for: $userId');
        return cached;
      }
    }

    // Fetch from Supabase
    try {
      debugPrint(' Fetching user data from Supabase for: $userId');
      final data = await _sb
          .from('users')
          .select('user_id, role, profile_image_url, created_at, updated_at, email, fullname, phone')
          .eq('user_id', userId)
          .single();

      final user = Users.fromJson(data);

      // Cache for next time
      await LocalDB.cacheUser(user);
      debugPrint(' Cached user data for: $userId');

      return user;
    } catch (e) {
      debugPrint(' Error fetching user: $e');
      // Last resort - try expired cache
      return await LocalDB.getCachedUser(userId);
    }
  }

  /// Get complete profile (with all related data)
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
        profile.resumes = await LocalDB.getCachedResumes(userId);

        // If we have cached user, return immediately but refresh in background
        if (profile.user != null) {
          _refreshProfileInBackground(userId, profile);
          return profile;
        }
      }
    }

    // Fetch fresh from Supabase
    return await _fetchFreshProfile(userId);
  }

  Future<CompleteUserProfile> _fetchFreshProfile(String userId) async {
    final profile = CompleteUserProfile(userId: userId);

    // Fetch user
    final userData = await _sb
        .from('users')
        .select()
        .eq('user_id', userId)
        .single();
    profile.user = Users.fromJson(userData);
    await LocalDB.cacheUser(profile.user!);

    // Fetch role-specific profile
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

    // Fetch related data
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

    final resumesData = await _sb
        .from('resume')
        .select()
        .eq('user_id', userId);
    profile.resumes = List<Map<String, dynamic>>.from(resumesData);
    await LocalDB.cacheResumes(userId, profile.resumes);

    return profile;
  }

  Future<void> _refreshProfileInBackground(String userId, CompleteUserProfile currentProfile) async {
    try {
      final freshProfile = await _fetchFreshProfile(userId);
      currentProfile.updateFrom(freshProfile);
    } catch (e) {
      debugPrint('Background refresh failed: $e');
    }
  }

  // User data - write with cache invalidation

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    // Update Supabase
    await _sb
        .from('users')
        .update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('user_id', userId);

    // Invalidate cache
    await LocalDB.clearUserCache(userId);
  }

  Future<void> updateJobSeekerProfile(String userId, Map<String, dynamic> updates) async {
    final existing = await _sb
        .from('job_seeker_profile')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

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

  Future<void> addResume(String userId, String fileUrl, String fileName) async {
    await _sb.from('resume').insert({
      'user_id': userId,
      'file_url': fileUrl,
      'file_name': fileName,
      'uploaded_at': DateTime.now().toIso8601String(),
      'is_default': false,
    });
    await LocalDB.clearUserCache(userId);
  }

  Future<void> deleteResume(String resumeId) async {
    final userId = _uid;
    if (userId == null) return;
    await _sb.from('resume').delete().eq('resume_id', resumeId);
    await LocalDB.clearUserCache(userId);
  }

  Future<void> cacheFullProfileAfterLogin(String userId) async {
    try {
      debugPrint('Caching full profile for user: $userId');

      // Fetch complete profile and cache it
      await _fetchFreshProfile(userId);
      debugPrint('Full profile cached successfully');
    } catch (e) {
      debugPrint('Error caching full profile: $e');
    }
  }

}

// Helper class for complete profile
class CompleteUserProfile {
  final String userId;
  Users? user;
  Map<String, dynamic>? jobSeekerProfile;
  Map<String, dynamic>? companyProfile;
  List<Map<String, dynamic>> skills = [];
  List<Map<String, dynamic>> education = [];
  List<Map<String, dynamic>> experience = [];
  List<Map<String, dynamic>> resumes = [];

  CompleteUserProfile({required this.userId});

  void updateFrom(CompleteUserProfile other) {
    user = other.user;
    jobSeekerProfile = other.jobSeekerProfile;
    companyProfile = other.companyProfile;
    skills = other.skills;
    education = other.education;
    experience = other.experience;
    resumes = other.resumes;
  }

  bool get isLoading => user == null;
}