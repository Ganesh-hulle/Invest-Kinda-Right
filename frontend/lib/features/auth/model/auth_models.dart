/// Auth data models for the IKR app.
///
/// Covers:
///  - [LoginRequest]    → POST /api/v1/auth/login
///  - [RegisterRequest] → POST /api/v1/auth/register
///  - [AuthResponse]    → wrapper around the returned JWT
///  - [UserProfile]     → GET  /api/v1/users/getCurrentUser
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };
}

class RegisterRequest {
  final String username;
  final String firstname;
  final String lastname;
  final String email;
  final String password;

  const RegisterRequest({
    required this.username,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'password': password,
      };
}

class AuthResponse {
  final String token;

  const AuthResponse({required this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final t = (json['token'] ?? json['accessToken'] ?? '') as String;
    return AuthResponse(token: t);
  }
}

class UserProfile {
  final int id;
  final String username;
  final String firstname;
  final String lastname;
  final String email;

  const UserProfile({
    required this.id,
    required this.username,
    required this.firstname,
    required this.lastname,
    required this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] as String?) ?? '',
      firstname: (json['firstname'] as String?) ?? '',
      lastname: (json['lastname'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
    );
  }

  /// Display name used across the app.
  String get displayName => '$firstname $lastname'.trim();
}

