// ═══════════════════════════════════════════════════════════════════════════
// local_db.dart  –  SQLite local cache (sqflite ^2.3.2 + path ^1.9.0)
// Stores: posts (feed cache), job_posts (discovery/employer cache),
// saved_posts, saved_jobs, reference tables, user profiles, company branches.
// Comments & likes are REMOTE ONLY – not stored locally.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:jobify/social/post_feed_setting.dart';
import '../users/users.dart';

// SQLite cache layer
class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dbPath = join(await getDatabasesPath(), 'jobify_v4.db');
    return openDatabase(
      dbPath,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // 1. Posts cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS posts (
        post_id         TEXT PRIMARY KEY,
        user_id         TEXT NOT NULL,
        company_id      TEXT,
        job_id          TEXT,
        content         TEXT NOT NULL DEFAULT '',
        post_type       TEXT NOT NULL DEFAULT 'post',
        hashtags        TEXT NOT NULL DEFAULT '[]',
        media_urls      TEXT NOT NULL DEFAULT '[]',
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL,
        author_name     TEXT NOT NULL DEFAULT '',
        author_avatar   TEXT NOT NULL DEFAULT '',
        author_subtitle TEXT NOT NULL DEFAULT '',
        is_verified     INTEGER NOT NULL DEFAULT 0,
        like_count      INTEGER NOT NULL DEFAULT 0,
        comment_count   INTEGER NOT NULL DEFAULT 0,
        is_liked        INTEGER NOT NULL DEFAULT 0,
        is_saved        INTEGER NOT NULL DEFAULT 0,
        is_following    INTEGER NOT NULL DEFAULT 0,
        synced_at       TEXT NOT NULL DEFAULT ''
      )
    ''');

    // 2. Saved posts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_posts (
        post_id    TEXT PRIMARY KEY,
        user_id    TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 3. Job posts cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS job_posts (
        job_id               TEXT PRIMARY KEY,
        company_id           TEXT NOT NULL,
        created_by           TEXT NOT NULL,
        job_title            TEXT NOT NULL,
        description          TEXT NOT NULL,
        location             TEXT NOT NULL,
        remote_option        INTEGER NOT NULL DEFAULT 0,
        salary_min           REAL,
        salary_max           REAL,
        job_type             TEXT NOT NULL DEFAULT '',
        job_category         TEXT NOT NULL DEFAULT '',
        experience_level     TEXT NOT NULL DEFAULT '',
        vacancy_count        INTEGER NOT NULL DEFAULT 1,
        application_deadline TEXT,
        status               TEXT NOT NULL DEFAULT 'active',
        view_count           INTEGER NOT NULL DEFAULT 0,
        application_count    INTEGER NOT NULL DEFAULT 0,
        created_at           TEXT NOT NULL,
        image_urls           TEXT NOT NULL DEFAULT '[]',
        video_url            TEXT,
        company_name         TEXT NOT NULL DEFAULT '',
        company_logo_url     TEXT,
        company_industry     TEXT,
        is_saved             INTEGER NOT NULL DEFAULT 0,
        synced_at            TEXT NOT NULL DEFAULT ''
      )
    ''');

    // 4. Saved jobs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_jobs (
        job_id     TEXT PRIMARY KEY,
        user_id    TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 5. Reference tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reference_table (
        table_name TEXT PRIMARY KEY,
        data_json  TEXT NOT NULL,
        cached_at  TEXT NOT NULL
      )
    ''');

    // 6. Users
    await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      user_id           TEXT PRIMARY KEY,
      role              TEXT NOT NULL,
      fullname          TEXT NOT NULL DEFAULT '',
      phone             TEXT,
      profile_image_url TEXT,
      email             TEXT NOT NULL,
      created_at        TEXT NOT NULL,
      updated_at        TEXT NOT NULL,
      cached_at         TEXT NOT NULL
    )
  ''');

    // 8. Cached job seeker profiles
    await db.execute('''
    CREATE TABLE IF NOT EXISTS job_seeker_profiles (
      user_id         TEXT PRIMARY KEY,
      date_of_birth   TEXT,
      gender          TEXT,
      address         TEXT,
      bio             TEXT,
      cached_at       TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
    )
  ''');

    // 9. Cached company profiles
    await db.execute('''
    CREATE TABLE IF NOT EXISTS company_profiles (
      user_id              TEXT PRIMARY KEY,
      company_name         TEXT NOT NULL DEFAULT '',
      company_description  TEXT,
      industry             TEXT,
      company_size         TEXT,
      location             TEXT,
      logo_url             TEXT,
      cached_at            TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
    )
  ''');

    // 10. Cached skills
    await db.execute('''
    CREATE TABLE IF NOT EXISTS skills (
      skill_id      TEXT PRIMARY KEY,
      user_id       TEXT NOT NULL,
      skill_name    TEXT NOT NULL,
      skill_level   TEXT,
      cached_at     TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
    )
  ''');

    // 11. Cached education
    await db.execute('''
    CREATE TABLE IF NOT EXISTS education (
      education_id      TEXT PRIMARY KEY,
      user_id           TEXT NOT NULL,
      institution_name  TEXT NOT NULL,
      qualification     TEXT NOT NULL,
      field_of_study    TEXT,
      start_date        TEXT,
      end_date          TEXT,
      description       TEXT,
      cached_at         TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
    )
  ''');

    // 12. Cached experience
    await db.execute('''
    CREATE TABLE IF NOT EXISTS experience (
      experience_id  TEXT PRIMARY KEY,
      user_id        TEXT NOT NULL,
      company_name   TEXT NOT NULL,
      job_title      TEXT NOT NULL,
      start_date     TEXT NOT NULL,
      end_date       TEXT,
      description    TEXT,
      cached_at      TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
    )
  ''');

    // 13. Cached resumes
    await db.execute('''
    CREATE TABLE IF NOT EXISTS resumes (
      resume_id     TEXT PRIMARY KEY,
      user_id       TEXT NOT NULL,
      file_url      TEXT NOT NULL,
      file_name     TEXT NOT NULL,
      uploaded_at   TEXT NOT NULL,
      is_default    INTEGER NOT NULL DEFAULT 0,
      cached_at     TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
    )
  ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS company_branches (
      branch_id     TEXT PRIMARY KEY,
      company_id    TEXT NOT NULL,
      branch_name   TEXT NOT NULL,
      address       TEXT NOT NULL,
      city          TEXT NOT NULL,
      state         TEXT NOT NULL,
      postal_code   TEXT,
      country       TEXT NOT NULL DEFAULT 'Malaysia',
      phone         TEXT,
      email         TEXT,
      is_head_office INTEGER NOT NULL DEFAULT 0,
      created_at    TEXT NOT NULL,
      updated_at    TEXT NOT NULL,
      cached_at     TEXT NOT NULL,
      FOREIGN KEY (company_id) REFERENCES company_profiles (company_id) ON DELETE CASCADE
    )
  ''');
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    for (final t in ['posts','comments','liked_posts','saved_posts','job_posts','saved_jobs',
      'users','job_seeker_profiles','company_profiles',
      'skills','education','experience','resumes']) {
      await db.execute('DROP TABLE IF EXISTS $t');
    }
    await _onCreate(db, newV);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POSTS (feed cache)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> insertPosts(List<FeedPost> posts) async {
    if (posts.isEmpty) return;
    final d = await db;
    final batch = d.batch();
    final now = DateTime.now().toIso8601String();
    for (final p in posts) {
      final map = Map<String, dynamic>.from(p.toLocalDbMap());
      map['synced_at'] = now;
      batch.insert('posts', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> insertPost(FeedPost p) async {
    final d = await db;
    final map = Map<String, dynamic>.from(p.toLocalDbMap());
    map['synced_at'] = DateTime.now().toIso8601String();
    await d.insert('posts', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<FeedPost>> getCachedPosts({
    String? postType,
    int limit = 30,
    int offset = 0,
  }) async {
    final d = await db;
    final filtered = postType != null && postType != 'All';
    final rows = await d.query(
      'posts',
      where: filtered ? 'post_type = ?' : null,
      whereArgs: filtered ? [postType] : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(FeedPost.fromLocalDb).toList();
  }

  static Future<void> deletePost(String postId) async {
    final d = await db;
    await d.delete('posts', where: 'post_id = ?', whereArgs: [postId]);
    await d.delete('saved_posts', where: 'post_id = ?', whereArgs: [postId]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVED POSTS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> setPostSaved(String postId, bool saved, String userId) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE posts SET is_saved = ? WHERE post_id = ?',
      [saved ? 1 : 0, postId],
    );
    if (saved) {
      await d.insert('saved_posts', {
        'post_id': postId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await d.delete('saved_posts', where: 'post_id = ?', whereArgs: [postId]);
    }
  }

  static Future<Set<String>> getSavedPostIds(String userId) async {
    final d = await db;
    final rows = await d.query('saved_posts',
        columns: ['post_id'], where: 'user_id = ?', whereArgs: [userId]);
    return rows.map((r) => r['post_id'] as String).toSet();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JOB POSTS (discovery + employer cache)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> insertJobs(List<JobPost> jobs) async {
    if (jobs.isEmpty) return;
    final d = await db;
    final batch = d.batch();
    final now = DateTime.now().toIso8601String();
    for (final j in jobs) {
      final map = Map<String, dynamic>.from(j.toLocalDbMap());
      map['synced_at'] = now;
      batch.insert('job_posts', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Insert a list of flat job maps directly into the cache (full replace for the user)
  static Future<void> insertJobMaps(List<Map<String, dynamic>> jobs) async {
    if (jobs.isEmpty) return;
    final dbInstance = await LocalDB.db;
    final batch = dbInstance.batch();
    final now = DateTime.now().toIso8601String();

    for (final job in jobs) {
      batch.insert(
        'job_posts',
        {
          'job_id': job['job_id'],
          'company_id': job['company_id'],
          'created_by': job['created_by'],
          'job_title': job['job_title'],
          'description': job['description'],
          'location': job['location'],
          'remote_option': job['remote_option'] == true ? 1 : 0,
          'salary_min': job['salary_min'],
          'salary_max': job['salary_max'],
          'job_type': job['job_type'] ?? '',
          'job_category': job['job_category'] ?? '',
          'experience_level': job['experience_level'] ?? '',
          'vacancy_count': job['vacancy_count'] ?? 1,
          'application_deadline': job['application_deadline'],
          'status': job['status'] ?? 'active',
          'view_count': job['view_count'] ?? 0,
          'application_count': job['application_count'] ?? 0,
          'created_at': job['created_at'],
          'image_urls': (job['image_urls'] as List?)?.join(',') ?? '',
          'video_url': job['video_url'],
          'company_name': job['company_name'] ?? '',
          'company_logo_url': job['company_logo_url'],
          'company_industry': job['company_industry'],
          'is_saved': job['is_saved'] == true ? 1 : 0,
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<JobPost>> getCachedJobs({
    String? jobType,
    String? experienceLevel,
    double? salaryMin,
    String? keyword,
    bool remoteOnly = false,
    int limit = 30,
    int offset = 0,
  }) async {
    final d = await db;
    final conditions = <String>["status = 'active'"];
    final args = <dynamic>[];

    if (jobType != null && jobType != 'All') {
      conditions.add('job_type = ?');
      args.add(jobType);
    }
    if (experienceLevel != null && experienceLevel != 'All') {
      conditions.add('experience_level = ?');
      args.add(experienceLevel);
    }
    if (salaryMin != null) {
      conditions.add('(salary_max IS NOT NULL AND salary_max >= ?)');
      args.add(salaryMin);
    }
    if (remoteOnly) {
      conditions.add('remote_option = 1');
    }
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('(job_title LIKE ? OR company_name LIKE ?)');
      args.addAll(['%$keyword%', '%$keyword%']);
    }

    final rows = await d.rawQuery(
      'SELECT * FROM job_posts WHERE ${conditions.join(' AND ')} ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    return rows.map(JobPost.fromLocalDb).toList();
  }

  static Future<List<JobPost>> getCachedJobsByUser(String userId) async {
    final d = await db;
    final rows = await d.query(
      'job_posts',
      where: 'created_by = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(JobPost.fromLocalDb).toList();
  }

  /// Get a single cached job as a Map (no JobPost model needed)
  static Future<Map<String, dynamic>?> getCachedJobMapById(String jobId) async {
    final d = await db;
    final rows = await d.query(
      'job_posts',
      where: 'job_id = ?',
      whereArgs: [jobId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return {
      'job_id': row['job_id'],
      'company_id': row['company_id'],
      'created_by': row['created_by'],
      'job_title': row['job_title'],
      'description': row['description'],
      'location': row['location'],
      'remote_option': row['remote_option'] == 1,
      'salary_min': row['salary_min'],
      'salary_max': row['salary_max'],
      'job_type': row['job_type'],
      'job_category': row['job_category'],
      'experience_level': row['experience_level'],
      'vacancy_count': row['vacancy_count'],
      'application_deadline': row['application_deadline'],
      'status': row['status'],
      'view_count': row['view_count'],
      'application_count': row['application_count'],
      'created_at': row['created_at'],
      'image_urls': (row['image_urls'] as String?)?.split(',') ?? [],
      'video_url': row['video_url'],
      'company_name': row['company_name'],
      'company_logo_url': row['company_logo_url'],
      'company_industry': row['company_industry'],
      'is_saved': row['is_saved'] == 1,
    };
  }

  /// Get cached job posts for a specific user as Maps (no JobPost model)
  static Future<List<Map<String, dynamic>>> getCachedJobMapsByUser(String userId) async {
    final d = await db;
    final rows = await d.query(
      'job_posts',
      where: 'created_by = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) {
      return {
        'job_id': row['job_id'],
        'company_id': row['company_id'],
        'created_by': row['created_by'],
        'job_title': row['job_title'],
        'description': row['description'],
        'location': row['location'],
        'remote_option': row['remote_option'] == 1,
        'salary_min': row['salary_min'],
        'salary_max': row['salary_max'],
        'job_type': row['job_type'],
        'job_category': row['job_category'],
        'experience_level': row['experience_level'],
        'vacancy_count': row['vacancy_count'],
        'application_deadline': row['application_deadline'],
        'status': row['status'],
        'view_count': row['view_count'],
        'application_count': row['application_count'],
        'created_at': row['created_at'],
        'image_urls': (row['image_urls'] as String?)?.split(',') ?? [],
        'video_url': row['video_url'],
        'company_name': row['company_name'],
        'company_logo_url': row['company_logo_url'],
        'company_industry': row['company_industry'],
        'is_saved': row['is_saved'] == 1,
      };
    }).toList();
  }

  static Future<void> deleteJobPost(String jobId) async {
    final d = await db;
    await d.delete('job_posts', where: 'job_id = ?', whereArgs: [jobId]);
    await d.delete('saved_jobs', where: 'job_id = ?', whereArgs: [jobId]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVED JOBS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> setJobSaved(String jobId, bool saved, String userId) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE job_posts SET is_saved = ? WHERE job_id = ?',
      [saved ? 1 : 0, jobId],
    );
    if (saved) {
      await d.insert('saved_jobs', {
        'job_id': jobId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await d.delete('saved_jobs', where: 'job_id = ?', whereArgs: [jobId]);
    }
  }

  static Future<List<String>> getSavedJobIds(String userId) async {
    final d = await db;
    final rows = await d.query('saved_jobs',
        columns: ['job_id'], where: 'user_id = ?', whereArgs: [userId]);
    return rows.map((r) => r['job_id'] as String).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JOB APPLICATIONS CACHE
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> cacheJobApplications(
      List<Map<String, dynamic>> applications, String userId) async {
    final db = await LocalDB.db;
    await db.delete('cached_job_applications', where: 'user_id = ?', whereArgs: [userId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final app in applications) {
      batch.insert('cached_job_applications', {
        'application_id': app['application_id'] as String,
        'user_id': userId,
        'job_id': app['job_id'] as String,
        'job_title': app['job_title'] ?? '',
        'company_name': app['company_name'] ?? '',
        'company_logo': app['company_logo'],
        'location': app['location'] ?? '',
        'salary_min': app['salary_min'],
        'salary_max': app['salary_max'],
        'job_type': app['job_type'] ?? '',
        'description': app['description'] ?? '',
        'resume_url': app['resume_url'] ?? '',
        'status': app['status'] ?? 'pending',
        'applied_at': app['applied_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': app['updated_at'] ?? DateTime.now().toIso8601String(),
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> cacheJobApplication(Map<String, dynamic> application, String userId) async {
    final db = await LocalDB.db;
    await db.insert('cached_job_applications', {
      'application_id': application['application_id'] as String,
      'user_id': userId,
      'job_id': application['job_id'] as String,
      'job_title': application['job_title'] ?? '',
      'company_name': application['company_name'] ?? '',
      'company_logo': application['company_logo'],
      'location': application['location'] ?? '',
      'salary_min': application['salary_min'],
      'salary_max': application['salary_max'],
      'job_type': application['job_type'] ?? '',
      'description': application['description'] ?? '',
      'resume_url': application['resume_url'] ?? '',
      'status': application['status'] ?? 'pending',
      'applied_at': application['applied_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': application['updated_at'] ?? DateTime.now().toIso8601String(),
      'cached_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getCachedJobApplications(
      String userId) async {
    final db = await LocalDB.db;
    final result = await db.query(
      'cached_job_applications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'applied_at DESC',
    );
    return result;
  }

  static Future<void> updateCachedApplicationStatus(
      String applicationId, String newStatus) async {
    final db = await LocalDB.db;
    await db.update(
      'cached_job_applications',
      {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'application_id = ?',
      whereArgs: [applicationId],
    );
  }

  static Future<void> deleteCachedJobApplication(
      String applicationId, String userId) async {
    final db = await LocalDB.db;
    await db.delete(
      'cached_job_applications',
      where: 'application_id = ? AND user_id = ?',
      whereArgs: [applicationId, userId],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REFERENCE TABLES
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> cacheReferenceTable(String tableName, List<Map<String, dynamic>> data) async {
    final d = await db;
    final json = jsonEncode(data);
    await d.insert(
      'reference_table',
      {
        'table_name': tableName,
        'data_json': json,
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getCachedReferenceTable(String tableName) async {
    final d = await db;
    final rows = await d.query(
      'reference_table',
      where: 'table_name = ?',
      whereArgs: [tableName],
    );
    if (rows.isEmpty) return [];
    final jsonStr = rows.first['data_json'] as String;
    return List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER PROFILES
  // ══════════════════════════════════════════════════════════════════════════
  // cache invalidation trigger when user update profile (clearUserCache / logout / TTL expire(5 minutes))
  static const int _userCacheTTLMinutes = 5; // Cache valid for 5 minutes

  static Future<void> cacheUser(Users user) async {
    final db = await LocalDB.db;
    await db.insert('users', {
      'user_id': user.userId,
      'role': user.role,
      'fullname': user.fullname,
      'phone': user.phone,
      'profile_image_url': user.profileImageUrl,
      'email': user.email,
      'created_at': user.createdAt.toIso8601String(),
      'updated_at': user.updatedAt.toIso8601String(),
      'cached_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Users?> getCachedUser(String userId) async {
    final db = await LocalDB.db;
    final result = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    final row = result.first;
    final cachedAt = DateTime.parse(row['cached_at'] as String);
    if (DateTime.now().difference(cachedAt).inMinutes > _userCacheTTLMinutes) {
      return null;
    }
    return Users(
      userId: row['user_id'] as String,
      role: row['role'] as String,
      fullname: row['fullname'] as String,
      phone: row['phone'] as String?,
      profileImageUrl: row['profile_image_url'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      email: row['email'] as String,
    );
  }

  static Future<void> cacheJobSeekerProfile(String userId, Map<String, dynamic> profile) async {
    final db = await LocalDB.db;
    await db.insert('job_seeker_profiles', {
      'user_id': userId,
      'date_of_birth': profile['date_of_birth'],
      'gender': profile['gender'],
      'address': profile['address'],
      'bio': profile['bio'],
      'cached_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getCachedJobSeekerProfile(String userId) async {
    final db = await LocalDB.db;
    final result = await db.query(
      'job_seeker_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  static Future<void> cacheCompanyProfile(String userId, Map<String, dynamic> profile) async {
    final db = await LocalDB.db;
    await db.insert('company_profiles', {
      'user_id': userId,
      'company_name': profile['company_name'] ?? '',
      'company_description': profile['company_description'],
      'industry': profile['industry'],
      'company_size': profile['company_size'],
      'location': profile['location'],
      'logo_url': profile['logo_url'],
      'cached_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getCachedCompanyProfile(String userId) async {
    final db = await LocalDB.db;
    final result = await db.query(
      'company_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  static Future<void> cacheSkills(String userId, List<Map<String, dynamic>> skills) async {
    final db = await LocalDB.db;
    // Delete old skills for this user first
    await db.delete('skills', where: 'user_id = ?', whereArgs: [userId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final skill in skills) {
      batch.insert('skills', {
        'skill_id': skill['skill_id'] as String,
        'user_id': userId,
        'skill_name': skill['skill_name'] as String,
        'skill_level': skill['skill_level'],
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedSkills(String userId) async {
    final db = await LocalDB.db;
    final result = await db.query(
      'skills',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return result;
  }

  static Future<void> cacheEducation(String userId, List<Map<String, dynamic>> education) async {
    final db = await LocalDB.db;
    await db.delete('education', where: 'user_id = ?', whereArgs: [userId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final edu in education) {
      batch.insert('education', {
        'education_id': edu['education_id'] as String,
        'user_id': userId,
        'institution_name': edu['institution_name'] as String,
        'qualification': edu['qualification'] as String,
        'field_of_study': edu['field_of_study'],
        'start_date': edu['start_date']?.toString(),
        'end_date': edu['end_date']?.toString(),
        'description': edu['description'],
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedEducation(String userId) async {
    final db = await LocalDB.db;
    final result = await db.query(
      'education',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_date DESC',
    );
    return result;
  }

  static Future<void> cacheExperience(String userId, List<Map<String, dynamic>> experience) async {
    final db = await LocalDB.db;
    await db.delete('experience', where: 'user_id = ?', whereArgs: [userId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final exp in experience) {
      batch.insert('experience', {
        'experience_id': exp['experience_id'] as String,
        'user_id': userId,
        'company_name': exp['company_name'] as String,
        'job_title': exp['job_title'] as String,
        'start_date': exp['start_date']?.toString(),
        'end_date': exp['end_date']?.toString(),
        'description': exp['description'],
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedExperience(String userId) async {
    final db = await LocalDB.db;
    final result = await db.query(
      'experience',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_date DESC',
    );
    return result;
  }

  static Future<void> cacheResumes(String userId, List<Map<String, dynamic>> resumes) async {
    final db = await LocalDB.db;
    await db.delete('resumes', where: 'user_id = ?', whereArgs: [userId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final resume in resumes) {
      batch.insert('resumes', {
        'resume_id': resume['resume_id'] as String,
        'user_id': userId,
        'file_url': resume['file_url'] as String,
        'file_name': resume['file_name'] as String,
        'uploaded_at': resume['uploaded_at']?.toString() ?? DateTime.now().toIso8601String(),
        'is_default': (resume['is_default'] == true) ? 1 : 0,
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedResumes(String userId) async {
    final db = await LocalDB.db;
    final result = await db.query(
      'resumes',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return result;
  }

  static Future<void> cacheBranches(String companyId, List<Map<String, dynamic>> branches) async {
    final db = await LocalDB.db;
    await db.delete('company_branches', where: 'company_id = ?', whereArgs: [companyId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final branch in branches) {
      batch.insert('company_branches', {
        'branch_id': branch['branch_id'] as String,
        'company_id': companyId,
        'branch_name': branch['branch_name'] as String,
        'address': branch['address'] as String,
        'city': branch['city'] as String,
        'state': branch['state'] as String,
        'postal_code': branch['postal_code'],
        'country': branch['country'] ?? 'Malaysia',
        'phone': branch['phone'],
        'email': branch['email'],
        'is_head_office': (branch['is_head_office'] == true) ? 1 : 0,
        'created_at': branch['created_at']?.toString() ?? now,
        'updated_at': branch['updated_at']?.toString() ?? now,
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedBranches(String companyId) async {
    final db = await LocalDB.db;
    final result = await db.query(
      'company_branches',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'is_head_office DESC, branch_name ASC',
    );
    return result;
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  static Future<void> clearAllCaches() async {
    final d = await db;
    for (final t in ['posts','saved_posts','job_posts','saved_jobs','reference_table',
      'users','job_seeker_profiles','company_profiles','skills',
      'education','experience','resumes','company_branches']) {
      await d.delete(t);
    }
  }

  static Future<void> clearUserCache(String userId) async {
    final db = await LocalDB.db;
    await db.delete('users', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('job_seeker_profiles', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('company_profiles', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('skills', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('education', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('experience', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('resumes', where: 'user_id = ?', whereArgs: [userId]);
  }
}