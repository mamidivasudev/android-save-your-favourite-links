/// Service for handling biometric and PIN authentication
/// Path: lib/services/auth_service.dart
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';

class AuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAuthAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticate({required String reason}) async {
    try {
      if (!await isAuthAvailable()) return true; // Device unsupported, fail open

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == auth_error.lockedOut || e.code == auth_error.permanentlyLockedOut) {
        // User is locked out of biometrics — maybe they should use PIN or wait
        // Defaulting to false blocks access, which is safer.
        return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticateForLink() async {
    return authenticate(reason: 'Authenticate to view locked link');
  }

  static Future<bool> authenticateForExport() async {
    return authenticate(reason: 'Authenticate to export links');
  }
}

