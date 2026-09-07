import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service for handling device biometric / fingerprint authentication.
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  /// Check if the device hardware supports biometrics and has enrolled credentials.
  Future<bool> canCheckBiometrics() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// List the biometric types available on the device (fingerprint, face, etc.).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Prompt the user for biometric authentication.
  Future<bool> authenticate({
    String reason = 'Authenticate to access Invest Kinda Right',
  }) async {
    try {
      final can = await canCheckBiometrics();
      if (!can) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Stop any active authentication prompt.
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } on PlatformException catch (_) {
      // Ignored
    }
  }
}
