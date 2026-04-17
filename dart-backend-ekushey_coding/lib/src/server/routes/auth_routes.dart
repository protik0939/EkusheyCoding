import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../store.dart';
import '../context.dart';

void registerAuthRoutes(Router router, ApiContext api) {
  router.get('/api/health', (Request request) {
    return api.jsonResponse(<String, dynamic>{
      'service': 'dart-backend-w3university',
      'status': 'ok',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  });

  router.post('/api/register', (Request request) async {
    try {
      final body = await api.readJsonBody(request);
      final name = '${body['name'] ?? ''}'.trim();
      final email = '${body['email'] ?? ''}'.trim();
      final password = '${body['password'] ?? ''}';
      final confirm = '${body['password_confirmation'] ?? ''}';

      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'name, email and password are required',
        }, status: 422);
      }
      if (!email.contains('@')) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'email must be valid',
        }, status: 422);
      }
      if (password.length < 8) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'password must be at least 8 characters',
        }, status: 422);
      }
      if (password != confirm) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'password confirmation does not match',
        }, status: 422);
      }

      final response = api.store.register(
        name: name,
        email: email,
        password: password,
      );
      return api.jsonResponse(response, status: 201);
    } on StateError catch (e) {
      return api.jsonResponse(<String, dynamic>{
        'message': e.message,
      }, status: 422);
    } catch (_) {
      return api.jsonResponse(<String, dynamic>{
        'message': 'Invalid request body',
      }, status: 400);
    }
  });

  router.post('/api/login', (Request request) async {
    try {
      final body = await api.readJsonBody(request);
      final email = '${body['email'] ?? ''}'.trim();
      final password = '${body['password'] ?? ''}';
      if (email.isEmpty || password.isEmpty) {
        return api.jsonResponse(<String, dynamic>{
          'message': 'email and password are required',
        }, status: 422);
      }

      final response = api.store.login(email: email, password: password);
      return api.jsonResponse(response);
    } on StateError catch (e) {
      return api.jsonResponse(<String, dynamic>{
        'message': e.message,
      }, status: 422);
    } catch (_) {
      return api.jsonResponse(<String, dynamic>{
        'message': 'Invalid request body',
      }, status: 400);
    }
  });

  router.get('/api/user', (Request request) {
    return api.requireAuth(
      request,
      (user, _) async => api.jsonResponse(api.store.profilePayload(user)),
    );
  });

  router.get('/api/profile', (Request request) {
    return api.requireAuth(
      request,
      (user, _) async => api.jsonResponse(api.store.profilePayload(user)),
    );
  });

  router.post('/api/logout', (Request request) {
    return api.requireAuth(request, (user, token) async {
      api.store.logout(token);
      user['api_token_hash'] = null;
      user['updated_at'] = DateTime.now().toUtc().toIso8601String();
      return api.jsonResponse(<String, dynamic>{
        'message': 'Logged out successfully',
      });
    });
  });
}
