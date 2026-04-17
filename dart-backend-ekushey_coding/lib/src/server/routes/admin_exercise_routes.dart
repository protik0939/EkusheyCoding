import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../store.dart';
import '../context.dart';

void registerAdminExerciseRoutes(Router router, ApiContext api) {
  router.get('/api/admin/exercises', (Request request) {
    return api.requireAdmin(request, (user, token) async {
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

      var items = List<Map<String, dynamic>>.from(api.store.exercises);
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

      api.sortByField(items, sortBy, sortOrder);
      return api.jsonResponse(
        api.store.paginate(items, page: page, perPage: perPage),
      );
    });
  });

  router.get('/api/admin/exercises/stats', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final total = api.store.exercises.length;
      final published = api.store.exercises
          .where((e) => '${e['status']}' == 'published')
          .length;
      final drafts = api.store.exercises
          .where((e) => '${e['status']}' == 'draft')
          .length;
      final archived = api.store.exercises
          .where((e) => '${e['status']}' == 'archived')
          .length;
      final totalViews = api.store.exercises.fold<int>(
        0,
        (acc, e) => acc + ((e['views'] as int?) ?? 0),
      );
      final totalCompletions = api.store.exercises.fold<int>(
        0,
        (acc, e) => acc + ((e['completions'] as int?) ?? 0),
      );

      final byLanguage = <String, int>{};
      for (final e in api.store.exercises) {
        final key = '${e['language_name'] ?? ''}';
        if (key.isEmpty) continue;
        byLanguage[key] = (byLanguage[key] ?? 0) + 1;
      }

      final recent = List<Map<String, dynamic>>.from(api.store.exercises);
      api.sortByField(recent, 'created_at', 'desc');

      return api.jsonResponse(<String, dynamic>{
        'total': total,
        'published': published,
        'drafts': drafts,
        'archived': archived,
        'total_views': totalViews,
        'total_completions': totalCompletions,
        'by_difficulty': <String, dynamic>{
          'beginner': api.store.exercises
              .where((e) => '${e['difficulty']}'.toLowerCase() == 'beginner')
              .length,
          'intermediate': api.store.exercises
              .where(
                (e) => '${e['difficulty']}'.toLowerCase() == 'intermediate',
              )
              .length,
          'advanced': api.store.exercises
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
    return api.requireAdmin(request, (user, token) async {
      final exerciseId = int.tryParse(id);
      if (exerciseId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      final index = api.store.exercises.indexWhere(
        (e) => e['id'] == exerciseId,
      );
      if (index == -1) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Exercise not found',
        }, status: 404);
      }
      return api.jsonResponse(api.store.exercises[index]);
    });
  });

  router.post('/api/admin/exercises', (Request request) {
    return api.requireAdmin(request, (user, token) async {
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
    return api.requireAdmin(request, (user, token) async {
      final exerciseId = int.tryParse(id);
      if (exerciseId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      final index = api.store.exercises.indexWhere(
        (e) => e['id'] == exerciseId,
      );
      if (index == -1) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Exercise not found',
        }, status: 404);
      }

      final body = await api.readJsonBody(request);
      for (final entry in body.entries) {
        api.store.exercises[index][entry.key] = entry.value;
      }
      if (body.containsKey('status') &&
          '${body['status']}' == 'published' &&
          api.store.exercises[index]['published_at'] == null) {
        api.store.exercises[index]['published_at'] = DateTime.now()
            .toUtc()
            .toIso8601String();
      }
      api.store.exercises[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return api.jsonResponse(<String, dynamic>{
        'message': 'Exercise updated successfully',
        'exercise': api.store.exercises[index],
      });
    });
  });

  router.delete('/api/admin/exercises/<id>', (Request request, String id) {
    return api.requireAdmin(request, (user, token) async {
      final exerciseId = int.tryParse(id);
      if (exerciseId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      api.store.exercises.removeWhere((e) => e['id'] == exerciseId);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Exercise deleted successfully',
      });
    });
  });

  router.post('/api/admin/exercises/bulk-delete', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final body = await api.readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      api.store.exercises.removeWhere((e) => ids.contains(e['id']));
      return api.jsonResponse(<String, dynamic>{
        'message': 'Exercises deleted successfully',
      });
    });
  });

  router.post('/api/admin/exercises/bulk-update-status', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final body = await api.readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      final status = '${body['status'] ?? ''}';
      for (final e in api.store.exercises) {
        if (ids.contains(e['id'])) {
          e['status'] = status;
          if (status == 'published') {
            e['published_at'] = DateTime.now().toUtc().toIso8601String();
          }
          e['updated_at'] = DateTime.now().toUtc().toIso8601String();
        }
      }
      return api.jsonResponse(<String, dynamic>{
        'message': 'Exercise status updated successfully',
      });
    });
  });
}
