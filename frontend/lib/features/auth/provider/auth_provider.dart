import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
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
