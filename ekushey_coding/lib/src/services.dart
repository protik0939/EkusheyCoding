import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  ApiClient({String? baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrls = _resolveBaseUrls(baseUrl: baseUrl) {
    _activeBaseUrl = _baseUrls.first;
  }

  final http.Client _httpClient;
  final List<String> _baseUrls;
  late String _activeBaseUrl;

  String get baseUrl => _activeBaseUrl;

  static List<String> _resolveBaseUrls({String? baseUrl}) {
    final envBaseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    final candidates = <String>[
      if (baseUrl != null && baseUrl.trim().isNotEmpty) baseUrl,
      if (envBaseUrl.trim().isNotEmpty) envBaseUrl,
      ..._platformDefaultBaseUrls(),
      'http://localhost:8080/api',
      'http://localhost:8081/api',
    ];

    final normalized = <String>[];
    for (final candidate in candidates) {
      final value = _normalizeBaseUrl(candidate);
      if (value.isNotEmpty && !normalized.contains(value)) {
        normalized.add(value);
      }
    }

    if (normalized.isEmpty) {
      return <String>['http://localhost:8080/api'];
    }

    return normalized;
  }

  static List<String> _platformDefaultBaseUrls() {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isEmpty) {
        return const <String>[];
      }

      final scheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
      final authority = Uri.base.authority;
      return <String>[
        '$scheme://$host:8080/api',
        '$scheme://$host:8081/api',
        '$scheme://$authority/api',
      ];
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return const <String>[
        'http://10.0.2.2:8080/api',
        'http://10.0.2.2:8081/api',
        'http://localhost:8080/api',
        'http://localhost:8081/api',
      ];
    }

    return const <String>[
      'http://localhost:8080/api',
      'http://localhost:8081/api',
      'http://127.0.0.1:8080/api',
      'http://127.0.0.1:8081/api',
    ];
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    try {
      final uri = Uri.parse(trimmed);
      var path = uri.path.trim();
      if (path.isEmpty || path == '/') {
        path = '/api';
      }
      if (path.length > 1 && path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }

      return uri.replace(path: path, query: null, fragment: null).toString();
    } catch (_) {
      return trimmed.endsWith('/')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed;
    }
  }

  List<String> _orderedBaseUrls() {
    return <String>[
      _activeBaseUrl,
      ..._baseUrls.where((base) => base != _activeBaseUrl),
    ];
  }

  Uri _buildUri(String baseUrl, String endpoint, [Map<String, String>? query]) {
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

  bool _isNetworkIssue(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('clientexception') ||
        message.contains('xmlhttprequest error') ||
        message.contains('networkerror') ||
        message.contains('timed out');
  }

  Future<dynamic> _sendWithFallback({
    required String endpoint,
    required String? token,
    Map<String, String>? query,
    required bool isJson,
    required Future<http.Response> Function(
      Uri uri,
      Map<String, String> headers,
    )
    send,
  }) async {
    final headers = _headers(token: token, isJson: isJson);
    final candidates = _orderedBaseUrls();
    final failures = <String>[];

    for (final candidate in candidates) {
      try {
        final response = await send(
          _buildUri(candidate, endpoint, query),
          headers,
        ).timeout(const Duration(seconds: 8));
        _activeBaseUrl = candidate;
        return _parseResponse(response);
      } on TimeoutException catch (error) {
        failures.add('$candidate -> $error');
      } catch (error) {
        if (!_isNetworkIssue(error)) {
          rethrow;
        }
        failures.add('$candidate -> $error');
      }
    }

    throw ApiException(
      'Unable to reach backend. Tried: ${candidates.join(', ')}. '
      'Provide API_BASE_URL using --dart-define if your backend uses a custom host.',
    );
  }

  Future<dynamic> get(
    String endpoint, {
    String? token,
    Map<String, String>? query,
  }) async {
    return _sendWithFallback(
      endpoint: endpoint,
      token: token,
      query: query,
      isJson: true,
      send: (uri, headers) {
        return _httpClient.get(uri, headers: headers);
      },
    );
  }

  Future<dynamic> post(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
    bool isJson = true,
  }) async {
    return _sendWithFallback(
      endpoint: endpoint,
      token: token,
      isJson: isJson,
      send: (uri, headers) {
        return _httpClient.post(
          uri,
          headers: headers,
          body: body == null ? null : (isJson ? jsonEncode(body) : body),
        );
      },
    );
  }

  Future<dynamic> put(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    return _sendWithFallback(
      endpoint: endpoint,
      token: token,
      isJson: true,
      send: (uri, headers) {
        return _httpClient.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      },
    );
  }

  Future<dynamic> delete(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    return _sendWithFallback(
      endpoint: endpoint,
      token: token,
      isJson: true,
      send: (uri, headers) {
        return _httpClient.delete(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      },
    );
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
    if (category != null && category.isNotEmpty && category != 'All') {
      query['category'] = category;
    }

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
          if (e is Map<String, dynamic>) {
            return (e['category'] ?? e['category_bn'] ?? '').toString();
          }
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
    if (difficulty != null && difficulty.isNotEmpty && difficulty != 'all') {
      query['difficulty'] = difficulty;
    }
    if (languageId != null && languageId.isNotEmpty && languageId != 'all') {
      query['language_id'] = languageId;
    }

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
    if (languageId != null && languageId.isNotEmpty) {
      query['language_id'] = languageId;
    }
    if (publishedOnly) {
      query['is_published'] = 'true';
    }

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
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }

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
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (difficulty != null && difficulty.isNotEmpty && difficulty != 'all') {
      query['difficulty'] = difficulty;
    }

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
    if (languageId != null && languageId.isNotEmpty && languageId != 'all') {
      query['language_id'] = languageId;
    }

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
