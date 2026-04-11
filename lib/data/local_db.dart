// ═══════════════════════════════════════════════════════════════════════════
// local_db.dart  –  SQLite local cache  (sqflite ^2.3.2 + path ^1.9.0)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:jobify/social/post_feed_setting.dart';

class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<Database> _init() async {
    final dbPath = join(await getDatabasesPath(), 'jobify_v2.db');
    return openDatabase(
      dbPath,
      version: 2,
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
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    for (final t in ['posts','comments','liked_posts','saved_posts','job_posts','saved_jobs']) {
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

  // ── Utilities ─────────────────────────────────────────────────────────────

  static Future<void> clearAllCaches() async {
    final d = await db;
    for (final t in ['posts','comments','liked_posts','saved_posts','job_posts','saved_jobs']) {
      await d.delete(t);
    }
  }
}