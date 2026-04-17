import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

import '../lib/src/store.dart';

final InMemoryStore store = InMemoryStore();

Response jsonResponse(Object data, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(data),
    headers: <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
    },
  );
}

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final body = await request.readAsString();
  if (body.trim().isEmpty) {
    return <String, dynamic>{};
  }
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw const FormatException('Invalid JSON body');
}

String? bearerToken(Request request) {
  final auth = request.headers[HttpHeaders.authorizationHeader] ?? '';
  if (!auth.startsWith('Bearer ')) return null;
  return auth.substring(7).trim();
}

Future<Response> requireAuth(
  Request request,
  Future<Response> Function(Map<String, dynamic> user, String token) handler,
) async {
  final token = bearerToken(request);
  final user = store.userFromToken(token);
  if (token == null || user == null) {
    return jsonResponse(<String, dynamic>{
      'message': 'Unauthenticated',
    }, status: 401);
  }
  return handler(user, token);
}

bool isAddressInUse(SocketException error) {
  final code = error.osError?.errorCode;
  if (code == 10048 || code == 98) {
    return true;
  }

  final message = error.message.toLowerCase();
  return message.contains('address already in use') ||
      message.contains('only one usage of each socket address');
}

Future<HttpServer> serveWithPortFallback(
  Handler handler,
  InternetAddress address,
  int preferredPort, {
  int maxPortRetries = 20,
}) async {
  for (var attempt = 0; attempt < maxPortRetries; attempt++) {
    final port = preferredPort + attempt;
    try {
      if (attempt > 0) {
        print('Port ${port - 1} is busy, retrying on port $port...');
      }
      return await shelf_io.serve(handler, address, port);
    } on SocketException catch (e) {
      if (!isAddressInUse(e) || attempt == maxPortRetries - 1) {
        rethrow;
      }
    }
  }

  throw StateError('Could not start server on any fallback port.');
}

Future<Response> requireAdmin(
  Request request,
  Future<Response> Function(Map<String, dynamic> user, String token) handler,
) async {
  return requireAuth(request, (user, token) async {
    if (!store.isAdmin(user)) {
      return jsonResponse(<String, dynamic>{
        'message': 'Unauthorized. Admin access required.',
      }, status: 403);
    }
    return handler(user, token);
  });
}

String slugify(String value) {
  var output = value.toLowerCase().trim();
  output = output.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
  output = output.replaceAll(RegExp(r'\s+'), '-');
  output = output.replaceAll(RegExp(r'-+'), '-');
  return output;
}

void sortByField(List<Map<String, dynamic>> list, String field, String order) {
  final desc = order.toLowerCase() == 'desc';
  list.sort((a, b) {
    final av = a[field];
    final bv = b[field];

    int cmp;
    if (av is num && bv is num) {
      cmp = av.compareTo(bv);
    } else {
      cmp = '${av ?? ''}'.compareTo('${bv ?? ''}');
    }

    return desc ? -cmp : cmp;
  });
}

bool isPublished(Map<String, dynamic> item) {
  if ('${item['status']}' != 'published') return false;
  final publishedAt = item['published_at'];
  if (publishedAt == null) return false;
  final dt = DateTime.tryParse('$publishedAt');
  if (dt == null) return false;
  return !dt.isAfter(DateTime.now().toUtc());
}

bool _shouldPersistRequest(Request request) {
  const writeMethods = <String>{'POST', 'PUT', 'PATCH', 'DELETE'};
  if (writeMethods.contains(request.method.toUpperCase())) {
    return true;
  }

  // View counters are incremented in these read endpoints.
  if (request.method.toUpperCase() == 'GET') {
    final path = request.url.path;
    final blogDetailMatch = RegExp(r'^api/blogs/[^/]+$').hasMatch(path);
    final exerciseDetailMatch = RegExp(r'^api/exercises/[^/]+$').hasMatch(path);
    return blogDetailMatch || exerciseDetailMatch;
  }

  return false;
}

Middleware persistStateMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      if (_shouldPersistRequest(request) && response.statusCode < 500) {
        try {
          await store.persistState();
        } catch (error) {
          stderr.writeln('Failed to persist state: $error');
        }
      }
      return response;
    };
  };
}

Future<void> main(List<String> args) async {
  await store.initializePersistence();
  if (store.isPersistenceEnabled) {
    print(store.persistenceStatus);
  } else {
    stderr.writeln(store.persistenceStatus);
  }

  final router = Router();

  router.get('/api/health', (Request request) {
    return jsonResponse(<String, dynamic>{
      'service': 'dart-backend-w3university',
      'status': 'ok',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  });

  router.post('/api/register', (Request request) async {
    try {
      final body = await readJsonBody(request);
      final name = '${body['name'] ?? ''}'.trim();
      final email = '${body['email'] ?? ''}'.trim();
      final password = '${body['password'] ?? ''}';
      final confirm = '${body['password_confirmation'] ?? ''}';

      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        return jsonResponse(<String, dynamic>{
          'message': 'name, email and password are required',
        }, status: 422);
      }
      if (!email.contains('@')) {
        return jsonResponse(<String, dynamic>{
          'message': 'email must be valid',
        }, status: 422);
      }
      if (password.length < 8) {
        return jsonResponse(<String, dynamic>{
          'message': 'password must be at least 8 characters',
        }, status: 422);
      }
      if (password != confirm) {
        return jsonResponse(<String, dynamic>{
          'message': 'password confirmation does not match',
        }, status: 422);
      }

      final response = store.register(
        name: name,
        email: email,
        password: password,
      );
      return jsonResponse(response, status: 201);
    } on StateError catch (e) {
      return jsonResponse(<String, dynamic>{'message': e.message}, status: 422);
    } catch (_) {
      return jsonResponse(<String, dynamic>{
        'message': 'Invalid request body',
      }, status: 400);
    }
  });

  router.post('/api/login', (Request request) async {
    try {
      final body = await readJsonBody(request);
      final email = '${body['email'] ?? ''}'.trim();
      final password = '${body['password'] ?? ''}';
      if (email.isEmpty || password.isEmpty) {
        return jsonResponse(<String, dynamic>{
          'message': 'email and password are required',
        }, status: 422);
      }

      final response = store.login(email: email, password: password);
      return jsonResponse(response);
    } on StateError catch (e) {
      return jsonResponse(<String, dynamic>{'message': e.message}, status: 422);
    } catch (_) {
      return jsonResponse(<String, dynamic>{
        'message': 'Invalid request body',
      }, status: 400);
    }
  });

  router.get('/api/blogs', (Request request) {
    final q = request.url.queryParameters;
    final status = q['status'];
    final category = q['category'];
    final search = (q['search'] ?? '').toLowerCase();
    final sortBy = q['sort_by'] ?? 'published_at';
    final sortOrder = q['sort_order'] ?? 'desc';
    final page = int.tryParse(q['page'] ?? '1') ?? 1;
    final perPage = int.tryParse(q['per_page'] ?? '10') ?? 10;

    var items = List<Map<String, dynamic>>.from(store.blogs);
    if (status == null || status.isEmpty) {
      items = items.where(isPublished).toList();
    } else {
      items = items.where((b) => '${b['status']}' == status).toList();
    }

    if (category != null && category.isNotEmpty) {
      items = items.where((b) => '${b['category']}' == category).toList();
    }

    if (search.isNotEmpty) {
      items = items.where((b) {
        final title = '${b['title']}'.toLowerCase();
        final titleBn = '${b['title_bn']}'.toLowerCase();
        return title.contains(search) || titleBn.contains(search);
      }).toList();
    }

    sortByField(items, sortBy, sortOrder);
    return jsonResponse(store.paginate(items, page: page, perPage: perPage));
  });

  router.get('/api/blogs/categories', (Request request) {
    final categories = <String, Map<String, dynamic>>{};
    for (final b in store.blogs.where(isPublished)) {
      categories['${b['category']}'] = <String, dynamic>{
        'category': b['category'],
        'category_bn': b['category_bn'],
      };
    }
    return jsonResponse(categories.values.toList());
  });

  router.get('/api/blogs/popular', (Request request) {
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '5') ?? 5;
    final items = List<Map<String, dynamic>>.from(
      store.blogs.where(isPublished),
    );
    sortByField(items, 'views', 'desc');
    return jsonResponse(items.take(limit).toList());
  });

  router.get('/api/blogs/recent', (Request request) {
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '5') ?? 5;
    final items = List<Map<String, dynamic>>.from(
      store.blogs.where(isPublished),
    );
    sortByField(items, 'published_at', 'desc');
    return jsonResponse(items.take(limit).toList());
  });

  router.get('/api/blogs/<slug>', (Request request, String slug) {
    final index = store.blogs.indexWhere((b) => '${b['slug']}' == slug);
    if (index == -1) {
      return jsonResponse(<String, dynamic>{
        'message': 'Blog not found',
      }, status: 404);
    }

    store.blogs[index]['views'] =
        ((store.blogs[index]['views'] as int?) ?? 0) + 1;
    return jsonResponse(store.blogs[index]);
  });

  router.get('/api/tutorials', (Request request) {
    final q = request.url.queryParameters;
    final languageId = q['language_id'];
    final hasPublished = q.containsKey('is_published');
    final isPublishedOnly =
        q['is_published'] == 'true' || q['is_published'] == '1';
    final search = (q['search'] ?? '').toLowerCase();

    var items = List<Map<String, dynamic>>.from(store.tutorials);

    if (languageId != null && languageId.isNotEmpty) {
      items = items.where((t) => '${t['language_id']}' == languageId).toList();
    }

    if (hasPublished) {
      items = items
          .where((t) => (t['is_published'] == true) == isPublishedOnly)
          .toList();
    } else {
      items = items.where((t) => t['is_published'] == true).toList();
    }

    if (search.isNotEmpty) {
      items = items
          .where((t) => '${t['title']}'.toLowerCase().contains(search))
          .toList();
    }

    sortByField(items, 'order', 'asc');

    final perPage = int.tryParse(q['per_page'] ?? '') ?? 0;
    if (perPage > 0) {
      final page = int.tryParse(q['page'] ?? '1') ?? 1;
      return jsonResponse(store.paginate(items, page: page, perPage: perPage));
    }

    return jsonResponse(items);
  });

  router.get('/api/tutorials/languages', (Request request) {
    final set = <String>{};
    for (final t in store.tutorials.where((t) => t['is_published'] == true)) {
      set.add('${t['language_id']}');
    }
    return jsonResponse(set.toList());
  });

  router.get('/api/tutorials/<id>', (Request request, String id) {
    final tutorialId = int.tryParse(id);
    if (tutorialId == null) {
      return jsonResponse(<String, dynamic>{
        'message': 'Invalid tutorial id',
      }, status: 400);
    }
    final index = store.tutorials.indexWhere((t) => t['id'] == tutorialId);
    if (index == -1) {
      return jsonResponse(<String, dynamic>{
        'message': 'Tutorial not found',
      }, status: 404);
    }
    return jsonResponse(store.tutorials[index]);
  });

  router.get('/api/exercises', (Request request) {
    final q = request.url.queryParameters;
    final status = q['status'];
    final category = q['category'];
    final difficulty = q['difficulty'];
    final languageId = q['language_id'];
    final search = (q['search'] ?? '').toLowerCase();
    final sortBy = q['sort_by'] ?? 'published_at';
    final sortOrder = q['sort_order'] ?? 'desc';
    final page = int.tryParse(q['page'] ?? '1') ?? 1;
    final perPage = int.tryParse(q['per_page'] ?? '10') ?? 10;

    var items = List<Map<String, dynamic>>.from(store.exercises);
    if (status == null || status.isEmpty) {
      items = items.where(isPublished).toList();
    } else {
      items = items.where((e) => '${e['status']}' == status).toList();
    }

    if (category != null && category.isNotEmpty) {
      items = items.where((e) => '${e['category']}' == category).toList();
    }

    if (difficulty != null && difficulty.isNotEmpty) {
      items = items
          .where(
            (e) =>
                '${e['difficulty']}'.toLowerCase() == difficulty.toLowerCase(),
          )
          .toList();
    }

    if (languageId != null && languageId.isNotEmpty) {
      items = items.where((e) => '${e['language_id']}' == languageId).toList();
    }

    if (search.isNotEmpty) {
      items = items.where((e) {
        final title = '${e['title']}'.toLowerCase();
        final titleBn = '${e['title_bn']}'.toLowerCase();
        return title.contains(search) || titleBn.contains(search);
      }).toList();
    }

    sortByField(items, sortBy, sortOrder);
    return jsonResponse(store.paginate(items, page: page, perPage: perPage));
  });

  router.get('/api/exercises/categories', (Request request) {
    final categories = <String, Map<String, dynamic>>{};
    for (final e in store.exercises.where(isPublished)) {
      categories['${e['category']}'] = <String, dynamic>{
        'category': e['category'],
        'category_bn': e['category_bn'],
      };
    }
    return jsonResponse(categories.values.toList());
  });

  router.get('/api/exercises/popular', (Request request) {
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '5') ?? 5;
    final items = List<Map<String, dynamic>>.from(
      store.exercises.where(isPublished),
    );
    sortByField(items, 'views', 'desc');
    return jsonResponse(items.take(limit).toList());
  });

  router.get('/api/exercises/recent', (Request request) {
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '5') ?? 5;
    final items = List<Map<String, dynamic>>.from(
      store.exercises.where(isPublished),
    );
    sortByField(items, 'published_at', 'desc');
    return jsonResponse(items.take(limit).toList());
  });

  router.get('/api/exercises/difficulty/<difficulty>', (
    Request request,
    String difficulty,
  ) {
    final perPage =
        int.tryParse(request.url.queryParameters['per_page'] ?? '10') ?? 10;
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;

    final items = List<Map<String, dynamic>>.from(
      store.exercises.where(
        (e) =>
            isPublished(e) &&
            '${e['difficulty']}'.toLowerCase() == difficulty.toLowerCase(),
      ),
    );

    sortByField(items, 'published_at', 'desc');
    return jsonResponse(store.paginate(items, page: page, perPage: perPage));
  });

  router.get('/api/exercises/<slug>', (Request request, String slug) {
    final index = store.exercises.indexWhere((e) => '${e['slug']}' == slug);
    if (index == -1) {
      return jsonResponse(<String, dynamic>{
        'message': 'Exercise not found',
      }, status: 404);
    }

    store.exercises[index]['views'] =
        ((store.exercises[index]['views'] as int?) ?? 0) + 1;
    return jsonResponse(store.exercises[index]);
  });

  router.get('/api/user', (Request request) {
    return requireAuth(
      request,
      (user, _) async => jsonResponse(store.profilePayload(user)),
    );
  });

  router.get('/api/profile', (Request request) {
    return requireAuth(
      request,
      (user, _) async => jsonResponse(store.profilePayload(user)),
    );
  });

  router.post('/api/logout', (Request request) {
    return requireAuth(request, (user, token) async {
      store.logout(token);
      user['api_token_hash'] = null;
      user['updated_at'] = DateTime.now().toUtc().toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Logged out successfully',
      });
    });
  });

  router.put('/api/profile/basic-info', (Request request) {
    return requireAuth(request, (user, _) async {
      final body = await readJsonBody(request);
      final name = body['name'];
      final email = body['email'];

      if (name != null) {
        user['name'] = '$name';
      }

      if (email != null) {
        final emailStr = '$email'.trim();
        final taken = store.users.any(
          (u) =>
              u['id'] != user['id'] &&
              '${u['email']}'.toLowerCase() == emailStr.toLowerCase(),
        );
        if (taken) {
          return jsonResponse(<String, dynamic>{
            'message': 'Email already taken',
          }, status: 422);
        }
        user['email'] = emailStr;
      }

      user['updated_at'] = DateTime.now().toUtc().toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Profile updated successfully',
        'user': store.sanitizeUser(user),
      });
    });
  });

  router.put('/api/profile/details', (Request request) {
    return requireAuth(request, (user, _) async {
      final body = await readJsonBody(request);
      const allowed = <String>{
        'username',
        'phone',
        'bio',
        'github_url',
        'linkedin_url',
        'twitter_url',
        'portfolio_url',
        'location',
        'timezone',
        'date_of_birth',
        'skill_level',
        'programming_languages',
        'interests',
        'daily_goal_minutes',
        'email_notifications',
        'is_public',
      };

      for (final entry in body.entries) {
        if (allowed.contains(entry.key)) {
          user[entry.key] = entry.value;
        }
      }

      user['updated_at'] = DateTime.now().toUtc().toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Profile details updated successfully',
        'user': store.sanitizeUser(user),
      });
    });
  });

  router.post('/api/profile/change-password', (Request request) {
    return requireAuth(request, (user, _) async {
      final body = await readJsonBody(request);
      final current = '${body['current_password'] ?? ''}';
      final next = '${body['new_password'] ?? ''}';
      final confirm = '${body['new_password_confirmation'] ?? ''}';

      if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
        return jsonResponse(<String, dynamic>{
          'message': 'All password fields are required',
        }, status: 422);
      }
      if (next.length < 8) {
        return jsonResponse(<String, dynamic>{
          'message': 'new_password must be at least 8 characters',
        }, status: 422);
      }
      if (next != confirm) {
        return jsonResponse(<String, dynamic>{
          'message': 'new_password confirmation does not match',
        }, status: 422);
      }
      if (user['password_hash'] != store.hashPassword(current)) {
        return jsonResponse(<String, dynamic>{
          'message': 'The current password is incorrect.',
        }, status: 422);
      }

      user['password_hash'] = store.hashPassword(next);
      user['updated_at'] = DateTime.now().toUtc().toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Password changed successfully',
      });
    });
  });

  router.get('/api/profile/favorites', (Request request) {
    return requireAuth(request, (user, _) async {
      final type = request.url.queryParameters['type'];
      var list = store.favorites.where((f) => f['user_id'] == user['id']);
      if (type != null && type.isNotEmpty) {
        list = list.where((f) => '${f['type']}' == type);
      }
      final output = list.toList();
      sortByField(output, 'order', 'asc');
      return jsonResponse(output);
    });
  });

  router.post('/api/profile/favorites', (Request request) {
    return requireAuth(request, (user, _) async {
      final body = await readJsonBody(request);
      final type = '${body['type'] ?? ''}';
      final title = '${body['title'] ?? ''}';
      if (type.isEmpty || title.isEmpty) {
        return jsonResponse(<String, dynamic>{
          'message': 'type and title are required',
        }, status: 422);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final favorite = <String, dynamic>{
        'id': store.nextFavoriteId(),
        'user_id': user['id'],
        'type': type,
        'title': title,
        'description': body['description'],
        'url': body['url'],
        'category': body['category'],
        'tags': body['tags'] ?? <String>[],
        'order': (body['order'] as num?)?.toInt() ?? 0,
        'created_at': now,
        'updated_at': now,
      };
      store.favorites.add(favorite);
      return jsonResponse(<String, dynamic>{
        'message': 'Favorite added successfully',
        'favorite': favorite,
      }, status: 201);
    });
  });

  router.put('/api/profile/favorites/<id>', (Request request, String id) {
    return requireAuth(request, (user, _) async {
      final favId = int.tryParse(id);
      if (favId == null) {
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid favorite id',
        }, status: 400);
      }
      final index = store.favorites.indexWhere(
        (f) => f['id'] == favId && f['user_id'] == user['id'],
      );
      if (index == -1) {
        return jsonResponse(<String, dynamic>{
          'message': 'Favorite not found',
        }, status: 404);
      }

      final body = await readJsonBody(request);
      for (final entry in body.entries) {
        store.favorites[index][entry.key] = entry.value;
      }
      store.favorites[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Favorite updated successfully',
        'favorite': store.favorites[index],
      });
    });
  });

  router.delete('/api/profile/favorites/<id>', (Request request, String id) {
    return requireAuth(request, (user, _) async {
      final favId = int.tryParse(id);
      if (favId == null) {
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid favorite id',
        }, status: 400);
      }
      store.favorites.removeWhere(
        (f) => f['id'] == favId && f['user_id'] == user['id'],
      );
      return jsonResponse(<String, dynamic>{
        'message': 'Favorite deleted successfully',
      });
    });
  });

  router.post('/api/profile/activity', (Request request) {
    return requireAuth(request, (user, _) async {
      final body = await readJsonBody(request);
      final minutes = (body['minutes_active'] as num?)?.toInt() ?? 0;
      if (minutes < 0) {
        return jsonResponse(<String, dynamic>{
          'message': 'minutes_active must be >= 0',
        }, status: 422);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final activity = <String, dynamic>{
        'id': store.nextActivityId(),
        'user_id': user['id'],
        'minutes_active': minutes,
        'lessons_completed': (body['lessons_completed'] as num?)?.toInt() ?? 0,
        'exercises_completed':
            (body['exercises_completed'] as num?)?.toInt() ?? 0,
        'quizzes_completed': (body['quizzes_completed'] as num?)?.toInt() ?? 0,
        'blogs_read': (body['blogs_read'] as num?)?.toInt() ?? 0,
        'comments_posted': (body['comments_posted'] as num?)?.toInt() ?? 0,
        'code_snippets_created':
            (body['code_snippets_created'] as num?)?.toInt() ?? 0,
        'created_at': now,
        'updated_at': now,
      };
      store.activities.add(activity);
      return jsonResponse(<String, dynamic>{
        'message': 'Activity tracked successfully',
        'activity': activity,
      }, status: 201);
    });
  });

  router.get('/api/profile/activity/history', (Request request) {
    return requireAuth(request, (user, _) async {
      final days =
          int.tryParse(request.url.queryParameters['days'] ?? '30') ?? 30;
      final since = DateTime.now().toUtc().subtract(Duration(days: days));
      final list = store.activities.where((a) {
        if (a['user_id'] != user['id']) return false;
        final dt = DateTime.tryParse('${a['created_at']}');
        return dt != null && !dt.isBefore(since);
      }).toList();
      sortByField(list, 'created_at', 'desc');
      return jsonResponse(list);
    });
  });

  router.get('/api/profile/performance', (Request request) {
    return requireAuth(request, (user, _) async {
      final mine = store.activities.where((a) => a['user_id'] == user['id']);
      final stats = <String, dynamic>{
        'total_minutes': mine.fold<int>(
          0,
          (acc, a) => acc + ((a['minutes_active'] as int?) ?? 0),
        ),
        'total_lessons': mine.fold<int>(
          0,
          (acc, a) => acc + ((a['lessons_completed'] as int?) ?? 0),
        ),
        'total_exercises': mine.fold<int>(
          0,
          (acc, a) => acc + ((a['exercises_completed'] as int?) ?? 0),
        ),
        'total_quizzes': mine.fold<int>(
          0,
          (acc, a) => acc + ((a['quizzes_completed'] as int?) ?? 0),
        ),
        'badges': user['badges'] ?? <String>[],
        'current_streak': user['current_streak'] ?? 0,
        'longest_streak': user['longest_streak'] ?? 0,
      };
      return jsonResponse(stats);
    });
  });

  router.post('/api/profile/badge', (Request request) {
    return requireAuth(request, (user, _) async {
      final body = await readJsonBody(request);
      final badge = '${body['badge'] ?? ''}'.trim();
      if (badge.isEmpty) {
        return jsonResponse(<String, dynamic>{
          'message': 'badge is required',
        }, status: 422);
      }
      final badges = List<String>.from(
        user['badges'] as List<dynamic>? ?? <dynamic>[],
      );
      if (!badges.contains(badge)) {
        badges.add(badge);
      }
      user['badges'] = badges;
      user['updated_at'] = DateTime.now().toUtc().toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Badge awarded successfully',
        'badges': badges,
      });
    });
  });

  router.post('/api/blogs', (Request request) {
    return requireAuth(request, (user, _) async {
      final body = await readJsonBody(request);
      final title = '${body['title'] ?? ''}'.trim();
      if (title.isEmpty) {
        return jsonResponse(<String, dynamic>{
          'message': 'title is required',
        }, status: 422);
      }

      var slug = '${body['slug'] ?? ''}'.trim();
      if (slug.isEmpty) slug = slugify(title);
      final original = slug;
      var c = 1;
      while (store.blogs.any((b) => '${b['slug']}' == slug)) {
        slug = '$original-$c';
        c++;
      }

      final status = '${body['status'] ?? 'draft'}';
      final now = DateTime.now().toUtc().toIso8601String();
      final blog = <String, dynamic>{
        'id': store.nextBlogId(),
        'title': title,
        'title_bn': '${body['title_bn'] ?? title}',
        'excerpt': '${body['excerpt'] ?? ''}',
        'excerpt_bn': '${body['excerpt_bn'] ?? ''}',
        'content': '${body['content'] ?? ''}',
        'content_bn': '${body['content_bn'] ?? ''}',
        'author': '${body['author'] ?? user['name']}',
        'author_bn': '${body['author_bn'] ?? user['name']}',
        'author_id': user['id'],
        'category': '${body['category'] ?? 'General'}',
        'category_bn':
            '${body['category_bn'] ?? body['category'] ?? 'General'}',
        'tags': body['tags'] ?? <String>[],
        'tags_bn': body['tags_bn'] ?? body['tags'] ?? <String>[],
        'read_time': '${body['read_time'] ?? '5 min read'}',
        'read_time_bn': '${body['read_time_bn'] ?? '৫ মিনিট পড়ুন'}',
        'image_url': body['image_url'],
        'featured_image': body['featured_image'],
        'slug': slug,
        'status': status,
        'views': 0,
        'published_at': status == 'published'
            ? (body['published_at'] ?? now)
            : body['published_at'],
        'created_at': now,
        'updated_at': now,
      };

      store.blogs.add(blog);
      return jsonResponse(<String, dynamic>{
        'message': 'Blog created successfully',
        'blog': blog,
      }, status: 201);
    });
  });

  router.put('/api/blogs/<slug>', (Request request, String slug) {
    return requireAuth(request, (user, _) async {
      final index = store.blogs.indexWhere((b) => '${b['slug']}' == slug);
      if (index == -1) {
        return jsonResponse(<String, dynamic>{
          'message': 'Blog not found',
        }, status: 404);
      }
      final body = await readJsonBody(request);
      for (final entry in body.entries) {
        store.blogs[index][entry.key] = entry.value;
      }
      if (body.containsKey('status') &&
          '${body['status']}' == 'published' &&
          store.blogs[index]['published_at'] == null) {
        store.blogs[index]['published_at'] = DateTime.now()
            .toUtc()
            .toIso8601String();
      }
      store.blogs[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Blog updated successfully',
        'blog': store.blogs[index],
      });
    });
  });

  router.delete('/api/blogs/<slug>', (Request request, String slug) {
    return requireAuth(request, (user, _) async {
      store.blogs.removeWhere((b) => '${b['slug']}' == slug);
      return jsonResponse(<String, dynamic>{
        'message': 'Blog deleted successfully',
      });
    });
  });

  router.post('/api/exercises', (Request request) {
    return requireAuth(request, (user, _) async {
      final body = await readJsonBody(request);
      final title = '${body['title'] ?? ''}'.trim();
      final difficulty = '${body['difficulty'] ?? ''}'.trim();
      if (title.isEmpty || difficulty.isEmpty) {
        return jsonResponse(<String, dynamic>{
          'message': 'title and difficulty are required',
        }, status: 422);
      }

      var slug = '${body['slug'] ?? ''}'.trim();
      if (slug.isEmpty) slug = slugify(title);
      final original = slug;
      var c = 1;
      while (store.exercises.any((e) => '${e['slug']}' == slug)) {
        slug = '$original-$c';
        c++;
      }

      final status = '${body['status'] ?? 'draft'}';
      final now = DateTime.now().toUtc().toIso8601String();
      final exercise = <String, dynamic>{
        'id': store.nextExerciseId(),
        'title': title,
        'title_bn': '${body['title_bn'] ?? ''}',
        'description': body['description'],
        'description_bn': body['description_bn'],
        'instructions': body['instructions'],
        'instructions_bn': body['instructions_bn'],
        'problem_statement': '${body['problem_statement'] ?? ''}',
        'problem_statement_bn': '${body['problem_statement_bn'] ?? ''}',
        'input_description': '${body['input_description'] ?? ''}',
        'input_description_bn': '${body['input_description_bn'] ?? ''}',
        'output_description': '${body['output_description'] ?? ''}',
        'output_description_bn': '${body['output_description_bn'] ?? ''}',
        'sample_input': '${body['sample_input'] ?? ''}',
        'sample_input_bn': '${body['sample_input_bn'] ?? ''}',
        'sample_output': '${body['sample_output'] ?? ''}',
        'sample_output_bn': '${body['sample_output_bn'] ?? ''}',
        'difficulty': difficulty,
        'difficulty_bn': '${body['difficulty_bn'] ?? ''}',
        'duration': body['duration'],
        'duration_bn': body['duration_bn'],
        'category': body['category'],
        'category_bn': body['category_bn'],
        'tags': body['tags'] ?? <String>[],
        'tags_bn': body['tags_bn'] ?? body['tags'] ?? <String>[],
        'starter_code': body['starter_code'],
        'solution_code': body['solution_code'],
        'programming_language': body['programming_language'],
        'language_id': body['language_id'],
        'language_name': body['language_name'],
        'language_name_bn': body['language_name_bn'],
        'image_url': body['image_url'],
        'slug': slug,
        'status': status,
        'views': 0,
        'completions': 0,
        'published_at': status == 'published'
            ? (body['published_at'] ?? now)
            : body['published_at'],
        'created_at': now,
        'updated_at': now,
      };

      store.exercises.add(exercise);
      return jsonResponse(<String, dynamic>{
        'message': 'Exercise created successfully',
        'exercise': exercise,
      }, status: 201);
    });
  });

  router.put('/api/exercises/<slug>', (Request request, String slug) {
    return requireAuth(request, (user, _) async {
      final index = store.exercises.indexWhere((e) => '${e['slug']}' == slug);
      if (index == -1) {
        return jsonResponse(<String, dynamic>{
          'message': 'Exercise not found',
        }, status: 404);
      }
      final body = await readJsonBody(request);
      for (final entry in body.entries) {
        store.exercises[index][entry.key] = entry.value;
      }
      if (body.containsKey('status') &&
          '${body['status']}' == 'published' &&
          store.exercises[index]['published_at'] == null) {
        store.exercises[index]['published_at'] = DateTime.now()
            .toUtc()
            .toIso8601String();
      }
      store.exercises[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Exercise updated successfully',
        'exercise': store.exercises[index],
      });
    });
  });

  router.delete('/api/exercises/<slug>', (Request request, String slug) {
    return requireAuth(request, (user, _) async {
      store.exercises.removeWhere((e) => '${e['slug']}' == slug);
      return jsonResponse(<String, dynamic>{
        'message': 'Exercise deleted successfully',
      });
    });
  });

  router.post('/api/exercises/<slug>/complete', (Request request, String slug) {
    return requireAuth(request, (user, _) async {
      final index = store.exercises.indexWhere((e) => '${e['slug']}' == slug);
      if (index == -1) {
        return jsonResponse(<String, dynamic>{
          'message': 'Exercise not found',
        }, status: 404);
      }
      store.exercises[index]['completions'] =
          ((store.exercises[index]['completions'] as int?) ?? 0) + 1;
      return jsonResponse(<String, dynamic>{
        'message': 'Exercise marked as completed',
        'completions': store.exercises[index]['completions'],
      });
    });
  });

  router.get('/api/admin/blogs', (Request request) {
    return requireAdmin(request, (user, token) async {
      final q = request.url.queryParameters;
      final search = (q['search'] ?? '').toLowerCase();
      final status = q['status'];
      final category = q['category'];
      final authorId = int.tryParse(q['author_id'] ?? '');
      final sortBy = q['sort_by'] ?? 'created_at';
      final sortOrder = q['sort_order'] ?? 'desc';
      final page = int.tryParse(q['page'] ?? '1') ?? 1;
      final perPage = int.tryParse(q['per_page'] ?? '15') ?? 15;

      var items = List<Map<String, dynamic>>.from(store.blogs);

      if (search.isNotEmpty) {
        items = items.where((b) {
          final title = '${b['title']}'.toLowerCase();
          final titleBn = '${b['title_bn']}'.toLowerCase();
          final content = '${b['content']}'.toLowerCase();
          final contentBn = '${b['content_bn']}'.toLowerCase();
          return title.contains(search) ||
              titleBn.contains(search) ||
              content.contains(search) ||
              contentBn.contains(search);
        }).toList();
      }

      if (status != null && status.isNotEmpty) {
        items = items.where((b) => '${b['status']}' == status).toList();
      }

      if (category != null && category.isNotEmpty) {
        items = items.where((b) => '${b['category']}' == category).toList();
      }

      if (authorId != null) {
        items = items.where((b) => b['author_id'] == authorId).toList();
      }

      sortByField(items, sortBy, sortOrder);
      return jsonResponse(store.paginate(items, page: page, perPage: perPage));
    });
  });

  router.get('/api/admin/blogs/stats', (Request request) {
    return requireAdmin(request, (user, token) async {
      final totalBlogs = store.blogs.length;
      final publishedBlogs = store.blogs
          .where((b) => '${b['status']}' == 'published')
          .length;
      final draftBlogs = store.blogs
          .where((b) => '${b['status']}' == 'draft')
          .length;
      final totalViews = store.blogs.fold<int>(
        0,
        (acc, b) => acc + ((b['views'] as int?) ?? 0),
      );

      final recent = List<Map<String, dynamic>>.from(store.blogs);
      sortByField(recent, 'created_at', 'desc');

      final categories = <String, int>{};
      for (final b in store.blogs) {
        final key = '${b['category']}';
        categories[key] = (categories[key] ?? 0) + 1;
      }

      final popularCategories =
          categories.entries
              .map(
                (e) => <String, dynamic>{'category': e.key, 'count': e.value},
              )
              .toList()
            ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return jsonResponse(<String, dynamic>{
        'total_blogs': totalBlogs,
        'published_blogs': publishedBlogs,
        'draft_blogs': draftBlogs,
        'total_views': totalViews,
        'total_categories': categories.length,
        'recent_blogs': recent.take(5).toList(),
        'popular_categories': popularCategories.take(6).toList(),
      });
    });
  });

  router.get('/api/admin/blogs/<id>', (Request request, String id) {
    return requireAdmin(request, (user, token) async {
      final blogId = int.tryParse(id);
      if (blogId == null) {
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      final index = store.blogs.indexWhere((b) => b['id'] == blogId);
      if (index == -1) {
        return jsonResponse(<String, dynamic>{
          'message': 'Blog not found',
        }, status: 404);
      }
      return jsonResponse(store.blogs[index]);
    });
  });

  router.post('/api/admin/blogs', (Request request) {
    return requireAdmin(request, (user, token) async {
      final proxy = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/api/blogs'),
          headers: request.headers,
          body: await request.readAsString(),
        ),
      );
      return proxy;
    });
  });

  router.put('/api/admin/blogs/<id>', (Request request, String id) {
    return requireAdmin(request, (user, token) async {
      final blogId = int.tryParse(id);
      if (blogId == null)
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      final index = store.blogs.indexWhere((b) => b['id'] == blogId);
      if (index == -1)
        return jsonResponse(<String, dynamic>{
          'message': 'Blog not found',
        }, status: 404);

      final body = await readJsonBody(request);
      for (final entry in body.entries) {
        store.blogs[index][entry.key] = entry.value;
      }
      if (body.containsKey('title')) {
        var slug = slugify('${body['title']}');
        final original = slug;
        var c = 1;
        while (store.blogs.any(
          (b) => b['id'] != blogId && '${b['slug']}' == slug,
        )) {
          slug = '$original-$c';
          c++;
        }
        store.blogs[index]['slug'] = slug;
      }
      if (body.containsKey('status') &&
          '${body['status']}' == 'published' &&
          store.blogs[index]['published_at'] == null) {
        store.blogs[index]['published_at'] = DateTime.now()
            .toUtc()
            .toIso8601String();
      }
      store.blogs[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Blog updated successfully',
        'blog': store.blogs[index],
      });
    });
  });

  router.delete('/api/admin/blogs/<id>', (Request request, String id) {
    return requireAdmin(request, (user, token) async {
      final blogId = int.tryParse(id);
      if (blogId == null)
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      store.blogs.removeWhere((b) => b['id'] == blogId);
      return jsonResponse(<String, dynamic>{
        'message': 'Blog deleted successfully',
      });
    });
  });

  router.post('/api/admin/blogs/bulk-delete', (Request request) {
    return requireAdmin(request, (user, token) async {
      final body = await readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      final before = store.blogs.length;
      store.blogs.removeWhere((b) => ids.contains(b['id']));
      final deleted = before - store.blogs.length;
      return jsonResponse(<String, dynamic>{
        'message': '$deleted blogs deleted successfully',
        'deleted_count': deleted,
      });
    });
  });

  router.post('/api/admin/blogs/bulk-update-status', (Request request) {
    return requireAdmin(request, (user, token) async {
      final body = await readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      final status = '${body['status'] ?? ''}';
      var updated = 0;
      for (final b in store.blogs) {
        if (ids.contains(b['id'])) {
          b['status'] = status;
          if (status == 'published' && b['published_at'] == null) {
            b['published_at'] = DateTime.now().toUtc().toIso8601String();
          }
          b['updated_at'] = DateTime.now().toUtc().toIso8601String();
          updated++;
        }
      }
      return jsonResponse(<String, dynamic>{
        'message': '$updated blogs updated successfully',
        'updated_count': updated,
      });
    });
  });

  router.get('/api/admin/exercises', (Request request) {
    return requireAdmin(request, (user, token) async {
      final q = request.url.queryParameters;
      final search = (q['search'] ?? '').toLowerCase();
      final status = q['status'];
      final difficulty = q['difficulty'];
      final languageId = q['language_id'];
      final category = q['category'];
      final sortBy = q['sort_by'] ?? 'created_at';
      final sortOrder = q['sort_order'] ?? 'desc';
      final page = int.tryParse(q['page'] ?? '1') ?? 1;
      final perPage = int.tryParse(q['per_page'] ?? '15') ?? 15;

      var items = List<Map<String, dynamic>>.from(store.exercises);
      if (search.isNotEmpty) {
        items = items.where((e) {
          final fields = <String>[
            '${e['title']}',
            '${e['title_bn']}',
            '${e['description']}',
            '${e['problem_statement']}',
          ];
          return fields.any((f) => f.toLowerCase().contains(search));
        }).toList();
      }

      if (status != null && status.isNotEmpty && status != 'all') {
        items = items.where((e) => '${e['status']}' == status).toList();
      }
      if (difficulty != null && difficulty.isNotEmpty) {
        items = items.where((e) => '${e['difficulty']}' == difficulty).toList();
      }
      if (languageId != null && languageId.isNotEmpty) {
        items = items
            .where((e) => '${e['language_id']}' == languageId)
            .toList();
      }
      if (category != null && category.isNotEmpty) {
        items = items.where((e) => '${e['category']}' == category).toList();
      }

      sortByField(items, sortBy, sortOrder);
      return jsonResponse(store.paginate(items, page: page, perPage: perPage));
    });
  });

  router.get('/api/admin/exercises/stats', (Request request) {
    return requireAdmin(request, (user, token) async {
      final total = store.exercises.length;
      final published = store.exercises
          .where((e) => '${e['status']}' == 'published')
          .length;
      final drafts = store.exercises
          .where((e) => '${e['status']}' == 'draft')
          .length;
      final archived = store.exercises
          .where((e) => '${e['status']}' == 'archived')
          .length;
      final totalViews = store.exercises.fold<int>(
        0,
        (acc, e) => acc + ((e['views'] as int?) ?? 0),
      );
      final totalCompletions = store.exercises.fold<int>(
        0,
        (acc, e) => acc + ((e['completions'] as int?) ?? 0),
      );

      final byLanguage = <String, int>{};
      for (final e in store.exercises) {
        final key = '${e['language_name'] ?? ''}';
        if (key.isEmpty) continue;
        byLanguage[key] = (byLanguage[key] ?? 0) + 1;
      }

      final recent = List<Map<String, dynamic>>.from(store.exercises);
      sortByField(recent, 'created_at', 'desc');

      return jsonResponse(<String, dynamic>{
        'total': total,
        'published': published,
        'drafts': drafts,
        'archived': archived,
        'total_views': totalViews,
        'total_completions': totalCompletions,
        'by_difficulty': <String, dynamic>{
          'beginner': store.exercises
              .where((e) => '${e['difficulty']}'.toLowerCase() == 'beginner')
              .length,
          'intermediate': store.exercises
              .where(
                (e) => '${e['difficulty']}'.toLowerCase() == 'intermediate',
              )
              .length,
          'advanced': store.exercises
              .where((e) => '${e['difficulty']}'.toLowerCase() == 'advanced')
              .length,
        },
        'by_language': byLanguage.entries
            .map(
              (e) => <String, dynamic>{
                'language_name': e.key,
                'count': e.value,
              },
            )
            .toList(),
        'recent_exercises': recent
            .take(5)
            .map(
              (e) => <String, dynamic>{
                'id': e['id'],
                'title': e['title'],
                'difficulty': e['difficulty'],
                'views': e['views'],
                'created_at': e['created_at'],
                'status': e['status'],
              },
            )
            .toList(),
      });
    });
  });

  router.get('/api/admin/exercises/<id>', (Request request, String id) {
    return requireAdmin(request, (user, token) async {
      final exerciseId = int.tryParse(id);
      if (exerciseId == null)
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      final index = store.exercises.indexWhere((e) => e['id'] == exerciseId);
      if (index == -1)
        return jsonResponse(<String, dynamic>{
          'message': 'Exercise not found',
        }, status: 404);
      return jsonResponse(store.exercises[index]);
    });
  });

  router.post('/api/admin/exercises', (Request request) {
    return requireAdmin(request, (user, token) async {
      final proxy = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/api/exercises'),
          headers: request.headers,
          body: await request.readAsString(),
        ),
      );
      return proxy;
    });
  });

  router.put('/api/admin/exercises/<id>', (Request request, String id) {
    return requireAdmin(request, (user, token) async {
      final exerciseId = int.tryParse(id);
      if (exerciseId == null)
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      final index = store.exercises.indexWhere((e) => e['id'] == exerciseId);
      if (index == -1)
        return jsonResponse(<String, dynamic>{
          'message': 'Exercise not found',
        }, status: 404);

      final body = await readJsonBody(request);
      for (final entry in body.entries) {
        store.exercises[index][entry.key] = entry.value;
      }
      if (body.containsKey('status') &&
          '${body['status']}' == 'published' &&
          store.exercises[index]['published_at'] == null) {
        store.exercises[index]['published_at'] = DateTime.now()
            .toUtc()
            .toIso8601String();
      }
      store.exercises[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Exercise updated successfully',
        'exercise': store.exercises[index],
      });
    });
  });

  router.delete('/api/admin/exercises/<id>', (Request request, String id) {
    return requireAdmin(request, (user, token) async {
      final exerciseId = int.tryParse(id);
      if (exerciseId == null)
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      store.exercises.removeWhere((e) => e['id'] == exerciseId);
      return jsonResponse(<String, dynamic>{
        'message': 'Exercise deleted successfully',
      });
    });
  });

  router.post('/api/admin/exercises/bulk-delete', (Request request) {
    return requireAdmin(request, (user, token) async {
      final body = await readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      store.exercises.removeWhere((e) => ids.contains(e['id']));
      return jsonResponse(<String, dynamic>{
        'message': 'Exercises deleted successfully',
      });
    });
  });

  router.post('/api/admin/exercises/bulk-update-status', (Request request) {
    return requireAdmin(request, (user, token) async {
      final body = await readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      final status = '${body['status'] ?? ''}';
      for (final e in store.exercises) {
        if (ids.contains(e['id'])) {
          e['status'] = status;
          if (status == 'published') {
            e['published_at'] = DateTime.now().toUtc().toIso8601String();
          }
          e['updated_at'] = DateTime.now().toUtc().toIso8601String();
        }
      }
      return jsonResponse(<String, dynamic>{
        'message': 'Exercise status updated successfully',
      });
    });
  });

  router.get('/api/admin/tutorials', (Request request) {
    return requireAdmin(request, (user, token) async {
      final q = request.url.queryParameters;
      final search = (q['search'] ?? '').toLowerCase();
      final languageId = q['language_id'];
      final perPage = int.tryParse(q['per_page'] ?? '') ?? 0;
      final page = int.tryParse(q['page'] ?? '1') ?? 1;

      var items = List<Map<String, dynamic>>.from(store.tutorials);
      if (languageId != null && languageId.isNotEmpty) {
        items = items
            .where((t) => '${t['language_id']}' == languageId)
            .toList();
      }
      if (search.isNotEmpty) {
        items = items
            .where((t) => '${t['title']}'.toLowerCase().contains(search))
            .toList();
      }
      sortByField(items, 'order', 'asc');

      if (perPage > 0) {
        return jsonResponse(
          store.paginate(items, page: page, perPage: perPage),
        );
      }
      return jsonResponse(items);
    });
  });

  router.get('/api/admin/tutorials/<id>', (Request request, String id) {
    return requireAdmin(request, (user, token) async {
      final tutorialId = int.tryParse(id);
      if (tutorialId == null)
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      final index = store.tutorials.indexWhere((t) => t['id'] == tutorialId);
      if (index == -1)
        return jsonResponse(<String, dynamic>{
          'message': 'Tutorial not found',
        }, status: 404);
      return jsonResponse(store.tutorials[index]);
    });
  });

  router.post('/api/admin/tutorials', (Request request) {
    return requireAdmin(request, (user, token) async {
      final body = await readJsonBody(request);
      final languageId = '${body['language_id'] ?? ''}'.trim();
      final title = '${body['title'] ?? ''}'.trim();
      final content = '${body['content'] ?? ''}'.trim();
      if (languageId.isEmpty || title.isEmpty || content.isEmpty) {
        return jsonResponse(<String, dynamic>{
          'message': 'language_id, title and content are required',
        }, status: 422);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final tutorial = <String, dynamic>{
        'id': store.nextTutorialId(),
        'language_id': languageId,
        'title': title,
        'content': content,
        'code_example': body['code_example'],
        'order': (body['order'] as num?)?.toInt() ?? 0,
        'is_published': body['is_published'] ?? true,
        'created_at': now,
        'updated_at': now,
      };
      store.tutorials.add(tutorial);
      return jsonResponse(<String, dynamic>{
        'message': 'Tutorial created successfully',
        'tutorial': tutorial,
      }, status: 201);
    });
  });

  router.put('/api/admin/tutorials/<id>', (Request request, String id) {
    return requireAdmin(request, (user, token) async {
      final tutorialId = int.tryParse(id);
      if (tutorialId == null)
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      final index = store.tutorials.indexWhere((t) => t['id'] == tutorialId);
      if (index == -1)
        return jsonResponse(<String, dynamic>{
          'message': 'Tutorial not found',
        }, status: 404);

      final body = await readJsonBody(request);
      for (final entry in body.entries) {
        store.tutorials[index][entry.key] = entry.value;
      }
      store.tutorials[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return jsonResponse(<String, dynamic>{
        'message': 'Tutorial updated successfully',
        'tutorial': store.tutorials[index],
      });
    });
  });

  router.delete('/api/admin/tutorials/<id>', (Request request, String id) {
    return requireAdmin(request, (user, token) async {
      final tutorialId = int.tryParse(id);
      if (tutorialId == null)
        return jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      store.tutorials.removeWhere((t) => t['id'] == tutorialId);
      return jsonResponse(<String, dynamic>{
        'message': 'Tutorial deleted successfully',
      });
    });
  });

  router.post('/api/admin/tutorials/bulk-delete', (Request request) {
    return requireAdmin(request, (user, token) async {
      final body = await readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      store.tutorials.removeWhere((t) => ids.contains(t['id']));
      return jsonResponse(<String, dynamic>{
        'message': 'Tutorials deleted successfully',
      });
    });
  });

  router.post('/api/admin/tutorials/bulk-update-status', (Request request) {
    return requireAdmin(request, (user, token) async {
      final body = await readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      final isPublished = body['is_published'] == true;
      for (final t in store.tutorials) {
        if (ids.contains(t['id'])) {
          t['is_published'] = isPublished;
          t['updated_at'] = DateTime.now().toUtc().toIso8601String();
        }
      }
      return jsonResponse(<String, dynamic>{
        'message': 'Tutorial status updated successfully',
      });
    });
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(persistStateMiddleware())
      .addHandler(router.call);

  final preferredPort =
      int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;

  final server = await serveWithPortFallback(
    handler,
    InternetAddress.anyIPv4,
    preferredPort,
  );

  print(
    'Dart backend listening on http://${server.address.host}:${server.port}',
  );
  print('Health endpoint: http://localhost:${server.port}/api/health');
  print('Default admin: admin@ekusheycoding.com / admin123');

  ProcessSignal.sigint.watch().listen((_) async {
    await store.closePersistence();
    exit(0);
  });
}
