import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../store.dart';
import '../context.dart';

void registerExerciseRoutes(Router router, ApiContext api) {
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

    var items = List<Map<String, dynamic>>.from(api.store.exercises);
    if (status == null || status.isEmpty) {
      items = items.where(api.isPublished).toList();
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

    api.sortByField(items, sortBy, sortOrder);
    return api.jsonResponse(
      api.store.paginate(items, page: page, perPage: perPage),
    );
  });

  router.get('/api/exercises/categories', (Request request) {
    final categories = <String, Map<String, dynamic>>{};
    for (final e in api.store.exercises.where(api.isPublished)) {
      categories['${e['category']}'] = <String, dynamic>{
        'category': e['category'],
        'category_bn': e['category_bn'],
      };
    }
    return api.jsonResponse(categories.values.toList());
  });

  router.get('/api/exercises/popular', (Request request) {
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '5') ?? 5;
    final items = List<Map<String, dynamic>>.from(
      api.store.exercises.where(api.isPublished),
    );
    api.sortByField(items, 'views', 'desc');
    return api.jsonResponse(items.take(limit).toList());
  });

  router.get('/api/exercises/recent', (Request request) {
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '5') ?? 5;
    final items = List<Map<String, dynamic>>.from(
      api.store.exercises.where(api.isPublished),
    );
    api.sortByField(items, 'published_at', 'desc');
    return api.jsonResponse(items.take(limit).toList());
  });

  router.get('/api/exercises/difficulty/<difficulty>', (
    Request request,
    String difficulty,
  ) {
    final perPage =
        int.tryParse(request.url.queryParameters['per_page'] ?? '10') ?? 10;
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;

    final items = List<Map<String, dynamic>>.from(
      api.store.exercises.where(
        (e) =>
            api.isPublished(e) &&
            '${e['difficulty']}'.toLowerCase() == difficulty.toLowerCase(),
      ),
    );

    api.sortByField(items, 'published_at', 'desc');
    return api.jsonResponse(
      api.store.paginate(items, page: page, perPage: perPage),
    );
  });

  router.get('/api/exercises/<slug>', (Request request, String slug) {
    final index = api.store.exercises.indexWhere((e) => '${e['slug']}' == slug);
    if (index == -1) {
      return api.jsonResponse(<String, dynamic>{
        'message': 'Exercise not found',
      }, status: 404);
    }

    api.store.exercises[index]['views'] =
        ((api.store.exercises[index]['views'] as int?) ?? 0) + 1;
    return api.jsonResponse(api.store.exercises[index]);
  });

  router.post('/api/exercises', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final body = await api.readJsonBody(request);
      final title = '${body['title'] ?? ''}'.trim();
      final difficulty = '${body['difficulty'] ?? ''}'.trim();
      if (title.isEmpty || difficulty.isEmpty) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'title and difficulty are required',
        }, status: 422);
      }

      var slug = '${body['slug'] ?? ''}'.trim();
      if (slug.isEmpty) slug = api.slugify(title);
      final original = slug;
      var c = 1;
      while (api.store.exercises.any((e) => '${e['slug']}' == slug)) {
        slug = '$original-$c';
        c++;
      }

      final status = '${body['status'] ?? 'draft'}';
      final now = DateTime.now().toUtc().toIso8601String();
      final exercise = <String, dynamic>{
        'id': api.store.nextExerciseId(),
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

      api.store.exercises.add(exercise);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Exercise created successfully',
        'exercise': exercise,
      }, status: 201);
    });
  });

  router.put('/api/exercises/<slug>', (Request request, String slug) {
    return api.requireAuth(request, (user, _) async {
      final index = api.store.exercises.indexWhere(
        (e) => '${e['slug']}' == slug,
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

  router.delete('/api/exercises/<slug>', (Request request, String slug) {
    return api.requireAuth(request, (user, _) async {
      api.store.exercises.removeWhere((e) => '${e['slug']}' == slug);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Exercise deleted successfully',
      });
    });
  });

  router.post('/api/exercises/<slug>/complete', (Request request, String slug) {
    return api.requireAuth(request, (user, _) async {
      final index = api.store.exercises.indexWhere(
        (e) => '${e['slug']}' == slug,
      );
      if (index == -1) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Exercise not found',
        }, status: 404);
      }
      api.store.exercises[index]['completions'] =
          ((api.store.exercises[index]['completions'] as int?) ?? 0) + 1;
      return api.jsonResponse(<String, dynamic>{
        'message': 'Exercise marked as completed',
        'completions': api.store.exercises[index]['completions'],
      });
    });
  });
}
