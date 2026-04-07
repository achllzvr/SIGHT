import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class GuardianAuthService {
  GuardianAuthService._private();

  static final GuardianAuthService instance = GuardianAuthService._private();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _guardianPinKey = 'guardian_override_pin';

  Future<bool> canAuthenticate() async {
    final bool isDeviceSupported = await _localAuth.isDeviceSupported();
    if (!isDeviceSupported) {
      return false;
    }

    return _localAuth.canCheckBiometrics;
  }

  Future<bool> authenticateWithBiometrics() async {
    final bool isAvailable = await canAuthenticate();
    if (!isAvailable) {
      return false;
    }

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Guardian Override Required to unlock SIGHT.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  bool verifyFallbackPin(String enteredPin, String storedPin) {
    return enteredPin.length == 4 && storedPin.length == 4 && enteredPin == storedPin;
  }

  Future<String?> loadFallbackPin() async {
    return _storage.read(key: _guardianPinKey);
  }

  Future<void> saveFallbackPin(String pin) async {
    final isValid = RegExp(r'^\d{4}$').hasMatch(pin);
    if (!isValid) {
      throw ArgumentError('Guardian PIN must be exactly 4 digits.');
    }

    await _storage.write(key: _guardianPinKey, value: pin);
  }
}