import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../store.dart';

class ApiContext {
  ApiContext(this.store);

  final InMemoryStore store;
  Future<void>? _persistTask;
  bool _persistAgain = false;

  void _schedulePersist() {
    if (_persistTask != null) {
      _persistAgain = true;
      return;
    }

    _persistTask = _runPersistLoop();
  }

  Future<void> _runPersistLoop() async {
    do {
      _persistAgain = false;
      try {
        await store.persistState();
      } catch (error) {
        stderr.writeln('Failed to persist state: $error');
      }
    } while (_persistAgain);

    _persistTask = null;
  }

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

  void sortByField(
    List<Map<String, dynamic>> list,
    String field,
    String order,
  ) {
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

    if (request.method.toUpperCase() == 'GET') {
      final path = request.url.path;
      final blogDetailMatch = RegExp(r'^api/blogs/[^/]+$').hasMatch(path);
      final exerciseDetailMatch = RegExp(
        r'^api/exercises/[^/]+$',
      ).hasMatch(path);
      return blogDetailMatch || exerciseDetailMatch;
    }

    return false;
  }

  Middleware persistStateMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        final response = await inner(request);
        if (_shouldPersistRequest(request) && response.statusCode < 500) {
          _schedulePersist();
        }
        return response;
      };
    };
  }
}
