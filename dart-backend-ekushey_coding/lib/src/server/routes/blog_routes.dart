import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../store.dart';
import '../context.dart';

void registerBlogRoutes(Router router, ApiContext api) {
  router.get('/api/blogs', (Request request) {
    final q = request.url.queryParameters;
    final status = q['status'];
    final category = q['category'];
    final search = (q['search'] ?? '').toLowerCase();
    final sortBy = q['sort_by'] ?? 'published_at';
    final sortOrder = q['sort_order'] ?? 'desc';
    final page = int.tryParse(q['page'] ?? '1') ?? 1;
    final perPage = int.tryParse(q['per_page'] ?? '10') ?? 10;

    var items = List<Map<String, dynamic>>.from(api.store.blogs);
    if (status == null || status.isEmpty) {
      items = items.where(api.isPublished).toList();
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

    api.sortByField(items, sortBy, sortOrder);
    return api.jsonResponse(
      api.store.paginate(items, page: page, perPage: perPage),
    );
  });

  router.get('/api/blogs/categories', (Request request) {
    final categories = <String, Map<String, dynamic>>{};
    for (final b in api.store.blogs.where(api.isPublished)) {
      categories['${b['category']}'] = <String, dynamic>{
        'category': b['category'],
        'category_bn': b['category_bn'],
      };
    }
    return api.jsonResponse(categories.values.toList());
  });

  router.get('/api/blogs/popular', (Request request) {
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '5') ?? 5;
    final items = List<Map<String, dynamic>>.from(
      api.store.blogs.where(api.isPublished),
    );
    api.sortByField(items, 'views', 'desc');
    return api.jsonResponse(items.take(limit).toList());
  });

  router.get('/api/blogs/recent', (Request request) {
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '5') ?? 5;
    final items = List<Map<String, dynamic>>.from(
      api.store.blogs.where(api.isPublished),
    );
    api.sortByField(items, 'published_at', 'desc');
    return api.jsonResponse(items.take(limit).toList());
  });

  router.get('/api/blogs/<slug>', (Request request, String slug) {
    final index = api.store.blogs.indexWhere((b) => '${b['slug']}' == slug);
    if (index == -1) {
      return api.jsonResponse(<String, dynamic>{
        'message': 'Blog not found',
      }, status: 404);
    }

    api.store.blogs[index]['views'] =
        ((api.store.blogs[index]['views'] as int?) ?? 0) + 1;
    return api.jsonResponse(api.store.blogs[index]);
  });

  router.post('/api/blogs', (Request request) {
    return api.requireAuth(request, (user, _) async {
      final body = await api.readJsonBody(request);
      final title = '${body['title'] ?? ''}'.trim();
      if (title.isEmpty) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'title is required',
        }, status: 422);
      }

      var slug = '${body['slug'] ?? ''}'.trim();
      if (slug.isEmpty) slug = api.slugify(title);
      final original = slug;
      var c = 1;
      while (api.store.blogs.any((b) => '${b['slug']}' == slug)) {
        slug = '$original-$c';
        c++;
      }

      final status = '${body['status'] ?? 'draft'}';
      final now = DateTime.now().toUtc().toIso8601String();
      final blog = <String, dynamic>{
        'id': api.store.nextBlogId(),
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

      api.store.blogs.add(blog);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Blog created successfully',
        'blog': blog,
      }, status: 201);
    });
  });

  router.put('/api/blogs/<slug>', (Request request, String slug) {
    return api.requireAuth(request, (user, _) async {
      final index = api.store.blogs.indexWhere((b) => '${b['slug']}' == slug);
      if (index == -1) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Blog not found',
        }, status: 404);
      }
      final body = await api.readJsonBody(request);
      for (final entry in body.entries) {
        api.store.blogs[index][entry.key] = entry.value;
      }
      if (body.containsKey('status') &&
          '${body['status']}' == 'published' &&
          api.store.blogs[index]['published_at'] == null) {
        api.store.blogs[index]['published_at'] = DateTime.now()
            .toUtc()
            .toIso8601String();
      }
      api.store.blogs[index]['updated_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return api.jsonResponse(<String, dynamic>{
        'message': 'Blog updated successfully',
        'blog': api.store.blogs[index],
      });
    });
  });

  router.delete('/api/blogs/<slug>', (Request request, String slug) {
    return api.requireAuth(request, (user, _) async {
      api.store.blogs.removeWhere((b) => '${b['slug']}' == slug);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Blog deleted successfully',
      });
    });
  });
}
