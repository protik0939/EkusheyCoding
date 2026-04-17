import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../store.dart';
import '../context.dart';

void registerAdminBlogRoutes(Router router, ApiContext api) {
  router.get('/api/admin/blogs', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final q = request.url.queryParameters;
      final search = (q['search'] ?? '').toLowerCase();
      final status = q['status'];
      final category = q['category'];
      final authorId = int.tryParse(q['author_id'] ?? '');
      final sortBy = q['sort_by'] ?? 'created_at';
      final sortOrder = q['sort_order'] ?? 'desc';
      final page = int.tryParse(q['page'] ?? '1') ?? 1;
      final perPage = int.tryParse(q['per_page'] ?? '15') ?? 15;

      var items = List<Map<String, dynamic>>.from(api.store.blogs);

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

      api.sortByField(items, sortBy, sortOrder);
      return api.jsonResponse(
        api.store.paginate(items, page: page, perPage: perPage),
      );
    });
  });

  router.get('/api/admin/blogs/stats', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final totalBlogs = api.store.blogs.length;
      final publishedBlogs = api.store.blogs
          .where((b) => '${b['status']}' == 'published')
          .length;
      final draftBlogs = api.store.blogs
          .where((b) => '${b['status']}' == 'draft')
          .length;
      final totalViews = api.store.blogs.fold<int>(
        0,
        (acc, b) => acc + ((b['views'] as int?) ?? 0),
      );

      final recent = List<Map<String, dynamic>>.from(api.store.blogs);
      api.sortByField(recent, 'created_at', 'desc');

      final categories = <String, int>{};
      for (final b in api.store.blogs) {
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

      return api.jsonResponse(<String, dynamic>{
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
    return api.requireAdmin(request, (user, token) async {
      final blogId = int.tryParse(id);
      if (blogId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      final index = api.store.blogs.indexWhere((b) => b['id'] == blogId);
      if (index == -1) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Blog not found',
        }, status: 404);
      }
      return api.jsonResponse(api.store.blogs[index]);
    });
  });

  router.post('/api/admin/blogs', (Request request) {
    return api.requireAdmin(request, (user, token) async {
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
    return api.requireAdmin(request, (user, token) async {
      final blogId = int.tryParse(id);
      if (blogId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      final index = api.store.blogs.indexWhere((b) => b['id'] == blogId);
      if (index == -1) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Blog not found',
        }, status: 404);
      }

      final body = await api.readJsonBody(request);
      for (final entry in body.entries) {
        api.store.blogs[index][entry.key] = entry.value;
      }
      if (body.containsKey('title')) {
        var slug = api.slugify('${body['title']}');
        final original = slug;
        var c = 1;
        while (api.store.blogs.any(
          (b) => b['id'] != blogId && '${b['slug']}' == slug,
        )) {
          slug = '$original-$c';
          c++;
        }
        api.store.blogs[index]['slug'] = slug;
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

  router.delete('/api/admin/blogs/<id>', (Request request, String id) {
    return api.requireAdmin(request, (user, token) async {
      final blogId = int.tryParse(id);
      if (blogId == null) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'Invalid id',
        }, status: 400);
      }
      api.store.blogs.removeWhere((b) => b['id'] == blogId);
      return api.jsonResponse(<String, dynamic>{
        'message': 'Blog deleted successfully',
      });
    });
  });

  router.post('/api/admin/blogs/bulk-delete', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final body = await api.readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      final before = api.store.blogs.length;
      api.store.blogs.removeWhere((b) => ids.contains(b['id']));
      final deleted = before - api.store.blogs.length;
      return api.jsonResponse(<String, dynamic>{
        'message': '$deleted blogs deleted successfully',
        'deleted_count': deleted,
      });
    });
  });

  router.post('/api/admin/blogs/bulk-update-status', (Request request) {
    return api.requireAdmin(request, (user, token) async {
      final body = await api.readJsonBody(request);
      final ids = (body['ids'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();
      final status = '${body['status'] ?? ''}';
      var updated = 0;
      for (final b in api.store.blogs) {
        if (ids.contains(b['id'])) {
          b['status'] = status;
          if (status == 'published' && b['published_at'] == null) {
            b['published_at'] = DateTime.now().toUtc().toIso8601String();
          }
          b['updated_at'] = DateTime.now().toUtc().toIso8601String();
          updated++;
        }
      }
      return api.jsonResponse(<String, dynamic>{
        'message': '$updated blogs updated successfully',
        'updated_count': updated,
      });
    });
  });
}
