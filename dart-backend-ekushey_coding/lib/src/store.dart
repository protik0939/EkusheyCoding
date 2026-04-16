import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

class InMemoryStore {
  InMemoryStore() {
    _seed();
  }

  final Random _random = Random.secure();

  final List<Map<String, dynamic>> users = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> blogs = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> exercises = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> tutorials = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> favorites = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> activities = <Map<String, dynamic>>[];

  final Map<String, int> tokenToUserId = <String, int>{};

  int _userId = 1;
  int _blogId = 1;
  int _exerciseId = 1;
  int _tutorialId = 1;
  int _favoriteId = 1;
  int _activityId = 1;

  Connection? _db;
  bool _isPersistenceEnabled = false;
  String? _persistenceStatus;

  bool get isPersistenceEnabled => _isPersistenceEnabled;
  String? get persistenceStatus => _persistenceStatus;

  int nextBlogId() => _blogId++;
  int nextExerciseId() => _exerciseId++;
  int nextTutorialId() => _tutorialId++;
  int nextFavoriteId() => _favoriteId++;
  int nextActivityId() => _activityId++;

  static const List<String> _tokenChars = <String>[
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];

  Future<void> initializePersistence({bool loadExisting = true}) async {
    final connectionString =
        Platform.environment['DATABASE_URL']?.trim() ??
        Platform.environment['POSTGRES_CONNECTION_STRING']?.trim() ??
        await _readConnectionStringFromEnvFile();

    if (connectionString == null || connectionString.isEmpty) {
      _isPersistenceEnabled = false;
      _persistenceStatus =
          'PostgreSQL disabled (set DATABASE_URL/POSTGRES_CONNECTION_STRING or .env).';
      return;
    }

    try {
      _db = await _openConnectionFromUrl(connectionString);
      await _ensurePersistenceTable();

      var loaded = false;
      if (loadExisting) {
        loaded = await _loadStateFromDatabase();
      }
      if (!loaded) {
        await persistState();
      }

      _isPersistenceEnabled = true;
      _persistenceStatus = 'PostgreSQL persistence enabled.';
    } catch (error) {
      _isPersistenceEnabled = false;
      _persistenceStatus = 'PostgreSQL disabled due to error: $error';
    }
  }

  Future<Connection> _openConnectionFromUrl(String connectionString) {
    final uri = Uri.parse(connectionString);
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'postgres' && scheme != 'postgresql') {
      throw const FormatException(
        'Connection string must use postgres:// or postgresql://',
      );
    }

    final databaseName = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .join('/');
    if (databaseName.isEmpty) {
      throw const FormatException('Database name is missing in connection URL');
    }

    final userInfoParts = uri.userInfo.split(':');
    final username = userInfoParts.isNotEmpty && userInfoParts.first.isNotEmpty
        ? Uri.decodeComponent(userInfoParts.first)
        : null;
    final password = userInfoParts.length > 1
        ? Uri.decodeComponent(userInfoParts.sublist(1).join(':'))
        : null;

    final sslModeValue = uri.queryParameters['sslmode']?.toLowerCase();
    final sslQuery = uri.queryParameters['ssl']?.toLowerCase();
    final sslRequired =
        sslQuery == 'true' ||
        sslModeValue == 'require' ||
        sslModeValue == 'verify-ca' ||
        sslModeValue == 'verify-full';

    return Connection.open(
      Endpoint(
        host: uri.host.isEmpty ? 'localhost' : uri.host,
        port: uri.hasPort ? uri.port : 5432,
        database: databaseName,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(
        sslMode: sslRequired ? SslMode.require : SslMode.disable,
      ),
    );
  }

  Future<String?> _readConnectionStringFromEnvFile() async {
    try {
      final file = File('.env');
      if (!await file.exists()) {
        return null;
      }

      final lines = await file.readAsLines();
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) {
          continue;
        }

        final separator = line.indexOf('=');
        if (separator <= 0) {
          continue;
        }

        final key = line.substring(0, separator).trim();
        if (key != 'DATABASE_URL' && key != 'POSTGRES_CONNECTION_STRING') {
          continue;
        }

        final value = line.substring(separator + 1).trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> closePersistence() async {
    await _db?.close();
    _db = null;
    _isPersistenceEnabled = false;
  }

  Future<void> persistState() async {
    if (!_isPersistenceEnabled || _db == null) {
      return;
    }

    await _db!.runTx((session) async {
      await session.execute('DELETE FROM activities');
      await session.execute('DELETE FROM favorites');
      await session.execute('DELETE FROM tutorials');
      await session.execute('DELETE FROM exercises');
      await session.execute('DELETE FROM blogs');
      await session.execute('DELETE FROM auth_tokens');
      await session.execute('DELETE FROM users');

      for (final user in users) {
        await session.execute(
          Sql.named(
            'INSERT INTO users '
            '(id, email, name, role, password_hash, api_token_hash, username, '
            'skill_level, current_streak, longest_streak, is_active, '
            'created_at, updated_at, payload) '
            'VALUES '
            '(@id, @email, @name, @role, @password_hash, @api_token_hash, @username, '
            '@skill_level, @current_streak, @longest_streak, @is_active, '
            '@created_at, @updated_at, @payload::jsonb)',
          ),
          parameters: <String, Object?>{
            'id': (user['id'] as num?)?.toInt(),
            'email': '${user['email'] ?? ''}',
            'name': '${user['name'] ?? ''}',
            'role': '${user['role'] ?? 'user'}',
            'password_hash': '${user['password_hash'] ?? ''}',
            'api_token_hash': user['api_token_hash'],
            'username': user['username'],
            'skill_level': user['skill_level'],
            'current_streak': (user['current_streak'] as num?)?.toInt() ?? 0,
            'longest_streak': (user['longest_streak'] as num?)?.toInt() ?? 0,
            'is_active': user['is_active'] ?? true,
            'created_at': user['created_at'],
            'updated_at': user['updated_at'],
            'payload': jsonEncode(user),
          },
        );
      }

      for (final tokenEntry in tokenToUserId.entries) {
        await session.execute(
          Sql.named(
            'INSERT INTO auth_tokens (token, user_id, created_at, last_used_at) '
            'VALUES (@token, @user_id, @now, @now)',
          ),
          parameters: <String, Object?>{
            'token': tokenEntry.key,
            'user_id': tokenEntry.value,
            'now': DateTime.now().toUtc().toIso8601String(),
          },
        );
      }

      for (final blog in blogs) {
        await session.execute(
          Sql.named(
            'INSERT INTO blogs '
            '(id, slug, title, title_bn, author, author_id, category, status, views, '
            'published_at, created_at, updated_at, payload) '
            'VALUES '
            '(@id, @slug, @title, @title_bn, @author, @author_id, @category, @status, @views, '
            '@published_at, @created_at, @updated_at, @payload::jsonb)',
          ),
          parameters: <String, Object?>{
            'id': (blog['id'] as num?)?.toInt(),
            'slug': blog['slug'],
            'title': blog['title'],
            'title_bn': blog['title_bn'],
            'author': blog['author'],
            'author_id': (blog['author_id'] as num?)?.toInt(),
            'category': blog['category'],
            'status': blog['status'],
            'views': (blog['views'] as num?)?.toInt() ?? 0,
            'published_at': blog['published_at'],
            'created_at': blog['created_at'],
            'updated_at': blog['updated_at'],
            'payload': jsonEncode(blog),
          },
        );
      }

      for (final tutorial in tutorials) {
        await session.execute(
          Sql.named(
            'INSERT INTO tutorials '
            '(id, language_id, title, tutorial_order, is_published, created_at, updated_at, payload) '
            'VALUES '
            '(@id, @language_id, @title, @tutorial_order, @is_published, @created_at, @updated_at, @payload::jsonb)',
          ),
          parameters: <String, Object?>{
            'id': (tutorial['id'] as num?)?.toInt(),
            'language_id': tutorial['language_id'],
            'title': tutorial['title'],
            'tutorial_order': (tutorial['order'] as num?)?.toInt() ?? 0,
            'is_published': tutorial['is_published'] ?? true,
            'created_at': tutorial['created_at'],
            'updated_at': tutorial['updated_at'],
            'payload': jsonEncode(tutorial),
          },
        );
      }

      for (final exercise in exercises) {
        await session.execute(
          Sql.named(
            'INSERT INTO exercises '
            '(id, slug, title, title_bn, difficulty, category, language_id, status, views, completions, '
            'published_at, created_at, updated_at, payload) '
            'VALUES '
            '(@id, @slug, @title, @title_bn, @difficulty, @category, @language_id, @status, @views, @completions, '
            '@published_at, @created_at, @updated_at, @payload::jsonb)',
          ),
          parameters: <String, Object?>{
            'id': (exercise['id'] as num?)?.toInt(),
            'slug': exercise['slug'],
            'title': exercise['title'],
            'title_bn': exercise['title_bn'],
            'difficulty': exercise['difficulty'],
            'category': exercise['category'],
            'language_id': exercise['language_id'],
            'status': exercise['status'],
            'views': (exercise['views'] as num?)?.toInt() ?? 0,
            'completions': (exercise['completions'] as num?)?.toInt() ?? 0,
            'published_at': exercise['published_at'],
            'created_at': exercise['created_at'],
            'updated_at': exercise['updated_at'],
            'payload': jsonEncode(exercise),
          },
        );
      }

      for (final favorite in favorites) {
        await session.execute(
          Sql.named(
            'INSERT INTO favorites '
            '(id, user_id, type, title, category, favorite_order, created_at, updated_at, payload) '
            'VALUES '
            '(@id, @user_id, @type, @title, @category, @favorite_order, @created_at, @updated_at, @payload::jsonb)',
          ),
          parameters: <String, Object?>{
            'id': (favorite['id'] as num?)?.toInt(),
            'user_id': (favorite['user_id'] as num?)?.toInt(),
            'type': favorite['type'],
            'title': favorite['title'],
            'category': favorite['category'],
            'favorite_order': (favorite['order'] as num?)?.toInt() ?? 0,
            'created_at': favorite['created_at'],
            'updated_at': favorite['updated_at'],
            'payload': jsonEncode(favorite),
          },
        );
      }

      for (final activity in activities) {
        await session.execute(
          Sql.named(
            'INSERT INTO activities '
            '(id, user_id, minutes_active, lessons_completed, exercises_completed, '
            'quizzes_completed, blogs_read, comments_posted, code_snippets_created, '
            'created_at, updated_at, payload) '
            'VALUES '
            '(@id, @user_id, @minutes_active, @lessons_completed, @exercises_completed, '
            '@quizzes_completed, @blogs_read, @comments_posted, @code_snippets_created, '
            '@created_at, @updated_at, @payload::jsonb)',
          ),
          parameters: <String, Object?>{
            'id': (activity['id'] as num?)?.toInt(),
            'user_id': (activity['user_id'] as num?)?.toInt(),
            'minutes_active':
                (activity['minutes_active'] as num?)?.toInt() ?? 0,
            'lessons_completed':
                (activity['lessons_completed'] as num?)?.toInt() ?? 0,
            'exercises_completed':
                (activity['exercises_completed'] as num?)?.toInt() ?? 0,
            'quizzes_completed':
                (activity['quizzes_completed'] as num?)?.toInt() ?? 0,
            'blogs_read': (activity['blogs_read'] as num?)?.toInt() ?? 0,
            'comments_posted':
                (activity['comments_posted'] as num?)?.toInt() ?? 0,
            'code_snippets_created':
                (activity['code_snippets_created'] as num?)?.toInt() ?? 0,
            'created_at': activity['created_at'],
            'updated_at': activity['updated_at'],
            'payload': jsonEncode(activity),
          },
        );
      }
    });
  }

  Future<void> _ensurePersistenceTable() async {
    if (_db == null) {
      return;
    }

    await _db!.execute(
      'CREATE TABLE IF NOT EXISTS users ('
      'id BIGINT PRIMARY KEY, '
      'email TEXT NOT NULL UNIQUE, '
      'name TEXT NOT NULL, '
      "role TEXT NOT NULL DEFAULT 'user', "
      'password_hash TEXT NOT NULL, '
      'api_token_hash TEXT, '
      'username TEXT UNIQUE, '
      'skill_level TEXT, '
      'current_streak INTEGER NOT NULL DEFAULT 0, '
      'longest_streak INTEGER NOT NULL DEFAULT 0, '
      'is_active BOOLEAN NOT NULL DEFAULT TRUE, '
      'created_at TEXT, '
      'updated_at TEXT, '
      "payload JSONB NOT NULL DEFAULT '{}'::jsonb"
      ')',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at)',
    );

    await _db!.execute(
      'CREATE TABLE IF NOT EXISTS auth_tokens ('
      'token TEXT PRIMARY KEY, '
      'user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, '
      'created_at TEXT, '
      'last_used_at TEXT'
      ')',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_auth_tokens_user_id ON auth_tokens(user_id)',
    );

    await _db!.execute(
      'CREATE TABLE IF NOT EXISTS blogs ('
      'id BIGINT PRIMARY KEY, '
      'slug TEXT NOT NULL UNIQUE, '
      'title TEXT NOT NULL, '
      'title_bn TEXT, '
      'author TEXT, '
      'author_id BIGINT REFERENCES users(id) ON DELETE SET NULL, '
      'category TEXT, '
      "status TEXT NOT NULL DEFAULT 'draft', "
      'views BIGINT NOT NULL DEFAULT 0, '
      'published_at TEXT, '
      'created_at TEXT, '
      'updated_at TEXT, '
      "payload JSONB NOT NULL DEFAULT '{}'::jsonb"
      ')',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_blogs_status_published ON blogs(status, published_at)',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_blogs_category ON blogs(category)',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_blogs_views ON blogs(views)',
    );

    await _db!.execute(
      'CREATE TABLE IF NOT EXISTS tutorials ('
      'id BIGINT PRIMARY KEY, '
      'language_id TEXT NOT NULL, '
      'title TEXT NOT NULL, '
      'tutorial_order INTEGER NOT NULL DEFAULT 0, '
      'is_published BOOLEAN NOT NULL DEFAULT TRUE, '
      'created_at TEXT, '
      'updated_at TEXT, '
      "payload JSONB NOT NULL DEFAULT '{}'::jsonb"
      ')',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_tutorials_lang_pub_order ON tutorials(language_id, is_published, tutorial_order)',
    );

    await _db!.execute(
      'CREATE TABLE IF NOT EXISTS exercises ('
      'id BIGINT PRIMARY KEY, '
      'slug TEXT NOT NULL UNIQUE, '
      'title TEXT NOT NULL, '
      'title_bn TEXT, '
      'difficulty TEXT, '
      'category TEXT, '
      'language_id TEXT, '
      "status TEXT NOT NULL DEFAULT 'draft', "
      'views BIGINT NOT NULL DEFAULT 0, '
      'completions BIGINT NOT NULL DEFAULT 0, '
      'published_at TEXT, '
      'created_at TEXT, '
      'updated_at TEXT, '
      "payload JSONB NOT NULL DEFAULT '{}'::jsonb"
      ')',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_exercises_status_published ON exercises(status, published_at)',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_exercises_filters ON exercises(difficulty, language_id, category)',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_exercises_views ON exercises(views)',
    );

    await _db!.execute(
      'CREATE TABLE IF NOT EXISTS favorites ('
      'id BIGINT PRIMARY KEY, '
      'user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, '
      'type TEXT NOT NULL, '
      'title TEXT NOT NULL, '
      'category TEXT, '
      'favorite_order INTEGER NOT NULL DEFAULT 0, '
      'created_at TEXT, '
      'updated_at TEXT, '
      "payload JSONB NOT NULL DEFAULT '{}'::jsonb"
      ')',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorites_user_type_order ON favorites(user_id, type, favorite_order)',
    );

    await _db!.execute(
      'CREATE TABLE IF NOT EXISTS activities ('
      'id BIGINT PRIMARY KEY, '
      'user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, '
      'minutes_active INTEGER NOT NULL DEFAULT 0, '
      'lessons_completed INTEGER NOT NULL DEFAULT 0, '
      'exercises_completed INTEGER NOT NULL DEFAULT 0, '
      'quizzes_completed INTEGER NOT NULL DEFAULT 0, '
      'blogs_read INTEGER NOT NULL DEFAULT 0, '
      'comments_posted INTEGER NOT NULL DEFAULT 0, '
      'code_snippets_created INTEGER NOT NULL DEFAULT 0, '
      'created_at TEXT, '
      'updated_at TEXT, '
      "payload JSONB NOT NULL DEFAULT '{}'::jsonb"
      ')',
    );
    await _db!.execute(
      'CREATE INDEX IF NOT EXISTS idx_activities_user_created ON activities(user_id, created_at)',
    );
  }

  Future<bool> _loadStateFromDatabase() async {
    if (_db == null) {
      return false;
    }

    final countResult = await _db!.execute(
      'SELECT '
      '(SELECT COUNT(*) FROM users) + '
      '(SELECT COUNT(*) FROM blogs) + '
      '(SELECT COUNT(*) FROM tutorials) + '
      '(SELECT COUNT(*) FROM exercises) + '
      '(SELECT COUNT(*) FROM favorites) + '
      '(SELECT COUNT(*) FROM activities) AS total_count',
    );

    final total = (countResult.first[0] as num?)?.toInt() ?? 0;
    if (total == 0) {
      return false;
    }

    users
      ..clear()
      ..addAll(await _loadUsers());
    blogs
      ..clear()
      ..addAll(await _loadBlogs());
    tutorials
      ..clear()
      ..addAll(await _loadTutorials());
    exercises
      ..clear()
      ..addAll(await _loadExercises());
    favorites
      ..clear()
      ..addAll(await _loadFavorites());
    activities
      ..clear()
      ..addAll(await _loadActivities());

    tokenToUserId
      ..clear()
      ..addAll(await _loadTokens());

    _userId = _nextId(users);
    _blogId = _nextId(blogs);
    _exerciseId = _nextId(exercises);
    _tutorialId = _nextId(tutorials);
    _favoriteId = _nextId(favorites);
    _activityId = _nextId(activities);

    return true;
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final rows = await _db!.execute(
      'SELECT id, email, name, role, password_hash, api_token_hash, username, '
      'skill_level, current_streak, longest_streak, is_active, created_at, updated_at, payload '
      'FROM users ORDER BY id ASC',
    );

    return rows.map((row) {
      final data = row.toColumnMap();
      final payload = _payloadToMap(data['payload']);
      payload['id'] = (data['id'] as num?)?.toInt();
      payload['email'] = data['email'];
      payload['name'] = data['name'];
      payload['role'] = data['role'];
      payload['password_hash'] = data['password_hash'];
      payload['api_token_hash'] = data['api_token_hash'];
      payload['username'] = data['username'];
      payload['skill_level'] = data['skill_level'];
      payload['current_streak'] =
          (data['current_streak'] as num?)?.toInt() ?? 0;
      payload['longest_streak'] =
          (data['longest_streak'] as num?)?.toInt() ?? 0;
      payload['is_active'] = data['is_active'] ?? true;
      payload['created_at'] = data['created_at'];
      payload['updated_at'] = data['updated_at'];
      return payload;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadBlogs() async {
    final rows = await _db!.execute(
      'SELECT id, slug, title, title_bn, author, author_id, category, status, views, '
      'published_at, created_at, updated_at, payload '
      'FROM blogs ORDER BY id ASC',
    );

    return rows.map((row) {
      final data = row.toColumnMap();
      final payload = _payloadToMap(data['payload']);
      payload['id'] = (data['id'] as num?)?.toInt();
      payload['slug'] = data['slug'];
      payload['title'] = data['title'];
      payload['title_bn'] = data['title_bn'];
      payload['author'] = data['author'];
      payload['author_id'] = (data['author_id'] as num?)?.toInt();
      payload['category'] = data['category'];
      payload['status'] = data['status'];
      payload['views'] = (data['views'] as num?)?.toInt() ?? 0;
      payload['published_at'] = data['published_at'];
      payload['created_at'] = data['created_at'];
      payload['updated_at'] = data['updated_at'];
      return payload;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadTutorials() async {
    final rows = await _db!.execute(
      'SELECT id, language_id, title, tutorial_order, is_published, created_at, updated_at, payload '
      'FROM tutorials ORDER BY tutorial_order ASC, id ASC',
    );

    return rows.map((row) {
      final data = row.toColumnMap();
      final payload = _payloadToMap(data['payload']);
      payload['id'] = (data['id'] as num?)?.toInt();
      payload['language_id'] = data['language_id'];
      payload['title'] = data['title'];
      payload['order'] = (data['tutorial_order'] as num?)?.toInt() ?? 0;
      payload['is_published'] = data['is_published'] ?? true;
      payload['created_at'] = data['created_at'];
      payload['updated_at'] = data['updated_at'];
      return payload;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadExercises() async {
    final rows = await _db!.execute(
      'SELECT id, slug, title, title_bn, difficulty, category, language_id, status, views, completions, '
      'published_at, created_at, updated_at, payload '
      'FROM exercises ORDER BY id ASC',
    );

    return rows.map((row) {
      final data = row.toColumnMap();
      final payload = _payloadToMap(data['payload']);
      payload['id'] = (data['id'] as num?)?.toInt();
      payload['slug'] = data['slug'];
      payload['title'] = data['title'];
      payload['title_bn'] = data['title_bn'];
      payload['difficulty'] = data['difficulty'];
      payload['category'] = data['category'];
      payload['language_id'] = data['language_id'];
      payload['status'] = data['status'];
      payload['views'] = (data['views'] as num?)?.toInt() ?? 0;
      payload['completions'] = (data['completions'] as num?)?.toInt() ?? 0;
      payload['published_at'] = data['published_at'];
      payload['created_at'] = data['created_at'];
      payload['updated_at'] = data['updated_at'];
      return payload;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadFavorites() async {
    final rows = await _db!.execute(
      'SELECT id, user_id, type, title, category, favorite_order, created_at, updated_at, payload '
      'FROM favorites ORDER BY favorite_order ASC, id ASC',
    );

    return rows.map((row) {
      final data = row.toColumnMap();
      final payload = _payloadToMap(data['payload']);
      payload['id'] = (data['id'] as num?)?.toInt();
      payload['user_id'] = (data['user_id'] as num?)?.toInt();
      payload['type'] = data['type'];
      payload['title'] = data['title'];
      payload['category'] = data['category'];
      payload['order'] = (data['favorite_order'] as num?)?.toInt() ?? 0;
      payload['created_at'] = data['created_at'];
      payload['updated_at'] = data['updated_at'];
      return payload;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadActivities() async {
    final rows = await _db!.execute(
      'SELECT id, user_id, minutes_active, lessons_completed, exercises_completed, '
      'quizzes_completed, blogs_read, comments_posted, code_snippets_created, '
      'created_at, updated_at, payload '
      'FROM activities ORDER BY created_at DESC, id DESC',
    );

    return rows.map((row) {
      final data = row.toColumnMap();
      final payload = _payloadToMap(data['payload']);
      payload['id'] = (data['id'] as num?)?.toInt();
      payload['user_id'] = (data['user_id'] as num?)?.toInt();
      payload['minutes_active'] =
          (data['minutes_active'] as num?)?.toInt() ?? 0;
      payload['lessons_completed'] =
          (data['lessons_completed'] as num?)?.toInt() ?? 0;
      payload['exercises_completed'] =
          (data['exercises_completed'] as num?)?.toInt() ?? 0;
      payload['quizzes_completed'] =
          (data['quizzes_completed'] as num?)?.toInt() ?? 0;
      payload['blogs_read'] = (data['blogs_read'] as num?)?.toInt() ?? 0;
      payload['comments_posted'] =
          (data['comments_posted'] as num?)?.toInt() ?? 0;
      payload['code_snippets_created'] =
          (data['code_snippets_created'] as num?)?.toInt() ?? 0;
      payload['created_at'] = data['created_at'];
      payload['updated_at'] = data['updated_at'];
      return payload;
    }).toList();
  }

  Future<Map<String, int>> _loadTokens() async {
    final rows = await _db!.execute('SELECT token, user_id FROM auth_tokens');
    final output = <String, int>{};
    for (final row in rows) {
      final data = row.toColumnMap();
      final token = '${data['token'] ?? ''}';
      final userId = (data['user_id'] as num?)?.toInt();
      if (token.isNotEmpty && userId != null) {
        output[token] = userId;
      }
    }
    return output;
  }

  Map<String, dynamic> _payloadToMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is String && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  int _nextId(List<Map<String, dynamic>> items) {
    var maxId = 0;
    for (final item in items) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id > maxId) {
        maxId = id;
      }
    }
    return maxId + 1;
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  String hashPassword(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  String _token() {
    final b = StringBuffer();
    for (var i = 0; i < 60; i++) {
      b.write(_tokenChars[_random.nextInt(_tokenChars.length)]);
    }
    return b.toString();
  }

  Map<String, dynamic> sanitizeUser(Map<String, dynamic> user) {
    final copy = Map<String, dynamic>.from(user);
    copy.remove('password_hash');
    copy.remove('api_token_hash');
    return copy;
  }

  Map<String, dynamic>? userFromToken(String? token) {
    if (token == null || token.isEmpty) return null;
    final userId = tokenToUserId[token];
    if (userId == null) return null;
    try {
      return users.firstWhere((u) => u['id'] == userId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? userById(int id) {
    for (final u in users) {
      if (u['id'] == id) return u;
    }
    return null;
  }

  bool isAdmin(Map<String, dynamic>? user) =>
      user != null && user['role'] == 'admin';

  Map<String, dynamic> register({
    required String name,
    required String email,
    required String password,
  }) {
    final exists = users.any(
      (u) => '${u['email']}'.toLowerCase() == email.toLowerCase(),
    );
    if (exists) {
      throw StateError('Email already exists');
    }

    final token = _token();
    final now = _now();
    final user = <String, dynamic>{
      'id': _userId++,
      'name': name,
      'email': email,
      'role': 'user',
      'password_hash': hashPassword(password),
      'api_token_hash': hashPassword(token),
      'username': null,
      'phone': null,
      'bio': null,
      'avatar': null,
      'github_url': null,
      'linkedin_url': null,
      'twitter_url': null,
      'portfolio_url': null,
      'location': null,
      'timezone': null,
      'date_of_birth': null,
      'skill_level': 'beginner',
      'programming_languages': <String>[],
      'interests': <String>[],
      'badges': <String>[],
      'daily_goal_minutes': 0,
      'email_notifications': true,
      'is_public': true,
      'current_streak': 0,
      'longest_streak': 0,
      'created_at': now,
      'updated_at': now,
      'email_verified_at': null,
    };

    users.add(user);
    tokenToUserId[token] = user['id'] as int;

    return <String, dynamic>{
      'message': 'User registered successfully',
      'user': sanitizeUser(user),
      'access_token': token,
      'token_type': 'Bearer',
    };
  }

  Map<String, dynamic> login({
    required String email,
    required String password,
  }) {
    Map<String, dynamic>? user;
    for (final u in users) {
      if ('${u['email']}'.toLowerCase() == email.toLowerCase()) {
        user = u;
        break;
      }
    }

    if (user == null || user['password_hash'] != hashPassword(password)) {
      throw StateError('The provided credentials are incorrect.');
    }

    final token = _token();
    user['api_token_hash'] = hashPassword(token);
    user['updated_at'] = _now();
    tokenToUserId[token] = user['id'] as int;

    return <String, dynamic>{
      'message': 'Login successful',
      'user': sanitizeUser(user),
      'access_token': token,
      'token_type': 'Bearer',
    };
  }

  void logout(String token) {
    tokenToUserId.remove(token);
  }

  Map<String, dynamic> profilePayload(Map<String, dynamic> user) {
    return <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'user': <String, dynamic>{
          'id': user['id'],
          'name': user['name'],
          'email': user['email'],
          'email_verified_at': user['email_verified_at'],
          'created_at': user['created_at'],
          'updated_at': user['updated_at'],
          'role': user['role'],
        },
        'profile': <String, dynamic>{
          'username': user['username'],
          'phone': user['phone'],
          'bio': user['bio'],
          'avatar': user['avatar'],
          'github_url': user['github_url'],
          'linkedin_url': user['linkedin_url'],
          'twitter_url': user['twitter_url'],
          'portfolio_url': user['portfolio_url'],
          'location': user['location'],
          'timezone': user['timezone'],
          'date_of_birth': user['date_of_birth'],
          'skill_level': user['skill_level'],
          'programming_languages': user['programming_languages'] ?? <String>[],
          'interests': user['interests'] ?? <String>[],
          'daily_goal_minutes': user['daily_goal_minutes'] ?? 0,
          'email_notifications': user['email_notifications'] ?? true,
          'is_public': user['is_public'] ?? true,
        },
        'stats': <String, dynamic>{
          'total_courses': 0,
          'hours_learned':
              activities
                  .where((a) => a['user_id'] == user['id'])
                  .fold<int>(
                    0,
                    (acc, a) => acc + ((a['minutes_active'] as int?) ?? 0),
                  ) ~/
              60,
          'certificates_earned': 0,
          'current_streak': user['current_streak'] ?? 0,
        },
      },
    };
  }

  Map<String, dynamic> paginate(
    List<Map<String, dynamic>> source, {
    required int page,
    required int perPage,
  }) {
    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage < 1 ? 10 : perPage;

    final total = source.length;
    final lastPage = total == 0 ? 1 : ((total - 1) ~/ safePerPage) + 1;
    final currentPage = safePage > lastPage ? lastPage : safePage;
    final start = (currentPage - 1) * safePerPage;
    final end = min(start + safePerPage, total);
    final slice = start >= total
        ? <Map<String, dynamic>>[]
        : source.sublist(start, end);

    return <String, dynamic>{
      'data': slice,
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': safePerPage,
      'total': total,
      'next_page_url': currentPage < lastPage
          ? '?page=${currentPage + 1}'
          : null,
      'prev_page_url': currentPage > 1 ? '?page=${currentPage - 1}' : null,
    };
  }

  void _seed() {
    final now = DateTime.now().toUtc();

    final admin = <String, dynamic>{
      'id': _userId++,
      'name': 'Admin',
      'email': 'admin@ekusheycoding.com',
      'role': 'admin',
      'password_hash': hashPassword('admin123'),
      'api_token_hash': null,
      'username': 'admin',
      'phone': null,
      'bio': 'Platform administrator',
      'avatar': null,
      'github_url': null,
      'linkedin_url': null,
      'twitter_url': null,
      'portfolio_url': null,
      'location': 'Dhaka, Bangladesh',
      'timezone': 'Asia/Dhaka',
      'date_of_birth': null,
      'skill_level': 'expert',
      'programming_languages': <String>['JavaScript', 'PHP', 'Dart'],
      'interests': <String>['Web Development', 'Platform Management'],
      'badges': <String>['admin'],
      'daily_goal_minutes': 60,
      'email_notifications': true,
      'is_public': true,
      'current_streak': 14,
      'longest_streak': 30,
      'created_at': now.subtract(const Duration(days: 120)).toIso8601String(),
      'updated_at': now.toIso8601String(),
      'email_verified_at': now.toIso8601String(),
    };

    final testUser = <String, dynamic>{
      'id': _userId++,
      'name': 'Test User',
      'email': 'test@example.com',
      'role': 'user',
      'password_hash': hashPassword('password123'),
      'api_token_hash': null,
      'username': 'testuser',
      'phone': null,
      'bio': 'Learning full stack development.',
      'avatar': null,
      'github_url': null,
      'linkedin_url': null,
      'twitter_url': null,
      'portfolio_url': null,
      'location': 'Chattogram, Bangladesh',
      'timezone': 'Asia/Dhaka',
      'date_of_birth': null,
      'skill_level': 'beginner',
      'programming_languages': <String>['JavaScript'],
      'interests': <String>['Frontend Development'],
      'badges': <String>[],
      'daily_goal_minutes': 45,
      'email_notifications': true,
      'is_public': true,
      'current_streak': 3,
      'longest_streak': 7,
      'created_at': now.subtract(const Duration(days: 40)).toIso8601String(),
      'updated_at': now.toIso8601String(),
      'email_verified_at': now.toIso8601String(),
    };

    users
      ..add(admin)
      ..add(testUser);

    final seededBlogs = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': 'Introduction to Laravel',
        'title_bn': 'লারাভেল পরিচিতি',
        'excerpt':
            'Learn the basics of Laravel framework and modern PHP development.',
        'excerpt_bn': 'লারাভেল ফ্রেমওয়ার্কের মূল বিষয়গুলি শিখুন।',
        'content':
            'Laravel is a web framework with elegant syntax and developer-friendly tooling.',
        'content_bn': 'লারাভেল একটি শক্তিশালী এবং মার্জিত ওয়েব ফ্রেমওয়ার্ক।',
        'author': 'John Doe',
        'author_bn': 'জন ডো',
        'author_id': admin['id'],
        'category': 'Web Development',
        'category_bn': 'ওয়েব ডেভেলপমেন্ট',
        'tags': <String>['Laravel', 'PHP', 'Framework'],
        'tags_bn': <String>['লারাভেল', 'পিএইচপি', 'ফ্রেমওয়ার্ক'],
        'read_time': '8 min read',
        'read_time_bn': '৮ মিনিট পড়ুন',
        'image_url': 'https://picsum.photos/800/400?random=1',
        'featured_image': null,
        'slug': 'introduction-to-laravel',
        'status': 'published',
        'views': 1234,
        'published_at': now.subtract(const Duration(days: 5)).toIso8601String(),
      },
      <String, dynamic>{
        'title': 'Getting Started with React',
        'title_bn': 'রিঅ্যাক্ট দিয়ে শুরু করা',
        'excerpt':
            'A practical guide to React fundamentals and component-driven UI.',
        'excerpt_bn': 'রিঅ্যাক্টের মৌলিক বিষয়ের একটি প্র্যাকটিক্যাল গাইড।',
        'content':
            'React is a JavaScript library for building user interfaces.',
        'content_bn': 'রিঅ্যাক্ট একটি জনপ্রিয় জাভাস্ক্রিপ্ট লাইব্রেরি।',
        'author': 'Jane Smith',
        'author_bn': 'জেন স্মিথ',
        'author_id': admin['id'],
        'category': 'Frontend Development',
        'category_bn': 'ফ্রন্টএন্ড ডেভেলপমেন্ট',
        'tags': <String>['React', 'JavaScript', 'Frontend'],
        'tags_bn': <String>['রিঅ্যাক্ট', 'জাভাস্ক্রিপ্ট', 'ফ্রন্টএন্ড'],
        'read_time': '10 min read',
        'read_time_bn': '১০ মিনিট পড়ুন',
        'image_url': 'https://picsum.photos/800/400?random=2',
        'featured_image': null,
        'slug': 'getting-started-with-react',
        'status': 'published',
        'views': 2156,
        'published_at': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
      <String, dynamic>{
        'title': 'Database Design Best Practices',
        'title_bn': 'ডাটাবেস ডিজাইনের সেরা অনুশীলন',
        'excerpt': 'Essential principles for scalable database schema design.',
        'excerpt_bn': 'স্কেলেবল ডাটাবেস স্কিমা ডিজাইনের গুরুত্বপূর্ণ নীতিগুলি।',
        'content':
            'This guide covers normalization, indexing, and relationship modeling.',
        'content_bn':
            'এই গাইডে নরমালাইজেশন, ইনডেক্সিং এবং সম্পর্ক নিয়ে আলোচনা করা হয়েছে।',
        'author': 'Mike Johnson',
        'author_bn': 'মাইক জনসন',
        'author_id': admin['id'],
        'category': 'Database',
        'category_bn': 'ডাটাবেস',
        'tags': <String>['Database', 'SQL', 'Design'],
        'tags_bn': <String>['ডাটাবেস', 'এসকিউএল', 'ডিজাইন'],
        'read_time': '12 min read',
        'read_time_bn': '১২ মিনিট পড়ুন',
        'image_url': 'https://picsum.photos/800/400?random=3',
        'featured_image': null,
        'slug': 'database-design-best-practices',
        'status': 'published',
        'views': 987,
        'published_at': now.subtract(const Duration(days: 7)).toIso8601String(),
      },
      <String, dynamic>{
        'title': 'Draft: Future of Web Development',
        'title_bn': 'খসড়া: ওয়েব ডেভেলপমেন্টের ভবিষ্যৎ',
        'excerpt': 'Exploring upcoming trends and technologies.',
        'excerpt_bn': 'ভবিষ্যতের প্রযুক্তিগত ট্রেন্ড নিয়ে আলোচনা।',
        'content':
            'This is a draft article about the future of web development.',
        'content_bn':
            'এটি ওয়েব ডেভেলপমেন্টের ভবিষ্যৎ নিয়ে একটি খসড়া নিবন্ধ।',
        'author': 'Alex Turner',
        'author_bn': 'অ্যালেক্স টার্নার',
        'author_id': admin['id'],
        'category': 'Web Development',
        'category_bn': 'ওয়েব ডেভেলপমেন্ট',
        'tags': <String>['Future', 'Trends', 'Web'],
        'tags_bn': <String>['ভবিষ্যৎ', 'ট্রেন্ড', 'ওয়েব'],
        'read_time': '5 min read',
        'read_time_bn': '৫ মিনিট পড়ুন',
        'image_url': 'https://picsum.photos/800/400?random=4',
        'featured_image': null,
        'slug': 'future-of-web-development',
        'status': 'draft',
        'views': 0,
        'published_at': null,
      },
    ];

    for (final data in seededBlogs) {
      blogs.add(<String, dynamic>{
        'id': _blogId++,
        ...data,
        'created_at': now.subtract(const Duration(days: 9)).toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    }

    final seededExercises = <Map<String, dynamic>>[
      <String, dynamic>{
        'slug': 'build-a-simple-calculator',
        'title': 'Build a Simple Calculator',
        'title_bn': 'একটি সাধারণ ক্যালকুলেটর তৈরি করুন',
        'description': 'Create a calculator with arithmetic operations.',
        'description_bn': 'গণনার মৌলিক অপারেশনসহ একটি ক্যালকুলেটর তৈরি করুন।',
        'instructions':
            'Implement add, subtract, multiply, and divide functions.',
        'instructions_bn': 'যোগ, বিয়োগ, গুণ ও ভাগ ফাংশন তৈরি করুন।',
        'problem_statement': 'Write functions for basic arithmetic operations.',
        'problem_statement_bn': 'মৌলিক গাণিতিক অপারেশনের জন্য ফাংশন লিখুন।',
        'input_description': 'Two numbers a and b',
        'input_description_bn': 'দুটি সংখ্যা a এবং b',
        'output_description': 'Result of operation',
        'output_description_bn': 'অপারেশনের ফলাফল',
        'sample_input': 'a=5, b=2',
        'sample_input_bn': 'a=৫, b=২',
        'sample_output': 'add=7, sub=3, mul=10, div=2.5',
        'sample_output_bn': 'যোগ=৭, বিয়োগ=৩, গুণ=১০, ভাগ=২.৫',
        'difficulty': 'Beginner',
        'difficulty_bn': 'সহজ',
        'duration': 30,
        'duration_bn': '৩০ মিনিট',
        'category': 'Programming Basics',
        'category_bn': 'প্রোগ্রামিং বেসিক',
        'tags': <String>['JavaScript', 'Beginner', 'Functions'],
        'tags_bn': <String>['জাভাস্ক্রিপ্ট', 'শিক্ষানবিস', 'ফাংশন'],
        'starter_code': 'function add(a, b) {\n  // TODO\n}',
        'solution_code': 'function add(a, b) { return a + b; }',
        'programming_language': 'JavaScript',
        'language_id': 'javascript',
        'language_name': 'JavaScript',
        'language_name_bn': 'জাভাস্ক্রিপ্ট',
        'image_url': 'https://picsum.photos/800/400?random=101',
        'status': 'published',
        'views': 1456,
        'completions': 823,
        'published_at': now
            .subtract(const Duration(days: 10))
            .toIso8601String(),
      },
      <String, dynamic>{
        'slug': 'implement-binary-search-algorithm',
        'title': 'Implement a Binary Search Algorithm',
        'title_bn': 'একটি বাইনারি সার্চ অ্যালগরিদম বাস্তবায়ন করুন',
        'description': 'Write an efficient binary search in a sorted array.',
        'description_bn': 'সাজানো অ্যারেতে বাইনারি সার্চ লিখুন।',
        'instructions':
            'Use iterative or recursive approach and return index or -1.',
        'instructions_bn': 'পুনরাবৃত্তি বা লুপ ব্যবহার করে সূচক ফেরত দিন।',
        'problem_statement': 'Find target in sorted list with O(log n).',
        'problem_statement_bn': 'সাজানো তালিকায় O(log n) সময়ে target খুঁজুন।',
        'input_description': 'Sorted integer list and target',
        'input_description_bn': 'সাজানো পূর্ণসংখ্যার তালিকা এবং target',
        'output_description': 'Index of target or -1',
        'output_description_bn': 'target এর সূচক অথবা -১',
        'sample_input': 'arr=[1,3,6,9], target=6',
        'sample_input_bn': 'arr=[১,৩,৬,৯], target=৬',
        'sample_output': '2',
        'sample_output_bn': '২',
        'difficulty': 'Intermediate',
        'difficulty_bn': 'মাঝারি',
        'duration': 45,
        'duration_bn': '৪৫ মিনিট',
        'category': 'Algorithms',
        'category_bn': 'অ্যালগরিদম',
        'tags': <String>['Python', 'Algorithms', 'Search'],
        'tags_bn': <String>['পাইথন', 'অ্যালগরিদম', 'সার্চ'],
        'starter_code': 'def binary_search(arr, target):\n  pass',
        'solution_code':
            'def binary_search(arr, target):\n  # solved\n  return -1',
        'programming_language': 'Python',
        'language_id': 'python',
        'language_name': 'Python',
        'language_name_bn': 'পাইথন',
        'image_url': 'https://picsum.photos/800/400?random=102',
        'status': 'published',
        'views': 2341,
        'completions': 1234,
        'published_at': now.subtract(const Duration(days: 8)).toIso8601String(),
      },
      <String, dynamic>{
        'slug': 'build-rest-api-endpoint',
        'title': 'Build a REST API Endpoint',
        'title_bn': 'একটি REST API এন্ডপয়েন্ট তৈরি করুন',
        'description': 'Create a registration endpoint with validation.',
        'description_bn': 'ভ্যালিডেশনসহ রেজিস্ট্রেশন এন্ডপয়েন্ট তৈরি করুন।',
        'instructions': 'Validate input and return proper status codes.',
        'instructions_bn': 'ইনপুট যাচাই করে সঠিক স্ট্যাটাস কোড ফেরত দিন।',
        'problem_statement': 'Build secure user registration endpoint.',
        'problem_statement_bn':
            'নিরাপদ ব্যবহারকারী রেজিস্ট্রেশন এন্ডপয়েন্ট তৈরি করুন।',
        'input_description': 'name, email, password',
        'input_description_bn': 'name, email, password',
        'output_description': 'Success response or validation errors',
        'output_description_bn': 'সফল রেসপন্স বা ভ্যালিডেশন ত্রুটি',
        'sample_input': '{"name":"A","email":"a@x.com","password":"12345678"}',
        'sample_input_bn':
            '{"name":"A","email":"a@x.com","password":"12345678"}',
        'sample_output': '{"message":"created"}',
        'sample_output_bn': '{"message":"created"}',
        'difficulty': 'Advanced',
        'difficulty_bn': 'কঠিন',
        'duration': 90,
        'duration_bn': '৯০ মিনিট',
        'category': 'Backend Development',
        'category_bn': 'ব্যাকএন্ড ডেভেলপমেন্ট',
        'tags': <String>['Node.js', 'REST API', 'Validation'],
        'tags_bn': <String>['নোড.জেএস', 'REST API', 'ভ্যালিডেশন'],
        'starter_code': 'app.post("/api/register", (req,res) => {});',
        'solution_code': '// secure endpoint implementation',
        'programming_language': 'JavaScript',
        'language_id': 'javascript',
        'language_name': 'JavaScript',
        'language_name_bn': 'জাভাস্ক্রিপ্ট',
        'image_url': 'https://picsum.photos/800/400?random=105',
        'status': 'published',
        'views': 2987,
        'completions': 1456,
        'published_at': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
    ];

    for (final data in seededExercises) {
      exercises.add(<String, dynamic>{
        'id': _exerciseId++,
        ...data,
        'created_at': now.subtract(const Duration(days: 12)).toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    }

    final seededTutorials = <Map<String, dynamic>>[
      <String, dynamic>{
        'language_id': 'javascript',
        'title': 'Introduction to JavaScript',
        'content':
            'JavaScript is a lightweight interpreted language for modern web applications.',
        'code_example': 'console.log("Hello, World!");',
        'order': 1,
        'is_published': true,
      },
      <String, dynamic>{
        'language_id': 'javascript',
        'title': 'Variables and Data Types',
        'content': 'Use let and const for modern variable declarations.',
        'code_example': 'const age = 25;\nlet name = "Alice";',
        'order': 2,
        'is_published': true,
      },
      <String, dynamic>{
        'language_id': 'python',
        'title': 'Getting Started with Python',
        'content': 'Python focuses on readability and simplicity.',
        'code_example': 'print("Hello, World!")',
        'order': 1,
        'is_published': true,
      },
      <String, dynamic>{
        'language_id': 'html',
        'title': 'HTML Basics',
        'content': 'HTML structures your content for the web.',
        'code_example': '<h1>Hello World</h1>',
        'order': 1,
        'is_published': true,
      },
      <String, dynamic>{
        'language_id': 'react',
        'title': 'Introduction to React',
        'content': 'React helps build component-driven user interfaces.',
        'code_example': 'function App(){ return <h1>Hello</h1> }',
        'order': 1,
        'is_published': true,
      },
    ];

    for (final data in seededTutorials) {
      tutorials.add(<String, dynamic>{
        'id': _tutorialId++,
        ...data,
        'created_at': now.subtract(const Duration(days: 15)).toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    }

    activities.add(<String, dynamic>{
      'id': _activityId++,
      'user_id': testUser['id'],
      'minutes_active': 90,
      'lessons_completed': 2,
      'exercises_completed': 1,
      'quizzes_completed': 1,
      'blogs_read': 2,
      'comments_posted': 0,
      'code_snippets_created': 1,
      'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      'updated_at': now.subtract(const Duration(days: 1)).toIso8601String(),
    });

    favorites.add(<String, dynamic>{
      'id': _favoriteId++,
      'user_id': testUser['id'],
      'type': 'tutorial',
      'title': 'Introduction to JavaScript',
      'description': 'Great start for newcomers',
      'url': '/tutorials/1',
      'category': 'javascript',
      'tags': <String>['intro'],
      'order': 0,
      'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
      'updated_at': now.subtract(const Duration(days: 2)).toIso8601String(),
    });
  }
}
