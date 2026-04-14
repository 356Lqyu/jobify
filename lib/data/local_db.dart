// ═══════════════════════════════════════════════════════════════════════════
// local_db.dart  –  SQLite local cache  (sqflite ^2.3.2 + path ^1.9.0)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:jobify/social/post_feed_setting.dart';

import '../users.dart';

class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<Database> _init() async {
    final dbPath = join(await getDatabasesPath(), 'jobify_v7.db');
    return openDatabase(
      dbPath,
      version: 7,
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

    // 2. Comments cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comments (
        comment_id    TEXT PRIMARY KEY,
        post_id       TEXT NOT NULL,
        user_id       TEXT NOT NULL,
        comment_text  TEXT NOT NULL,
        created_at    TEXT NOT NULL,
        author_name   TEXT NOT NULL DEFAULT '',
        author_avatar TEXT NOT NULL DEFAULT ''
      )
    ''');

    // 3. Liked posts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS liked_posts (
        post_id    TEXT PRIMARY KEY,
        user_id    TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Saved posts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_posts (
        post_id    TEXT PRIMARY KEY,
        user_id    TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 5. Job posts cache
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

    // 6. Saved jobs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_jobs (
        job_id     TEXT PRIMARY KEY,
        user_id    TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 7. Cached users
    await db.execute('''
    CREATE TABLE IF NOT EXISTS cached_users (
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
    CREATE TABLE IF NOT EXISTS cached_job_seeker_profiles (
      user_id         TEXT PRIMARY KEY,
      date_of_birth   TEXT,
      gender          TEXT,
      address         TEXT,
      bio             TEXT,
      cached_at       TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES cached_users (user_id) ON DELETE CASCADE
    )
  ''');

    // 9. Cached company profiles
    await db.execute('''
    CREATE TABLE IF NOT EXISTS cached_company_profiles (
      user_id              TEXT PRIMARY KEY,
      company_name         TEXT NOT NULL DEFAULT '',
      company_description  TEXT,
      industry             TEXT,
      company_size         TEXT,
      location             TEXT,
      logo_url             TEXT,
      cached_at            TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES cached_users (user_id) ON DELETE CASCADE
    )
  ''');

    // 10. Cached skills
    await db.execute('''
    CREATE TABLE IF NOT EXISTS cached_skills (
      skill_id      TEXT PRIMARY KEY,
      user_id       TEXT NOT NULL,
      skill_name    TEXT NOT NULL,
      skill_level   TEXT,
      cached_at     TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES cached_users (user_id) ON DELETE CASCADE
    )
  ''');

    // 11. Cached education
    await db.execute('''
    CREATE TABLE IF NOT EXISTS cached_education (
      education_id      TEXT PRIMARY KEY,
      user_id           TEXT NOT NULL,
      institution_name  TEXT NOT NULL,
      qualification     TEXT NOT NULL,
      field_of_study    TEXT,
      start_date        TEXT,
      end_date          TEXT,
      description       TEXT,
      cached_at         TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES cached_users (user_id) ON DELETE CASCADE
    )
  ''');

    // 12. Cached experience
    await db.execute('''
    CREATE TABLE IF NOT EXISTS cached_experience (
      experience_id  TEXT PRIMARY KEY,
      user_id        TEXT NOT NULL,
      company_name   TEXT NOT NULL,
      job_title      TEXT NOT NULL,
      start_date     TEXT NOT NULL,
      end_date       TEXT,
      description    TEXT,
      cached_at      TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES cached_users (user_id) ON DELETE CASCADE
    )
  ''');

    // 13. Cached resumes
    await db.execute('''
    CREATE TABLE IF NOT EXISTS cached_resumes (
      resume_id     TEXT PRIMARY KEY,
      user_id       TEXT NOT NULL,
      file_url      TEXT NOT NULL,
      file_name     TEXT NOT NULL,
      uploaded_at   TEXT NOT NULL,
      is_default    INTEGER NOT NULL DEFAULT 0,
      cached_at     TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES cached_users (user_id) ON DELETE CASCADE
    )
  ''');
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    for (final t in ['posts','comments','liked_posts','saved_posts','job_posts','saved_jobs',
      'cached_users','cached_job_seeker_profiles','cached_company_profiles',
      'cached_skills','cached_education','cached_experience','cached_resumes']) {
      await db.execute('DROP TABLE IF EXISTS $t');
    }
    await _onCreate(db, newV);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POSTS
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
      where:     filtered ? 'post_type = ?' : null,
      whereArgs: filtered ? [postType]      : null,
      orderBy:   'created_at DESC',
      limit:     limit,
      offset:    offset,
    );
    return rows.map(FeedPost.fromLocalDb).toList();
  }

  static Future<void> deletePost(String postId) async {
    final d = await db;
    await d.delete('posts', where: 'post_id = ?', whereArgs: [postId]);
  }

  static Future<void> setPostLiked(String postId, bool liked, String userId) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE posts SET is_liked = ?, like_count = MAX(0, like_count + ?) WHERE post_id = ?',
      [liked ? 1 : 0, liked ? 1 : -1, postId],
    );
    if (liked) {
      await d.insert('liked_posts', {
        'post_id':    postId,
        'user_id':    userId,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await d.delete('liked_posts', where: 'post_id = ?', whereArgs: [postId]);
    }
  }

  static Future<Set<String>> getLikedPostIds(String userId) async {
    final d = await db;
    final rows = await d.query('liked_posts',
        columns: ['post_id'], where: 'user_id = ?', whereArgs: [userId]);
    return rows.map((r) => r['post_id'] as String).toSet();
  }

  static Future<void> setPostSaved(String postId, bool saved, String userId) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE posts SET is_saved = ? WHERE post_id = ?',
      [saved ? 1 : 0, postId],
    );
    if (saved) {
      await d.insert('saved_posts', {
        'post_id':    postId,
        'user_id':    userId,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await d.delete('saved_posts', where: 'post_id = ?', whereArgs: [postId]);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMMENTS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> insertComment(PostComment c) async {
    final d = await db;
    await d.insert('comments', {
      'comment_id':   c.commentId,
      'post_id':      c.postId,
      'user_id':      c.userId,
      'comment_text': c.commentText,
      'created_at':   c.createdAt.toIso8601String(),
      'author_name':  c.authorName,
      'author_avatar':c.authorAvatar,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<PostComment>> getCachedComments(String postId) async {
    final d = await db;
    final rows = await d.query('comments',
        where: 'post_id = ?', whereArgs: [postId], orderBy: 'created_at DESC');
    return rows.map((r) => PostComment(
      commentId:    r['comment_id'] as String,
      postId:       r['post_id'] as String,
      userId:       r['user_id'] as String,
      commentText:  r['comment_text'] as String,
      createdAt:    DateTime.parse(r['created_at'] as String),
      authorName:   r['author_name'] as String? ?? '',
      authorAvatar: r['author_avatar'] as String? ?? '',
    )).toList();
  }

  static Future<void> deleteComment(String commentId) async {
    final d = await db;
    await d.delete('comments', where: 'comment_id = ?', whereArgs: [commentId]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JOBS
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

  static Future<void> setJobSaved(String jobId, bool saved, String userId) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE job_posts SET is_saved = ? WHERE job_id = ?',
      [saved ? 1 : 0, jobId],
    );
    if (saved) {
      await d.insert('saved_jobs', {
        'job_id':     jobId,
        'user_id':    userId,
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
  // Users
  // ══════════════════════════════════════════════════════════════════════════
  static const int _userCacheTTLMinutes = 5; // Cache valid for 5 minutes

  static Future<void> cacheUser(Users user) async {
    final db = await LocalDB.db;
    await db.insert('cached_users', {
      'user_id': user.userId,
      'role': user.role,
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
      'cached_users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final cachedAt = DateTime.parse(row['cached_at'] as String);

    // Check if cache is still valid (5 minutes TTL)
    if (DateTime.now().difference(cachedAt).inMinutes > _userCacheTTLMinutes) {
      return null; // Cache expired
    }

    return Users(
      userId: row['user_id'] as String,
      role: row['role'] as String,
      fullname: '',
      phone: row['phone'] as String?,
      profileImageUrl: row['profile_image_url'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      email: row['email'] as String,
    );
  }

  static Future<void> cacheJobSeekerProfile(String userId, Map<String, dynamic> profile) async {
    final db = await LocalDB.db;
    await db.insert('cached_job_seeker_profiles', {
      'user_id': userId,
      'fullname': profile['fullname'] ?? '',
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
      'cached_job_seeker_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  static Future<void> cacheCompanyProfile(String userId, Map<String, dynamic> profile) async {
    final db = await LocalDB.db;
    await db.insert('cached_company_profiles', {
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
      'cached_company_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  static Future<void> cacheSkills(String userId, List<Map<String, dynamic>> skills) async {
    final db = await LocalDB.db;
    // Delete old skills for this user first
    await db.delete('cached_skills', where: 'user_id = ?', whereArgs: [userId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final skill in skills) {
      batch.insert('cached_skills', {
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
      'cached_skills',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return result;
  }

  static Future<void> cacheEducation(String userId, List<Map<String, dynamic>> education) async {
    final db = await LocalDB.db;
    await db.delete('cached_education', where: 'user_id = ?', whereArgs: [userId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final edu in education) {
      batch.insert('cached_education', {
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
      'cached_education',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_date DESC',
    );
    return result;
  }

  static Future<void> cacheExperience(String userId, List<Map<String, dynamic>> experience) async {
    final db = await LocalDB.db;
    await db.delete('cached_experience', where: 'user_id = ?', whereArgs: [userId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final exp in experience) {
      batch.insert('cached_experience', {
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
      'cached_experience',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_date DESC',
    );
    return result;
  }

  static Future<void> cacheResumes(String userId, List<Map<String, dynamic>> resumes) async {
    final db = await LocalDB.db;
    await db.delete('cached_resumes', where: 'user_id = ?', whereArgs: [userId]);

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final resume in resumes) {
      batch.insert('cached_resumes', {
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
      'cached_resumes',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return result;
  }

  static Future<void> clearUserCache(String userId) async {
    final db = await LocalDB.db;
    await db.delete('cached_users', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_job_seeker_profiles', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_company_profiles', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_skills', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_education', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_experience', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_resumes', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  static Future<void> clearAllCaches() async {
    final d = await db;
    for (final t in ['posts','comments','liked_posts','saved_posts','job_posts','saved_jobs']) {
      await d.delete(t);
    }
  }
}