import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../store.dart';
import '../context.dart';

void registerProfileRoutes(Router router, ApiContext api) {
  router.put('/api/profile/basic-info', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final body = await api.readJsonBody(request);
      final name = body['name'];
      final email = body['email'];

      if (name != null) {
        user['name'] = '$name';
      }

      if (email != null) {
        final emailStr = '$email'.trim();
        final taken = api.store.users.any(
          (u) =>
              u['id'] != user['id'] &&
              '${u['email']}'.toLowerCase() == emailStr.toLowerCase(),
        );
        if (taken) {
          return api.jsonResponse(<String, dynamic>{
            'message': 'Email already taken',
          }, status: 422);
        }
        user['email'] = emailStr;
      }

      user['updated_at'] = DateTime.now().toUtc().toIso8601String();
      return api.jsonResponse(<String, dynamic>{
        'message': 'Profile updated successfully',
        'user': api.store.sanitizeUser(user),
      });
    });
  });

  router.put('/api/profile/details', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final body = await api.readJsonBody(request);
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
      return api.jsonResponse(<String, dynamic>{
        'message': 'Profile details updated successfully',
        'user': api.store.sanitizeUser(user),
      });
    });
  });

  router.post('/api/profile/change-password', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final body = await api.readJsonBody(request);
      final current = '${body['current_password'] ?? ''}';
      final next = '${body['new_password'] ?? ''}';
      final confirm = '${body['new_password_confirmation'] ?? ''}';

      if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'All password fields are required',
        }, status: 422);
      }
      if (next.length < 8) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'new_password must be at least 8 characters',
        }, status: 422);
      }
      if (next != confirm) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'new_password confirmation does not match',
        }, status: 422);
      }
      if (user['password_hash'] != api.store.hashPassword(current)) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'The current password is incorrect.',
        }, status: 422);
      }

      user['password_hash'] = api.store.hashPassword(next);
      user['updated_at'] = DateTime.now().toUtc().toIso8601String();
      return api.jsonResponse(<String, dynamic>{
        'message': 'Password changed successfully',
      });
    });
  });

  router.get('/api/profile/favorites', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final type = request.url.queryParameters['type'];
      var list = api.store.favorites.where((f) => f['user_id'] == user['id']);
      if (type != null && type.isNotEmpty) {
        list = list.where((f) => '${f['type']}' == type);
      }
      final output = list.toList();
      api.sortByField(output, 'order', 'asc');
      return api.jsonResponse(output);
    });
  });

  router.post('/api/profile/favorites', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final body = await api.readJsonBody(request);
      final type = '${body['type'] ?? ''}';
      final title = '${body['title'] ?? ''}';
      if (type.isEmpty || title.isEmpty) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'type and title are required',
        }, status: 422);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final favorite = <String, dynamic>{
        'id': api.store.nextFavoriteId(),
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
      api.store.favorites.add(favorite);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Favorite added successfully',
        'favorite': favorite,
      }, status: 201);
    });
  });

  router.put('/api/profile/favorites/<id>', (Request request, String id) {
    return api.requireAuth(request, (user, _) async {
      final favId = int.tryParse(id);
      if (favId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid favorite id',
        }, status: 400);
      }
      final index = api.store.favorites.indexWhere(
        (f) => f['id'] == favId && f['user_id'] == user['id'],
      );
      if (index == -1) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Favorite not found',
        }, status: 404);
      }

      final body = await api.readJsonBody(request);
      for (final entry in body.entries) {
        api.store.favorites[index][entry.key] = entry.value;
      }
      api.store.favorites[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return api.jsonResponse(<String, dynamic>{
        'message': 'Favorite updated successfully',
        'favorite': api.store.favorites[index],
      });
    });
  });

  router.delete('/api/profile/favorites/<id>', (Request request, String id) {
    return api.requireAuth(request, (user, _) async {
      final favId = int.tryParse(id);
      if (favId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid favorite id',
        }, status: 400);
      }
      api.store.favorites.removeWhere(
        (f) => f['id'] == favId && f['user_id'] == user['id'],
      );
      return api.jsonResponse(<String, dynamic>{
        'message': 'Favorite deleted successfully',
      });
    });
  });

  router.post('/api/profile/activity', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final body = await api.readJsonBody(request);
      final minutes = (body['minutes_active'] as num?)?.toInt() ?? 0;
      if (minutes < 0) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'minutes_active must be >= 0',
        }, status: 422);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final activity = <String, dynamic>{
        'id': api.store.nextActivityId(),
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
      api.store.activities.add(activity);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Activity tracked successfully',
        'activity': activity,
      }, status: 201);
    });
  });

  router.get('/api/profile/activity/history', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final days =
          int.tryParse(request.url.queryParameters['days'] ?? '30') ?? 30;
      final since = DateTime.now().toUtc().subtract(Duration(days: days));
      final list = api.store.activities.where((a) {
        if (a['user_id'] != user['id']) return false;
        final dt = DateTime.tryParse('${a['created_at']}');
        return dt != null && !dt.isBefore(since);
      }).toList();
      api.sortByField(list, 'created_at', 'desc');
      return api.jsonResponse(list);
    });
  });

  router.get('/api/profile/performance', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final mine = api.store.activities.where(
        (a) => a['user_id'] == user['id'],
      );
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
      return api.jsonResponse(stats);
    });
  });

  router.post('/api/profile/badge', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final body = await api.readJsonBody(request);
      final badge = '${body['badge'] ?? ''}'.trim();
      if (badge.isEmpty) {
        return api.jsonResponse(<String, dynamic>{
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
      return api.jsonResponse(<String, dynamic>{
        'message': 'Badge awarded successfully',
        'badges': badges,
      });
    });
  });
}
