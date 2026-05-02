import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:lumi/services/api_client_service.dart';
import 'package:lumi/services/api_config_service.dart';
import 'package:lumi/services/connectivity_service.dart';
import 'package:lumi/services/offline_database_service.dart';

import 'active_child_context_service.dart';
import 'offline_models.dart';
import 'server_sync_service.dart';
import 'gamification_service.dart';

class LocalMetricsService {
  LocalMetricsService._private();
  static final LocalMetricsService instance = LocalMetricsService._private();

  Timer? _oneMinuteTimer;
  Timer? _thirtyMinuteSyncTimer;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await OfflineDatabaseService.instance.initialize();
    await ActiveChildContextService.instance.initialize();
    _initialized = true;

    // Per-minute batch creation and raw event reset
    _oneMinuteTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      curateOneMinuteBatch();
    });

    // Every 30 minutes, sync ALL unsynced records for the active user
    _thirtyMinuteSyncTimer ??= Timer.periodic(const Duration(minutes: 30), (_) {
      attemptBackgroundSync();
    });

    if (kDebugMode) {
      debugPrint('[LocalMetricsService] Initialized: 1-min batch timer + 30-min sync timer started');
    }
  }

  Future<void> logRawEvent(String type, double value, DateTime timestamp) async {
    await initialize();
    final childId = await ActiveChildContextService.instance.getActiveChildId();
    await OfflineDatabaseService.instance.insertRawEvent(
      LocalMetricEvent(childId: childId, type: type, value: value, timestamp: timestamp),
    );
  }

  /// Creates a per-minute curated batch from raw events and clears them.
  /// This runs every 60 seconds to maintain a rolling 1-minute window.
  Future<CuratedMetricBatch?> curateOneMinuteBatch() async {
    await initialize();
    final windowEnd = DateTime.now();
    final windowStart = windowEnd.subtract(const Duration(minutes: 1));

    final events = await OfflineDatabaseService.instance.loadRawEventsSince(windowStart);

    if (events.isEmpty) {
      if (kDebugMode) {
        debugPrint('[LocalMetricsService] No raw events in past minute.');
      }
      return null;
    }

    final childId = await ActiveChildContextService.instance.getActiveChildId();

    double? averageFor(String type) {
      final values = events.where((event) => event.type == type).map((event) => event.value).toList(growable: false);
      if (values.isEmpty) {
        return null;
      }
      final total = values.fold<double>(0.0, (sum, value) => sum + value);
      return total / values.length;
    }

    final strainEvents = events.where((event) => event.type == 'strainEvent').length;
    const screenTimeMinutes = 1;

    final batch = CuratedMetricBatch(
      childId: childId,
      windowStart: windowStart,
      windowEnd: windowEnd,
      averageBlinkRate: averageFor('blinkRate'),
      averageDistanceCm: averageFor('distanceCm'),
      strainEvents: strainEvents,
      screenTimeMinutes: screenTimeMinutes,
      healthScore: GamificationService.instance.healthScoreNotifier.value,
      coins: GamificationService.instance.coinsNotifier.value,             
      eventCount: events.length,
      syncState: SyncState.pending,
    );

    final batchId = await OfflineDatabaseService.instance.insertCuratedBatch(batch);

    // Clear raw events up to this window start to avoid duplication
    await OfflineDatabaseService.instance.deleteRawEventsBefore(windowStart);

    if (kDebugMode) {
      debugPrint('[LocalMetricsService] Curated 1-min batch (ID: $batchId): '
          'blink=${batch.averageBlinkRate?.toStringAsFixed(2)}, '
          'distance=${batch.averageDistanceCm?.toStringAsFixed(2)}, '
          'strain=${batch.strainEvents}, events=${batch.eventCount}');
    }

    return batch;
  }

  /// Legacy method for backward compatibility (optional).
  /// Can still be called manually if needed.
  Future<CuratedMetricBatch?> curateThirtyMinuteBatch() async {
    await initialize();
    final windowEnd = DateTime.now();
    final windowStart = windowEnd.subtract(const Duration(minutes: 30));

    final events = await OfflineDatabaseService.instance.loadRawEventsSince(windowStart);
    if (events.isEmpty) {
      return null;
    }

    final childId = await ActiveChildContextService.instance.getActiveChildId();

    double? averageFor(String type) {
      final values = events.where((event) => event.type == type).map((event) => event.value).toList(growable: false);
      if (values.isEmpty) {
        return null;
      }
      final total = values.fold<double>(0.0, (sum, value) => sum + value);
      return total / values.length;
    }

    final strainEvents = events.where((event) => event.type == 'strainEvent').length;
    final measuredWindowMinutes = max(1, windowEnd.difference(events.first.timestamp).inMinutes);
    final screenTimeMinutes = min(30, measuredWindowMinutes);

    final batch = CuratedMetricBatch(
      childId: childId,
      windowStart: windowStart,
      windowEnd: windowEnd,
      averageBlinkRate: averageFor('blinkRate'),
      averageDistanceCm: averageFor('distanceCm'),
      strainEvents: strainEvents,
      screenTimeMinutes: screenTimeMinutes,
      healthScore: GamificationService.instance.healthScoreNotifier.value,
      coins: GamificationService.instance.coinsNotifier.value,             
      eventCount: events.length,
      syncState: SyncState.pending,
    );

    await OfflineDatabaseService.instance.insertCuratedBatch(batch);
    await OfflineDatabaseService.instance.deleteRawEventsBefore(windowStart);
    return batch;
  }

  Future<int> queueForCloudSync(CuratedMetricBatch curatedBatch) async {
    await initialize();
    return OfflineDatabaseService.instance.insertCuratedBatch(curatedBatch);
  }

  /// Syncs ALL unsynced records for the active child every 30 minutes.
  Future<int> attemptBackgroundSync() async {
    await initialize();

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
      if (kDebugMode) {
        debugPrint('[LocalMetricsService] No connectivity; skipping sync.');
      }
      return 0;
    }

    final childId = await ActiveChildContextService.instance.getActiveChildId();
    final pending = await OfflineDatabaseService.instance.loadPendingBatches();

    if (pending.isEmpty) {
      if (kDebugMode) {
        debugPrint('[LocalMetricsService] No pending batches for sync.');
      }
      return 0;
    }

    // Filter batches for the active child only
    final relevantBatches = pending.where((b) => b.childId == childId).toList();
    if (relevantBatches.isEmpty) {
      if (kDebugMode) {
        debugPrint('[LocalMetricsService] No pending batches for child $childId.');
      }
      return 0;
    }

    int successCount = 0;
    int failureCount = 0;

    for (final batch in relevantBatches) {
      if (batch.id == null) {
        continue;
      }

      final nextRetryCount = batch.retryCount + 1;
      await OfflineDatabaseService.instance.markBatchSyncAttempt(batch.id!, retryCount: nextRetryCount);

      final uploadResult = await ServerSyncService.instance.uploadMetricBatch(batch);
      if (uploadResult.success) {
        await OfflineDatabaseService.instance.markBatchSynced(
          batch.id!,
          remoteId: uploadResult.data,
        );
        successCount++;

        if (kDebugMode) {
          debugPrint('[LocalMetricsService] Synced batch ${batch.id}: ${uploadResult.data}');
        }
      } else {
        await OfflineDatabaseService.instance.markBatchSyncFailed(
          batch.id!,
          retryCount: nextRetryCount,
          error: uploadResult.error ?? 'Unknown metric sync failure.',
        );
        failureCount++;

        if (kDebugMode) {
          debugPrint('[LocalMetricsService] Failed to sync batch ${batch.id}: ${uploadResult.error}');
        }
      }
    }

    if (kDebugMode) {
      debugPrint('[LocalMetricsService] Background sync complete: '
          '$successCount succeeded, $failureCount failed out of ${relevantBatches.length} total');
    }

    return successCount;
  }

  Future<void> dispose() async {
    _oneMinuteTimer?.cancel();
    _thirtyMinuteSyncTimer?.cancel();
    _oneMinuteTimer = null;
    _thirtyMinuteSyncTimer = null;
    _initialized = false;

    if (kDebugMode) {
      debugPrint('[LocalMetricsService] Disposed');
    }
  }

  // TODO: Remove after testing/demo purposes to avoid misuse in production
  /// Forces an immediate sync of local metrics to the cloud for testing/demos.
  Future<void> forceSyncNow(int childId) async {
    // 1. Check Connectivity
    if (!await ConnectivityService.instance.isOnline()) {
      throw Exception('No internet connection available. Cannot sync.');
    }

    // 2. Fetch the data we want to sync
    // Assuming we want to sync today's data for the demo.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final batches = await OfflineDatabaseService.instance.loadBatchesForChild(childId, today, tomorrow);

    if (batches.isEmpty) {
      throw Exception('No local metrics found to sync today.');
    }

    final List<Map<String, dynamic>> batchPayload = batches.map((b) {
      
      // Convert DateTime to 'YYYY-MM-DD HH:MM:SS' for Laravel
      final String formattedTimestamp = 
          "${b.windowEnd.year.toString().padLeft(4, '0')}-"
          "${b.windowEnd.month.toString().padLeft(2, '0')}-"
          "${b.windowEnd.day.toString().padLeft(2, '0')} "
          "${b.windowEnd.hour.toString().padLeft(2, '0')}:"
          "${b.windowEnd.minute.toString().padLeft(2, '0')}:"
          "${b.windowEnd.second.toString().padLeft(2, '0')}";

      return {
        'timestamp': formattedTimestamp,
        'screen_time_minutes': b.screenTimeMinutes,
        'avg_blink_rate': b.averageBlinkRate ?? 0.0,
        'avg_distance': b.averageDistanceCm ?? 0.0,
        'strain_events': b.strainEvents,
        'health_score': b.healthScore ?? 100,
        'coins': b.coins ?? 0, 
      };
    }).toList();

    // 4. Send to the Laravel API
    final uri = ApiConfigService.buildUri('/api/mobile/child/$childId/sync/metrics/batch');
    final response = await ApiClientService.instance.post(
      uri,
      jsonBody: {
        'metrics': batchPayload 
      },
    );

    // 5. Handle the response
    if (!response.isSuccess) {
      debugPrint('Sync Error Body: ${response.rawBody}');
      throw Exception('Server rejected the sync request. Code: ${response.statusCode}');
    }

    // Optional: If your OfflineDatabaseService has a method to mark rows as "synced" 
    // to prevent duplicate uploads, you would call it here.
    // e.g., await OfflineDatabaseService.instance.markAsSynced(batches.map((b) => b.id).toList());

    debugPrint('Force sync completely successfully for child ID: $childId');
  }
}