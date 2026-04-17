import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../store.dart';
import '../context.dart';

void registerAdminTutorialRoutes(Router router, ApiContext api) {
  router.get('/api/admin/tutorials', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final q = request.url.queryParameters;
      final search = (q['search'] ?? '').toLowerCase();
      final languageId = q['language_id'];
      final perPage = int.tryParse(q['per_page'] ?? '') ?? 0;
      final page = int.tryParse(q['page'] ?? '1') ?? 1;

      var items = List<Map<String, dynamic>>.from(api.store.tutorials);
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
      api.sortByField(items, 'order', 'asc');

      if (perPage > 0) {
        return api.jsonResponse(
          api.store.paginate(items, page: page, perPage: perPage),
        );
      }
      return api.jsonResponse(items);
    });
  });

  router.get('/api/admin/tutorials/<id>', (Request request, String id) {
    return api.requireAdmin(request, (user, token) async {
      final tutorialId = int.tryParse(id);
      if (tutorialId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      final index = api.store.tutorials.indexWhere(
        (t) => t['id'] == tutorialId,
      );
      if (index == -1) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Tutorial not found',
        }, status: 404);
      }
      return api.jsonResponse(api.store.tutorials[index]);
    });
  });

  router.post('/api/admin/tutorials', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final body = await api.readJsonBody(request);
      final languageId = '${body['language_id'] ?? ''}'.trim();
      final title = '${body['title'] ?? ''}'.trim();
      final content = '${body['content'] ?? ''}'.trim();
      if (languageId.isEmpty || title.isEmpty || content.isEmpty) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'language_id, title and content are required',
        }, status: 422);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final tutorial = <String, dynamic>{
        'id': api.store.nextTutorialId(),
        'language_id': languageId,
        'title': title,
        'content': content,
        'code_example': body['code_example'],
        'order': (body['order'] as num?)?.toInt() ?? 0,
        'is_published': body['is_published'] ?? true,
        'created_at': now,
        'updated_at': now,
      };
      api.store.tutorials.add(tutorial);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Tutorial created successfully',
        'tutorial': tutorial,
      }, status: 201);
    });
  });

  router.put('/api/admin/tutorials/<id>', (Request request, String id) {
    return api.requireAdmin(request, (user, token) async {
      final tutorialId = int.tryParse(id);
      if (tutorialId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      final index = api.store.tutorials.indexWhere(
        (t) => t['id'] == tutorialId,
      );
      if (index == -1) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Tutorial not found',
        }, status: 404);
      }

      final body = await api.readJsonBody(request);
      for (final entry in body.entries) {
        api.store.tutorials[index][entry.key] = entry.value;
      }
      api.store.tutorials[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return api.jsonResponse(<String, dynamic>{
        'message': 'Tutorial updated successfully',
        'tutorial': api.store.tutorials[index],
      });
    });
  });

  router.delete('/api/admin/tutorials/<id>', (Request request, String id) {
    return api.requireAdmin(request, (user, token) async {
      final tutorialId = int.tryParse(id);
      if (tutorialId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      api.store.tutorials.removeWhere((t) => t['id'] == tutorialId);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Tutorial deleted successfully',
      });
    });
  });

  router.post('/api/admin/tutorials/bulk-delete', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final body = await api.readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      api.store.tutorials.removeWhere((t) => ids.contains(t['id']));
      return api.jsonResponse(<String, dynamic>{
        'message': 'Tutorials deleted successfully',
      });
    });
  });

  router.post('/api/admin/tutorials/bulk-update-status', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final body = await api.readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      final isPublished = body['is_published'] == true;
      for (final t in api.store.tutorials) {
        if (ids.contains(t['id'])) {
          t['is_published'] = isPublished;
          t['updated_at'] = DateTime.now().toUtc().toIso8601String();
        }
      }
      return api.jsonResponse(<String, dynamic>{
        'message': 'Tutorial status updated successfully',
      });
    });
  });
}
