import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../model/auth_models.dart';

/// Pure Dio layer for all auth-related endpoints.
class AuthApi {
  final DioClient _client;

  const AuthApi(this._client);

  // ── POST /api/v1/auth/login ───────────────────────────────────────────────

  Future<Result<AuthResponse>> login(LoginRequest request) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: request.toJson(),
      );
      return Success(AuthResponse.fromJson(response.data!));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return const Failure(UnknownFailure('Unexpected error during login.'));
    }
  }

  // ── POST /api/v1/auth/register ───────────────────────────────────────────

  Future<Result<AuthResponse>> register(RegisterRequest request) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: request.toJson(),
      );
      return Success(AuthResponse.fromJson(response.data!));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return const Failure(UnknownFailure('Unexpected error during registration.'));
    }
  }

  // ── GET /api/v1/users/getCurrentUser ────────────────────────────────────

  Future<Result<UserProfile>> getCurrentUser() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/users/getCurrentUser',
      );
      return Success(UserProfile.fromJson(response.data!));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return const Failure(UnknownFailure('Failed to load user profile.'));
    }
  }
}

