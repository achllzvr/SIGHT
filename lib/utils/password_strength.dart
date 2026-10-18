/// Shared password strength evaluation for parent register / change-password.
class PasswordStrengthResult {
  const PasswordStrengthResult({
    required this.hasMinLength,
    required this.hasLowercase,
    required this.hasUppercase,
    required this.hasNumber,
    required this.hasSymbol,
    required this.matchesConfirm,
  });

  final bool hasMinLength;
  final bool hasLowercase;
  final bool hasUppercase;
  final bool hasNumber;
  final bool hasSymbol;
  final bool matchesConfirm;

  int get complexityScore {
    var score = 0;
    if (hasMinLength) score++;
    if (hasLowercase) score++;
    if (hasUppercase) score++;
    if (hasNumber) score++;
    if (hasSymbol) score++;
    return score;
  }

  bool get isStrongEnough => complexityScore == 5;

  bool get isFullyValid => isStrongEnough && matchesConfirm;

  String get meterLabel {
    if (complexityScore <= 1) return 'Weak';
    if (complexityScore <= 3) return 'Getting stronger';
    if (complexityScore == 4) return 'Almost there';
    return 'Strong';
  }
}

PasswordStrengthResult evaluatePasswordStrength({
  required String password,
  required String confirm,
}) {
  return PasswordStrengthResult(
    hasMinLength: password.length >= 8,
    hasLowercase: RegExp(r'[a-z]').hasMatch(password),
    hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
    hasNumber: RegExp(r'[0-9]').hasMatch(password),
    hasSymbol: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    matchesConfirm: password.isNotEmpty && password == confirm,
  );
}

String? passwordStrengthErrorMessage(PasswordStrengthResult result) {
  if (!result.hasMinLength) return 'Password must be at least 8 characters.';
  if (!result.hasLowercase) return 'Add a lowercase letter (a–z).';
  if (!result.hasUppercase) return 'Add an uppercase letter (A–Z).';
  if (!result.hasNumber) return 'Add a number (0–9).';
  if (!result.hasSymbol) return 'Add a symbol (!@#\$…).';
  if (!result.matchesConfirm) return 'Passwords don’t match.';
  return null;
}
