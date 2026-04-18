part of store;

extension InMemoryStorePersistence on InMemoryStore {
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

    // Create snapshots to avoid concurrent modification errors
    final userSnapshot = List<Map<String, dynamic>>.from(users);
    final blogSnapshot = List<Map<String, dynamic>>.from(blogs);
    final exerciseSnapshot = List<Map<String, dynamic>>.from(exercises);
    final tutorialSnapshot = List<Map<String, dynamic>>.from(tutorials);
    final favoriteSnapshot = List<Map<String, dynamic>>.from(favorites);
    final activitySnapshot = List<Map<String, dynamic>>.from(activities);
    final tokenSnapshot = Map<String, int>.from(tokenToUserId);

    await _db!.runTx((session) async {
      await session.execute('DELETE FROM activities');
      await session.execute('DELETE FROM favorites');
      await session.execute('DELETE FROM tutorials');
      await session.execute('DELETE FROM exercises');
      await session.execute('DELETE FROM blogs');
      await session.execute('DELETE FROM auth_tokens');
      await session.execute('DELETE FROM users');

      for (final user in userSnapshot) {
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

      for (final tokenEntry in tokenSnapshot.entries) {
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

      for (final blog in blogSnapshot) {
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

      for (final tutorial in tutorialSnapshot) {
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

      for (final exercise in exerciseSnapshot) {
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

      for (final favorite in favoriteSnapshot) {
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

      for (final activity in activitySnapshot) {
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
}
