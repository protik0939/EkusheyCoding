import 'package:flutter/foundation.dart';

import 'models.dart';
import 'services.dart';
import 'session_store.dart';

class AppState extends ChangeNotifier {
  AppState({required SessionStore sessionStore, ApiClient? apiClient})
    : _sessionStore = sessionStore,
      _apiClient = apiClient ?? ApiClient(),
      _isInitialized = false,
      _isBusy = false;

  final SessionStore _sessionStore;
  final ApiClient _apiClient;

  late final AuthService authService = AuthService(_apiClient);
  late final ContentService contentService = ContentService(_apiClient);
  late final ProfileService profileService = ProfileService(_apiClient);
  late final AdminService adminService = AdminService(_apiClient);

  bool _isInitialized;
  bool _isBusy;
  String _locale = 'en';
  String? _token;
  UserModel? _user;

  bool get isInitialized => _isInitialized;
  bool get isBusy => _isBusy;
  String get locale => _locale;
  String? get token => _token;
  UserModel? get user => _user;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> initialize() async {
    _locale = await _sessionStore.getLocale();
    _token = await _sessionStore.getToken();
    _user = await _sessionStore.getUser();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    await _sessionStore.saveLocale(locale);
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    _setBusy(true);
    try {
      final auth = await authService.login(email: email, password: password);
      _token = auth.accessToken;
      _user = auth.user;
      await _sessionStore.saveSession(token: auth.accessToken, user: auth.user);
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    _setBusy(true);
    try {
      final auth = await authService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      _token = auth.accessToken;
      _user = auth.user;
      await _sessionStore.saveSession(token: auth.accessToken, user: auth.user);
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    final currentToken = _token;
    _token = null;
    _user = null;
    await _sessionStore.clearSession();
    notifyListeners();

    if (currentToken != null && currentToken.isNotEmpty) {
      try {
        await authService.logout(currentToken);
      } catch (_) {
        // Ignore backend logout errors if local session is already cleared.
      }
    }
  }

  Future<void> refreshCurrentUser() async {
    if (!isAuthenticated || _token == null) return;

    try {
      final profile = await profileService.getProfile(_token!);
      final userMap = profile.user;
      final existingRole = _user?.role ?? 'user';

      _user = UserModel(
        id: (userMap['id'] as num?)?.toInt() ?? (_user?.id ?? 0),
        name: (userMap['name'] ?? _user?.name ?? '') as String,
        email: (userMap['email'] ?? _user?.email ?? '') as String,
        role: (userMap['role'] ?? existingRole) as String,
      );

      await _sessionStore.saveSession(token: _token!, user: _user!);
      notifyListeners();
    } catch (_) {
      // Keep stale user cache if refresh fails.
    }
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}
