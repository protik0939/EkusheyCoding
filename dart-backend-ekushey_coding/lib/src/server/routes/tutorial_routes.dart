import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../store.dart';
import '../context.dart';

void registerTutorialRoutes(Router router, ApiContext api) {
  router.get('/api/tutorials', (Request request) {
    final q = request.url.queryParameters;
    final languageId = q['language_id'];
    final hasPublished = q.containsKey('is_published');
    final isPublishedOnly =
        q['is_published'] == 'true' || q['is_published'] == '1';
    final search = (q['search'] ?? '').toLowerCase();

    var items = List<Map<String, dynamic>>.from(api.store.tutorials);

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

    api.sortByField(items, 'order', 'asc');

    final perPage = int.tryParse(q['per_page'] ?? '') ?? 0;
    if (perPage > 0) {
      final page = int.tryParse(q['page'] ?? '1') ?? 1;
      return api.jsonResponse(
        api.store.paginate(items, page: page, perPage: perPage),
      );
    }

    return api.jsonResponse(items);
  });

  router.get('/api/tutorials/languages', (Request request) {
    final set = <String>{};
    for (final t in api.store.tutorials.where(
      (t) => t['is_published'] == true,
    )) {
      set.add('${t['language_id']}');
    }
    return api.jsonResponse(set.toList());
  });

  router.get('/api/tutorials/<id>', (Request request, String id) {
    final tutorialId = int.tryParse(id);
    if (tutorialId == null) {
      return api.jsonResponse(<String, dynamic>{
        'message': 'Invalid tutorial id',
      }, status: 400);
    }
    final index = api.store.tutorials.indexWhere((t) => t['id'] == tutorialId);
    if (index == -1) {
      return api.jsonResponse(<String, dynamic>{
        'message': 'Tutorial not found',
      }, status: 404);
    }
    return api.jsonResponse(api.store.tutorials[index]);
  });
}
