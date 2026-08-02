import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lumi/services/api_client_service.dart';
import 'package:lumi/services/api_config_service.dart';
import 'package:lumi/services/connectivity_service.dart';
import 'package:lumi/services/offline_database_service.dart';

import 'active_child_context_service.dart';
import 'guardian_preferences_service.dart';
import 'offline_models.dart';
import 'server_sync_service.dart';
import 'gamification_service.dart';
import 'watch_tracking_session.dart';

class LocalMetricsService {
  LocalMetricsService._private();
  static final LocalMetricsService instance = LocalMetricsService._private();

  Timer? _oneMinuteTimer;
  Timer? _thirtyMinuteSyncTimer;
  Timer? _rawEventFlushTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _initialized = false;
  int _syncBackoffSeconds = 30;
  static const int _maxBackoffSeconds = 30 * 60;

  static const _lastSyncPrefsKey = 'local_metrics_last_successful_sync_at';

  /// Pending raw events coalesced before SQLite write (T3).
  final List<LocalMetricEvent> _rawEventBuffer = [];

  /// Last time any metric batch synced successfully (local + cloud).
  final ValueNotifier<DateTime?> lastSuccessfulSyncAt = ValueNotifier<DateTime?>(null);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await OfflineDatabaseService.instance.initialize();
    await ActiveChildContextService.instance.initialize();
    await _loadLastSyncTimestamp();
    _initialized = true;

    // Per-minute batch creation and raw event reset
    _oneMinuteTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      curateOneMinuteBatch();
    });

    // Coalesce raw SQLite writes every 2s (T3)
    _rawEventFlushTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_flushRawEventBuffer());
    });

    // Connectivity-triggered sync + periodic backoff (D4)
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) unawaited(attemptBackgroundSync());
    });

    _thirtyMinuteSyncTimer ??= Timer.periodic(const Duration(minutes: 30), (_) {
      attemptBackgroundSync();
    });

    if (kDebugMode) {
      debugPrint('[LocalMetricsService] Initialized: batch + connectivity sync + raw flush');
    }
  }

  Future<void> _loadLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncPrefsKey);
    if (raw != null) {
      lastSuccessfulSyncAt.value = DateTime.tryParse(raw);
    }
  }

  Future<void> _recordSuccessfulSync() async {
    final now = DateTime.now();
    lastSuccessfulSyncAt.value = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncPrefsKey, now.toIso8601String());
  }

  Future<void> logRawEvent(String type, double value, DateTime timestamp) async {
    await initialize();
    final childId = await ActiveChildContextService.instance.getActiveChildId();
    _rawEventBuffer.add(
      LocalMetricEvent(childId: childId, type: type, value: value, timestamp: timestamp),
    );
    if (_rawEventBuffer.length >= 40) {
      await _flushRawEventBuffer();
    }
  }

  Future<void> _flushRawEventBuffer() async {
    if (_rawEventBuffer.isEmpty) return;
    final batch = List<LocalMetricEvent>.from(_rawEventBuffer);
    _rawEventBuffer.clear();
    for (final event in batch) {
      await OfflineDatabaseService.instance.insertRawEvent(event);
    }
  }

  /// Creates a per-minute curated batch from raw events and clears them.
  /// Screen time counts only while Watch Area is active (D2).
  /// Strain = distance samples below guardian harmful threshold (D6).
  Future<CuratedMetricBatch?> curateOneMinuteBatch() async {
    await initialize();
    await _flushRawEventBuffer();
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
    final prefs = await GuardianPreferencesService.instance.loadPreferences();
    final harmfulCm = prefs.distanceAlertThresholdCm;

    double? averageFor(String type) {
      final values = events.where((event) => event.type == type).map((event) => event.value).toList(growable: false);
      if (values.isEmpty) {
        return null;
      }
      final total = values.fold<double>(0.0, (sum, value) => sum + value);
      return total / values.length;
    }

    final strainEvents = events
        .where((e) => e.type == 'distanceCm' && e.value > 0 && e.value < harmfulCm)
        .length;
    final screenTimeMinutes = WatchTrackingSession.instance.active.value ? 1 : 0;

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
          'strain=${batch.strainEvents}, watchScreen=$screenTimeMinutes, events=${batch.eventCount}');
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
      if (childId != null) {
        await ServerSyncService.instance.syncPet(childId);
      }
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
        await _recordSuccessfulSync();

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

    if (childId != null) {
      await ServerSyncService.instance.syncPet(childId);
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
    _rawEventFlushTimer?.cancel();
    await _connectivitySub?.cancel();
    await _flushRawEventBuffer();
    _oneMinuteTimer = null;
    _thirtyMinuteSyncTimer = null;
    _rawEventFlushTimer = null;
    _connectivitySub = null;
    _initialized = false;

    if (kDebugMode) {
      debugPrint('[LocalMetricsService] Disposed');
    }
  }

  // TODO: Remove after testing/demo purposes to avoid misuse in production
  /// Forces an immediate sync of all unsynced local metrics for [childId] (all days).
  Future<void> forceSyncNow(int childId) async {
    if (!await ConnectivityService.instance.isOnline()) {
      throw Exception('No internet connection available. Cannot sync.');
    }

    final batches = await OfflineDatabaseService.instance.loadPendingBatchesForChild(childId);

    if (batches.isEmpty) {
      final pet = await ServerSyncService.instance.syncPet(childId);
      if (!pet.success) {
        throw Exception(pet.error ?? 'Nothing to sync.');
      }
      await _recordSuccessfulSync();
      return;
    }

    final List<Map<String, dynamic>> batchPayload = batches.map((b) {
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

    final uri = ApiConfigService.buildUri(ApiConfigService.metricsBatchEndpoint(childId));
    final response = await ApiClientService.instance.post(
      uri,
      jsonBody: {
        'metrics': batchPayload,
      },
    );

    if (!response.isSuccess) {
      debugPrint('Sync Error Body: ${response.rawBody}');
      throw Exception('Server rejected the sync request. Code: ${response.statusCode}');
    }

    for (final batch in batches) {
      if (batch.id != null) {
        await OfflineDatabaseService.instance.markBatchSynced(batch.id!);
      }
    }

    await ServerSyncService.instance.syncPet(childId);
    await _recordSuccessfulSync();
    debugPrint('Force sync completed for child ID: $childId (${batches.length} batches)');
  }

  /// Summarizes pending/failed curated batches for UI status pills.
  Future<CloudSyncStatus> getCloudSyncStatus({int? childId}) async {
    final pending = await OfflineDatabaseService.instance.loadPendingBatches();
    final scoped = childId == null
        ? pending
        : pending.where((b) => b.childId == childId).toList(growable: false);

    final failedCount = scoped.where((b) => b.syncState == SyncState.failed).length;
    final needsSyncCount = scoped.length;

    if (failedCount > 0) {
      return CloudSyncStatus(kind: CloudSyncKind.failed, pendingCount: needsSyncCount, failedCount: failedCount);
    }
    if (needsSyncCount > 0) {
      return CloudSyncStatus(kind: CloudSyncKind.needsSync, pendingCount: needsSyncCount, failedCount: 0);
    }
    return const CloudSyncStatus(kind: CloudSyncKind.synced, pendingCount: 0, failedCount: 0);
  }
}

enum CloudSyncKind { synced, needsSync, failed }

class CloudSyncStatus {
  final CloudSyncKind kind;
  final int pendingCount;
  final int failedCount;

  const CloudSyncStatus({
    required this.kind,
    required this.pendingCount,
    required this.failedCount,
  });

  String get label {
    switch (kind) {
      case CloudSyncKind.synced:
        return 'Synced';
      case CloudSyncKind.needsSync:
        return 'Needs sync ($pendingCount)';
      case CloudSyncKind.failed:
        return 'Sync failed';
    }
  }
}