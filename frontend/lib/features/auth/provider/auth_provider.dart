import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/secure_storage.dart';

class AuthUser {
  final String id;
  final String username;
  final String email;

  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final DioClient dioClient;
  final SecureStorage secureStorage;

  AuthUser? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  AuthProvider({required this.dioClient, required this.secureStorage}) {
    _initFromStorage();
  }

  AuthUser? get user => _user;
  AuthUser? get currentUser => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  String get username => _user?.username ?? 'Trader';

  Future<void> _initFromStorage() async {
    final token = await secureStorage.readToken();
    if (token != null) {
      _isLoggedIn = true;
      notifyListeners();
      await fetchCurrentUser();
    }
  }

  Future<Result<AuthUser>> login(
      String usernameOrEmail, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await dioClient.post('/api/v1/auth/login', data: {
        'username': usernameOrEmail,
        'email': usernameOrEmail,
        'password': password,
      });
      final data = response.data as Map<String, dynamic>;
      final token = (data['token'] ?? data['accessToken'] ?? '') as String;
      await secureStorage.saveToken(token);

      // Store credentials locally for fingerprint / biometric authentication
      await secureStorage.saveBiometricCredentials(
        username: usernameOrEmail,
        password: password,
      );

      final user =
          AuthUser.fromJson(data['user'] as Map<String, dynamic>? ?? data);
      _user = user;
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return Success(user);
    } on DioException catch (e) {
      final failure = mapDioError(e);
      _error = failure.message;
      _isLoading = false;
      notifyListeners();
      return Failure(failure);
    }
  }

  /// Perform login using stored biometric credentials after biometric prompt passes.
  Future<Result<AuthUser>> loginWithBiometrics(
      BiometricService biometricService) async {
    final isEnabled = await secureStorage.isBiometricEnabled();
    final creds = await secureStorage.readBiometricCredentials();

    if (!isEnabled || creds == null) {
      return const Failure(AppFailure(
          'No biometric credentials found. Please sign in with password first.'));
    }

    final canAuth = await biometricService.canCheckBiometrics();
    if (!canAuth) {
      return const Failure(AppFailure(
          'Biometrics not available or not enrolled on this device.'));
    }

    final authenticated = await biometricService.authenticate(
      reason: 'Scan fingerprint to log in as ${creds.username}',
    );

    if (!authenticated) {
      return const Failure(AppFailure('Biometric authentication cancelled'));
    }

    return login(creds.username, creds.password);
  }

  Future<Result<AuthUser>> register(
    String username,
    String email,
    String password, {
    String? firstname,
    String? lastname,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await dioClient.post('/api/v1/auth/register', data: {
        'username': username,
        'firstname': firstname ?? username,
        'lastname': lastname ?? '',
        'email': email,
        'password': password,
      });
      final data = response.data as Map<String, dynamic>;
      final token = (data['token'] ?? data['accessToken'] ?? '') as String;
      if (token.isNotEmpty) {
        await secureStorage.saveToken(token);
        await secureStorage.saveBiometricCredentials(
          username: username,
          password: password,
        );
      }
      final user =
          AuthUser.fromJson(data['user'] as Map<String, dynamic>? ?? data);
      _user = user;
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return Success(user);
    } on DioException catch (e) {
      final failure = mapDioError(e);
      _error = failure.message;
      _isLoading = false;
      notifyListeners();
      return Failure(failure);
    }
  }

  Future<void> fetchCurrentUser() async {
    try {
      final response = await dioClient.get('/api/v1/users/getCurrentUser');
      final data = response.data as Map<String, dynamic>;
      _user = AuthUser.fromJson(data);
      notifyListeners();
    } on DioException catch (e) {
      debugPrint('[Auth] fetchCurrentUser error: ${e.message}');
    }
  }

  Future<void> logout() async {
    await secureStorage.deleteToken();
    _user = null;
    _isLoggedIn = false;
    _error = null;
    notifyListeners();
  }
}
