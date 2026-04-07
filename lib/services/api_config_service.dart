class ApiConfigService {
  ApiConfigService._();

  static const String baseUrl = String.fromEnvironment('SIGHT_API_BASE_URL', defaultValue: '');
  static const String metricsEndpoint = String.fromEnvironment(
    'SIGHT_METRICS_ENDPOINT',
    defaultValue: '/api/mobile/eye-health-metrics',
  );
  static const String sessionLimitsEndpoint = String.fromEnvironment(
    'SIGHT_SESSION_LIMITS_ENDPOINT',
    defaultValue: '/api/mobile/session-limits',
  );

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