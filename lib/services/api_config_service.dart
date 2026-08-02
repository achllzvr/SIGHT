class ApiConfigService {
  ApiConfigService._();

  static const String registerGuardianEndpoint = '/api/mobile/guardian/register';
  static const String registerChildEndpoint = '/api/mobile/child/register';
  static const String verifyEmailEndpoint = '/api/mobile/guardian/verify-email';
  static const String resendVerificationEndpoint = '/api/mobile/guardian/resend-verification';
  static const String resetPasswordEndpoint = '/api/mobile/guardian/reset-password';
  static const String updateChildPasswordEndpoint = '/api/mobile/child/{child_id}/password';
  static const String loginChildEndpoint = '/api/mobile/child/login';
  static const String guardianChildrenEndpoint = '/api/mobile/guardian/children';
  static const String sharedLoginEndpoint = '/api/shared/login';

  static const String baseUrl = String.fromEnvironment('SIGHT_API_BASE_URL', defaultValue: '');

  static String metricsBatchEndpoint(int childId) =>
      '/api/mobile/child/$childId/sync/metrics/batch';
  static String metricsEndpoint(int childId) =>
      '/api/mobile/child/$childId/sync/metrics';
  static String sessionLimitsEndpoint(int childId) =>
      '/api/mobile/child/$childId/sync/limits';
  static String petSyncEndpoint(int childId) =>
      '/api/mobile/child/$childId/sync/pet';
  static String calibrationEndpoint(int childId) =>
      '/api/mobile/child/$childId/sync/calibration';

  static bool get isConfigured => baseUrl.trim().isNotEmpty;

  static Uri buildUri(String endpoint, {Map<String, String>? queryParameters}) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final normalizedEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    final uri = Uri.parse(normalizedBase).resolve(normalizedEndpoint);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }
}
