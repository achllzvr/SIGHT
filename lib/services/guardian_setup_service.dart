import 'guardian_auth_service.dart';

class GuardianActionResult {
  final bool success;
  final String message;

  const GuardianActionResult({required this.success, required this.message});
}

class GuardianSetupService {
  GuardianSetupService._private();

  static final GuardianSetupService instance = GuardianSetupService._private();

  Future<bool> hasGuardianPin() async {
    final pin = await GuardianAuthService.instance.loadFallbackPin();
    return pin != null && pin.length == 4;
  }

  String? validateNewPinInputs(String pin, String confirmPin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return 'PIN must be exactly 4 digits.';
    }

    if (pin != confirmPin) {
      return 'PIN and confirmation do not match.';
    }

    return null;
  }

  Future<GuardianActionResult> createGuardianPin({
    required String pin,
    required String confirmPin,
  }) async {
    final validationError = validateNewPinInputs(pin, confirmPin);
    if (validationError != null) {
      return GuardianActionResult(success: false, message: validationError);
    }

    await GuardianAuthService.instance.saveFallbackPin(pin);
    return const GuardianActionResult(success: true, message: 'Guardian PIN created.');
  }

  Future<GuardianActionResult> changeGuardianPin({
    required String currentPin,
    required String newPin,
    required String confirmNewPin,
  }) async {
    final storedPin = await GuardianAuthService.instance.loadFallbackPin();
    if (storedPin == null) {
      return const GuardianActionResult(success: false, message: 'No guardian PIN is set yet.');
    }

    final isCurrentPinValid = GuardianAuthService.instance.verifyFallbackPin(currentPin, storedPin);
    if (!isCurrentPinValid) {
      return const GuardianActionResult(success: false, message: 'Current PIN is incorrect.');
    }

    final validationError = validateNewPinInputs(newPin, confirmNewPin);
    if (validationError != null) {
      return GuardianActionResult(success: false, message: validationError);
    }

    if (newPin == currentPin) {
      return const GuardianActionResult(success: false, message: 'New PIN must be different from current PIN.');
    }

    await GuardianAuthService.instance.saveFallbackPin(newPin);
    return const GuardianActionResult(success: true, message: 'Guardian PIN updated.');
  }

  Future<GuardianActionResult> verifyPinAccess(String enteredPin) async {
    final storedPin = await GuardianAuthService.instance.loadFallbackPin();
    if (storedPin == null) {
      return const GuardianActionResult(success: false, message: 'Guardian PIN is not configured.');
    }

    final isValid = GuardianAuthService.instance.verifyFallbackPin(enteredPin, storedPin);
    if (!isValid) {
      return const GuardianActionResult(success: false, message: 'Invalid guardian PIN.');
    }

    return const GuardianActionResult(success: true, message: 'Access granted.');
  }
}