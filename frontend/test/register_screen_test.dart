import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invest_kinda_right/features/auth/model/auth_models.dart';
import 'package:invest_kinda_right/features/auth/provider/auth_provider.dart';
import 'package:invest_kinda_right/features/auth/screens/register_screen.dart';
import 'package:invest_kinda_right/core/network/dio_client.dart';
import 'package:invest_kinda_right/core/storage/secure_storage.dart';
import 'package:invest_kinda_right/core/websocket/market_ws_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('Register API Model Tests', () {
    test('RegisterRequest serializes all 5 backend fields correctly', () {
      const request = RegisterRequest(
        username: 'trader123',
        firstname: 'John',
        lastname: 'Doe',
        email: 'john.doe@example.com',
        password: 'password123',
      );

      final json = request.toJson();
      expect(json['username'], 'trader123');
      expect(json['firstname'], 'John');
      expect(json['lastname'], 'Doe');
      expect(json['email'], 'john.doe@example.com');
      expect(json['password'], 'password123');
    });

    test('AuthResponse parses backend register response with userId and message', () {
      final backendResponse = {
        'userId': 42,
        'username': 'trader123',
        'message': 'User registered successfully',
      };

      final response = AuthResponse.fromJson(backendResponse);
      expect(response.userId, 42);
      expect(response.username, 'trader123');
      expect(response.message, 'User registered successfully');
      expect(response.token, isNull);
      expect(response.hasToken, isFalse);
    });

    test('AuthResponse parses backend login response with token', () {
      final backendResponse = {
        'userId': 42,
        'username': 'trader123',
        'token': 'jwt-sample-token',
        'message': 'Login successful',
      };

      final response = AuthResponse.fromJson(backendResponse);
      expect(response.userId, 42);
      expect(response.token, 'jwt-sample-token');
      expect(response.hasToken, isTrue);
    });
  });

  group('RegisterScreen Widget Tests', () {
    testWidgets('Renders all fields required by backend API and confirm password', (tester) async {
      const storage = FlutterSecureStorage();
      const secureStorage = SecureStorage(storage);
      final dioClient = DioClient(secureStorage: secureStorage);
      final authProvider = AuthProvider(
        dioClient: dioClient,
        secureStorage: secureStorage,
      );
      final wsService = MarketWsService(secureStorage: secureStorage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            Provider<DioClient>.value(value: dioClient),
            ChangeNotifierProvider<MarketWsService>.value(value: wsService),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      // Verify all fields are present
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsOneWidget);

      // Scroll into view and tap submit button with empty form to trigger validations
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      // Verify validation errors appear
      expect(find.text('First name required'), findsOneWidget);
      expect(find.text('Last name required'), findsOneWidget);
      expect(find.text('Username is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
    });

    testWidgets('Enforces min 8 character password and matching confirm password', (tester) async {
      const storage = FlutterSecureStorage();
      const secureStorage = SecureStorage(storage);
      final dioClient = DioClient(secureStorage: secureStorage);
      final authProvider = AuthProvider(
        dioClient: dioClient,
        secureStorage: secureStorage,
      );
      final wsService = MarketWsService(secureStorage: secureStorage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            Provider<DioClient>.value(value: dioClient),
            ChangeNotifierProvider<MarketWsService>.value(value: wsService),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      // Enter short password (6 chars, which backend rejects with @Size(min=8))
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), '123456');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'different');

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
