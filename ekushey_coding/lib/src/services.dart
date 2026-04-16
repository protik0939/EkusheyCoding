import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class PaginatedList<T> {
  const PaginatedList({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

class ApiClient {
  ApiClient({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:8080/api',
          );

  final String baseUrl;

  Uri _buildUri(String endpoint, [Map<String, String>? query]) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$baseUrl$cleanEndpoint');
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers({String? token, bool isJson = true}) {
    final headers = <String, String>{'Accept': 'application/json'};

    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> get(
    String endpoint, {
    String? token,
    Map<String, String>? query,
  }) async {
    final response = await http.get(
      _buildUri(endpoint, query),
      headers: _headers(token: token),
    );
    return _parseResponse(response);
  }

  Future<dynamic> post(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
    bool isJson = true,
  }) async {
    final response = await http.post(
      _buildUri(endpoint),
      headers: _headers(token: token, isJson: isJson),
      body: body == null ? null : (isJson ? jsonEncode(body) : body),
    );
    return _parseResponse(response);
  }

  Future<dynamic> put(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final response = await http.put(
      _buildUri(endpoint),
      headers: _headers(token: token),
      body: body == null ? null : jsonEncode(body),
    );
    return _parseResponse(response);
  }

  Future<dynamic> delete(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final response = await http.delete(
      _buildUri(endpoint),
      headers: _headers(token: token),
      body: body == null ? null : jsonEncode(body),
    );
    return _parseResponse(response);
  }

  dynamic _parseResponse(http.Response response) {
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = <String, dynamic>{'message': response.body};
      }
    } else {
      data = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message = data is Map<String, dynamic>
        ? ((data['message'] ?? data['error'] ?? 'Request failed') as String)
        : 'Request failed';
    throw ApiException(message, statusCode: response.statusCode);
  }
}

class AuthService {
  const AuthService(this._api);

  final ApiClient _api;

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _api.post(
      '/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    return AuthResponse.fromJson(
      (response ?? <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/login',
      body: {'email': email, 'password': password},
    );

    return AuthResponse.fromJson(
      (response ?? <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  Future<void> logout(String token) async {
    await _api.post('/logout', token: token);
  }
}

class ContentService {
  const ContentService(this._api);

  final ApiClient _api;

  Future<PaginatedList<BlogPost>> fetchBlogs({
    int page = 1,
    int perPage = 10,
    String? search,
    String? category,
  }) async {
    final query = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (category != null && category.isNotEmpty && category != 'All')
      query['category'] = category;

    final response = await _api.get('/blogs', query: query);
    final map = (response ?? <String, dynamic>{}) as Map<String, dynamic>;
    final list = (map['data'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (item) => BlogPost.fromJson(
            (item ?? <String, dynamic>{}) as Map<String, dynamic>,
          ),
        )
        .toList();

    return PaginatedList<BlogPost>(
      items: list,
      currentPage: (map['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (map['last_page'] as num?)?.toInt() ?? 1,
      total: (map['total'] as num?)?.toInt() ?? list.length,
    );
  }

  Future<BlogPost> fetchBlogBySlug(String slug) async {
    final response = await _api.get('/blogs/$slug');
    return BlogPost.fromJson(
      (response ?? <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  Future<List<String>> fetchBlogCategories() async {
    final response = await _api.get('/blogs/categories');
    final list = (response as List<dynamic>? ?? <dynamic>[])
        .map((e) {
          if (e is String) return e;
          if (e is Map<String, dynamic>)
            return (e['category'] ?? e['category_bn'] ?? '').toString();
          return '';
        })
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    list.sort();
    return <String>['All', ...list];
  }

  Future<PaginatedList<ExerciseItem>> fetchExercises({
    int page = 1,
    int perPage = 20,
    String? search,
    String? difficulty,
    String? languageId,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'status': 'published',
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (difficulty != null && difficulty.isNotEmpty && difficulty != 'all')
      query['difficulty'] = difficulty;
    if (languageId != null && languageId.isNotEmpty && languageId != 'all')
      query['language_id'] = languageId;

    final response = await _api.get('/exercises', query: query);
    final map = (response ?? <String, dynamic>{}) as Map<String, dynamic>;
    final list = (map['data'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (item) => ExerciseItem.fromJson(
            (item ?? <String, dynamic>{}) as Map<String, dynamic>,
          ),
        )
        .toList();

    return PaginatedList<ExerciseItem>(
      items: list,
      currentPage: (map['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (map['last_page'] as num?)?.toInt() ?? 1,
      total: (map['total'] as num?)?.toInt() ?? list.length,
    );
  }

  Future<List<TutorialItem>> fetchTutorials({
    String? languageId,
    bool publishedOnly = true,
  }) async {
    final query = <String, String>{};
    if (languageId != null && languageId.isNotEmpty)
      query['language_id'] = languageId;
    if (publishedOnly) query['is_published'] = 'true';

    final response = await _api.get('/tutorials', query: query);
    if (response is List<dynamic>) {
      return response
          .map(
            (item) => TutorialItem.fromJson(
              (item ?? <String, dynamic>{}) as Map<String, dynamic>,
            ),
          )
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    }

    if (response is Map<String, dynamic>) {
      final list = (response['data'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) => TutorialItem.fromJson(
              (item ?? <String, dynamic>{}) as Map<String, dynamic>,
            ),
          )
          .toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    }

    return <TutorialItem>[];
  }

  Future<List<String>> fetchTutorialLanguages() async {
    final response = await _api.get('/tutorials/languages');
    return (response as List<dynamic>? ?? <dynamic>[])
        .map((e) => '$e')
        .toList();
  }
}

class ProfileService {
  const ProfileService(this._api);

  final ApiClient _api;

  Future<ProfileBundle> getProfile(String token) async {
    final response = await _api.get('/user', token: token);
    return ProfileBundle.fromJson(
      (response ?? <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  Future<void> updateBasicInfo(
    String token, {
    String? name,
    String? email,
  }) async {
    await _api.put(
      '/profile/basic-info',
      token: token,
      body: {if (name != null) 'name': name, if (email != null) 'email': email},
    );
  }

  Future<void> updateDetails(String token, Map<String, dynamic> data) async {
    await _api.put('/profile/details', token: token, body: data);
  }

  Future<void> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _api.post(
      '/profile/change-password',
      token: token,
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
    );
  }
}

class AdminService {
  const AdminService(this._api);

  final ApiClient _api;

  Future<DashboardStats> fetchDashboardStats(String token) async {
    final response = await _api.get('/admin/blogs/stats', token: token);
    return DashboardStats.fromJson(
      (response ?? <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  Future<PaginatedList<BlogPost>> fetchAdminBlogs(
    String token, {
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'sort_by': 'created_at',
      'sort_order': 'desc',
    };

    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status.isNotEmpty && status != 'all')
      query['status'] = status;

    final response = await _api.get('/admin/blogs', token: token, query: query);
    final map = (response ?? <String, dynamic>{}) as Map<String, dynamic>;
    final list = (map['data'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (item) => BlogPost.fromJson(
            (item ?? <String, dynamic>{}) as Map<String, dynamic>,
          ),
        )
        .toList();

    return PaginatedList<BlogPost>(
      items: list,
      currentPage: (map['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (map['last_page'] as num?)?.toInt() ?? 1,
      total: (map['total'] as num?)?.toInt() ?? list.length,
    );
  }

  Future<PaginatedList<ExerciseItem>> fetchAdminExercises(
    String token, {
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    String? difficulty,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'sort_by': 'created_at',
      'sort_order': 'desc',
    };

    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status.isNotEmpty && status != 'all')
      query['status'] = status;
    if (difficulty != null && difficulty.isNotEmpty && difficulty != 'all')
      query['difficulty'] = difficulty;

    final response = await _api.get(
      '/admin/exercises',
      token: token,
      query: query,
    );
    final map = (response ?? <String, dynamic>{}) as Map<String, dynamic>;
    final list = (map['data'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (item) => ExerciseItem.fromJson(
            (item ?? <String, dynamic>{}) as Map<String, dynamic>,
          ),
        )
        .toList();

    return PaginatedList<ExerciseItem>(
      items: list,
      currentPage: (map['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (map['last_page'] as num?)?.toInt() ?? 1,
      total: (map['total'] as num?)?.toInt() ?? list.length,
    );
  }

  Future<List<TutorialItem>> fetchAdminTutorials(
    String token, {
    String? search,
    String? languageId,
  }) async {
    final query = <String, String>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (languageId != null && languageId.isNotEmpty && languageId != 'all')
      query['language_id'] = languageId;

    final response = await _api.get(
      '/admin/tutorials',
      token: token,
      query: query,
    );

    if (response is List<dynamic>) {
      return response
          .map(
            (item) => TutorialItem.fromJson(
              (item ?? <String, dynamic>{}) as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    if (response is Map<String, dynamic>) {
      final list = (response['data'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) => TutorialItem.fromJson(
              (item ?? <String, dynamic>{}) as Map<String, dynamic>,
            ),
          )
          .toList();
      return list;
    }

    return <TutorialItem>[];
  }

  Future<void> deleteAdminBlog(String token, int id) async {
    await _api.delete('/admin/blogs/$id', token: token);
  }

  Future<void> deleteAdminExercise(String token, int id) async {
    await _api.delete('/admin/exercises/$id', token: token);
  }

  Future<void> deleteAdminTutorial(String token, int id) async {
    await _api.delete('/admin/tutorials/$id', token: token);
  }
}
