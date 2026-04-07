import 'api_client_service.dart';
import 'api_config_service.dart';
import 'guardian_preferences_service.dart';
import 'offline_models.dart';

class SyncOperationResult<T> {
  final bool success;
  final T? data;
  final String? error;

  const SyncOperationResult({required this.success, this.data, this.error});
}

class ServerSyncService {
  ServerSyncService._private();

  static final ServerSyncService instance = ServerSyncService._private();

  Future<SyncOperationResult<String>> uploadMetricBatch(CuratedMetricBatch batch) async {
    if (!ApiConfigService.isConfigured) {
      return const SyncOperationResult(success: false, error: 'API base URL is not configured.');
    }

    final childId = batch.childId;
    if (childId == null) {
      return const SyncOperationResult(success: false, error: 'Missing child_id for metric sync.');
    }

    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.metricsEndpoint);
      final response = await ApiClientService.instance.post(
        uri,
        jsonBody: {
          'child_id': childId,
          'avg_blink_rate': batch.averageBlinkRate,
          'avg_distance': batch.averageDistanceCm,
          'strain_events': batch.strainEvents,
          'timestamp': batch.windowEnd.toIso8601String(),
          'screen_time_minutes': batch.screenTimeMinutes,
        },
      );

      if (!response.isSuccess) {
        return SyncOperationResult(
          success: false,
          error: 'Metric sync failed (${response.statusCode}): ${response.rawBody}',
        );
      }

      final data = response.data;
      String remoteId = '';
      if (data is Map<String, dynamic>) {
        final candidate = data['metric_id'] ?? data['id'] ?? data['data']?['metric_id'] ?? data['data']?['id'];
        remoteId = candidate?.toString() ?? '';
      }

      if (remoteId.isEmpty) {
        remoteId = 'remote-${DateTime.now().millisecondsSinceEpoch}';
      }

      return SyncOperationResult(success: true, data: remoteId);
    } catch (e) {
      return SyncOperationResult(success: false, error: 'Metric sync exception: $e');
    }
  }

  Future<SyncOperationResult<GuardianPreferences>> fetchSessionLimits(int childId) async {
    if (!ApiConfigService.isConfigured) {
      return const SyncOperationResult(success: false, error: 'API base URL is not configured.');
    }

    try {
      final uri = ApiConfigService.buildUri(
        ApiConfigService.sessionLimitsEndpoint,
        queryParameters: {'child_id': childId.toString()},
      );
      final response = await ApiClientService.instance.get(uri);

      if (!response.isSuccess) {
        return SyncOperationResult(
          success: false,
          error: 'Session limits fetch failed (${response.statusCode}): ${response.rawBody}',
        );
      }

      Map<String, dynamic>? source;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['data'] is Map<String, dynamic>) {
          source = data['data'] as Map<String, dynamic>;
        } else {
          source = data;
        }
      } else if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        source = data.first as Map<String, dynamic>;
      }

      if (source == null) {
        return const SyncOperationResult(success: false, error: 'No session limits data found in response.');
      }

      final preferences = const GuardianPreferences.defaults().copyWith(
        selectedChildId: childId,
        dailyScreenLimitMinutes: (source['daily_limit_minutes'] as num?)?.toInt() ?? 120,
        monitoringMode: (source['mode'] as String?) ?? 'Moderate',
        isActive: (source['is_active'] as num?)?.toInt() != 0,
        distanceAlertThresholdCm: (source['harmful_distance_threshold'] as num?)?.toDouble() ?? 30,
        criticalDistanceThresholdCm: (source['critical_distance_threshold'] as num?)?.toDouble() ?? 10,
        autoEnforceBreaks: (source['auto_enforce_breaks'] as num?)?.toInt() != 0,
      );

      return SyncOperationResult(success: true, data: preferences);
    } catch (e) {
      return SyncOperationResult(success: false, error: 'Session limits fetch exception: $e');
    }
  }

  Future<SyncOperationResult<void>> upsertSessionLimits(GuardianPreferences preferences) async {
    if (!ApiConfigService.isConfigured) {
      return const SyncOperationResult(success: false, error: 'API base URL is not configured.');
    }

    final childId = preferences.selectedChildId;
    if (childId == null) {
      return const SyncOperationResult(success: false, error: 'Cannot sync session limits without child_id.');
    }

    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.sessionLimitsEndpoint);
      final response = await ApiClientService.instance.put(
        uri,
        jsonBody: {
          'child_id': childId,
          'daily_limit_minutes': preferences.dailyScreenLimitMinutes,
          'mode': preferences.monitoringMode,
          'is_active': preferences.isActive ? 1 : 0,
          'harmful_distance_threshold': preferences.distanceAlertThresholdCm,
          'critical_distance_threshold': preferences.criticalDistanceThresholdCm,
          'auto_enforce_breaks': preferences.autoEnforceBreaks ? 1 : 0,
        },
      );

      if (!response.isSuccess) {
        return SyncOperationResult(
          success: false,
          error: 'Session limits sync failed (${response.statusCode}): ${response.rawBody}',
        );
      }

      return const SyncOperationResult(success: true);
    } catch (e) {
      return SyncOperationResult(success: false, error: 'Session limits sync exception: $e');
    }
  }
}