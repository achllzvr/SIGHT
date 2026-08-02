import 'api_client_service.dart';
import 'api_config_service.dart';
import 'gamification_service.dart';
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
      final formattedTimestamp =
          "${batch.windowEnd.year.toString().padLeft(4, '0')}-"
          "${batch.windowEnd.month.toString().padLeft(2, '0')}-"
          "${batch.windowEnd.day.toString().padLeft(2, '0')} "
          "${batch.windowEnd.hour.toString().padLeft(2, '0')}:"
          "${batch.windowEnd.minute.toString().padLeft(2, '0')}:"
          "${batch.windowEnd.second.toString().padLeft(2, '0')}";

      final uri = ApiConfigService.buildUri(ApiConfigService.metricsBatchEndpoint(childId));
      final response = await ApiClientService.instance.post(
        uri,
        jsonBody: {
          'metrics': [
            {
              'timestamp': formattedTimestamp,
              'screen_time_minutes': batch.screenTimeMinutes,
              'avg_blink_rate': batch.averageBlinkRate ?? 0.0,
              'avg_distance': batch.averageDistanceCm ?? 0.0,
              'strain_events': batch.strainEvents,
              'health_score': batch.healthScore ?? 100,
              'coins': batch.coins ?? 0,
            }
          ],
        },
      );

      if (!response.isSuccess) {
        return SyncOperationResult(
          success: false,
          error: 'Metric sync failed (${response.statusCode}): ${response.rawBody}',
        );
      }

      final data = response.data;
      String remoteId = 'remote-${DateTime.now().millisecondsSinceEpoch}';
      if (data is Map<String, dynamic>) {
        final candidate =
            data['metric_id'] ?? data['id'] ?? data['data']?['metric_id'] ?? data['data']?['id'];
        if (candidate != null) remoteId = candidate.toString();
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
      // Prefer shared authenticated read when available; fall back to defaults on failure.
      final uri = ApiConfigService.buildUri('/api/shared/child/$childId/limits');
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
      }

      if (source == null) {
        return const SyncOperationResult(success: false, error: 'No session limits data found.');
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
      final now = DateTime.now();
      final formatted =
          "${now.year.toString().padLeft(4, '0')}-"
          "${now.month.toString().padLeft(2, '0')}-"
          "${now.day.toString().padLeft(2, '0')} "
          "${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}:"
          "${now.second.toString().padLeft(2, '0')}";

      final uri = ApiConfigService.buildUri(ApiConfigService.sessionLimitsEndpoint(childId));
      final response = await ApiClientService.instance.put(
        uri,
        jsonBody: {
          'daily_limit_minutes': preferences.dailyScreenLimitMinutes,
          'mode': preferences.monitoringMode == 'Relaxed' ? 'Relaxed' : 'Strict',
          'harmful_distance_threshold': preferences.distanceAlertThresholdCm,
          'critical_distance_threshold': preferences.criticalDistanceThresholdCm,
          'auto_enforce_breaks': preferences.autoEnforceBreaks,
          'device_timestamp': formatted,
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

  /// Last-write-wins pet sync (D3) — payload matches Laravel MobileApiController::syncPet.
  Future<SyncOperationResult<void>> syncPet(int childId) async {
    if (!ApiConfigService.isConfigured) {
      return const SyncOperationResult(success: false, error: 'API base URL is not configured.');
    }

    try {
      final g = GamificationService.instance;
      final now = DateTime.now();
      final formatted =
          "${now.year.toString().padLeft(4, '0')}-"
          "${now.month.toString().padLeft(2, '0')}-"
          "${now.day.toString().padLeft(2, '0')} "
          "${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}:"
          "${now.second.toString().padLeft(2, '0')}";

      final hp = g.healthScoreNotifier.value;
      final petState = hp >= 70
          ? 'Healthy'
          : hp >= 40
              ? 'Good'
              : hp > 0
                  ? 'Critical'
                  : 'Dead';

      final uri = ApiConfigService.buildUri(ApiConfigService.petSyncEndpoint(childId));
      final response = await ApiClientService.instance.put(
        uri,
        jsonBody: {
          'xp_points': g.coinsNotifier.value,
          'currency': g.coinsNotifier.value,
          'current_streak_days': g.dailyStreakNotifier.value,
          'last_streak_date':
              "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
          'pet_state': petState,
          'device_timestamp': formatted,
        },
      );

      if (!response.isSuccess) {
        return SyncOperationResult(
          success: false,
          error: 'Pet sync failed (${response.statusCode}): ${response.rawBody}',
        );
      }

      return const SyncOperationResult(success: true);
    } catch (e) {
      return SyncOperationResult(success: false, error: 'Pet sync exception: $e');
    }
  }
}
