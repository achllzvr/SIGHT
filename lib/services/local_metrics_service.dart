import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'active_child_context_service.dart';
import 'offline_database_service.dart';
import 'offline_models.dart';
import 'server_sync_service.dart';

class LocalMetricsService {
  LocalMetricsService._private();
  static final LocalMetricsService instance = LocalMetricsService._private();

  Timer? _batchTimer;
  Timer? _syncTimer;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await OfflineDatabaseService.instance.initialize();
    await ActiveChildContextService.instance.initialize();
    _initialized = true;

    _batchTimer ??= Timer.periodic(const Duration(minutes: 30), (_) {
      curateThirtyMinuteBatch();
    });

    _syncTimer ??= Timer.periodic(const Duration(minutes: 5), (_) {
      attemptBackgroundSync();
    });
  }

  Future<void> logRawEvent(String type, double value, DateTime timestamp) async {
    await initialize();
    final childId = await ActiveChildContextService.instance.getActiveChildId();
    await OfflineDatabaseService.instance.insertRawEvent(
      LocalMetricEvent(childId: childId, type: type, value: value, timestamp: timestamp),
    );
  }

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
    final measuredWindowMinutes = events.isEmpty
        ? 0
        : max(1, windowEnd.difference(events.first.timestamp).inMinutes);
    final screenTimeMinutes = min(30, measuredWindowMinutes);

    final batch = CuratedMetricBatch(
      childId: childId,
      windowStart: windowStart,
      windowEnd: windowEnd,
      averageBlinkRate: averageFor('blinkRate'),
      averageDistanceCm: averageFor('distanceCm'),
      strainEvents: strainEvents,
      screenTimeMinutes: screenTimeMinutes,
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

  Future<int> attemptBackgroundSync() async {
    await initialize();
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
      return 0;
    }

    final pending = await OfflineDatabaseService.instance.loadPendingBatches();
    if (pending.isEmpty) {
      return 0;
    }

    for (final batch in pending) {
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
      } else {
        await OfflineDatabaseService.instance.markBatchSyncFailed(
          batch.id!,
          retryCount: nextRetryCount,
          error: uploadResult.error ?? 'Unknown metric sync failure.',
        );
      }
    }

    return pending.length;
  }

  Future<void> dispose() async {
    _batchTimer?.cancel();
    _syncTimer?.cancel();
    _batchTimer = null;
    _syncTimer = null;
    _initialized = false;
  }
}