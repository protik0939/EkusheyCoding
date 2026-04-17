part of store;

extension InMemoryStoreAuthProfile on InMemoryStore {
  String _now() => DateTime.now().toUtc().toIso8601String();

  String hashPassword(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  String _token() {
    final b = StringBuffer();
    for (var i = 0; i < 60; i++) {
      b.write(
        InMemoryStore._tokenChars[_random.nextInt(
          InMemoryStore._tokenChars.length,
        )],
      );
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
}
