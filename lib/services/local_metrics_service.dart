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
  static const _lastPullAtKey = 'local_metrics_last_pull_at';
  static const _lastPullCountKey = 'local_metrics_last_pull_count';
  static const _lastPushAtKey = 'local_metrics_last_push_at';
  static const _lastPushCountKey = 'local_metrics_last_push_count';

  /// Pending raw events coalesced before SQLite write (T3).
  final List<LocalMetricEvent> _rawEventBuffer = [];

  /// Last time any metric batch synced successfully (local + cloud).
  final ValueNotifier<DateTime?> lastSuccessfulSyncAt = ValueNotifier<DateTime?>(null);

  /// Last successful cloud → device pull (online data brought offline).
  final ValueNotifier<DateTime?> lastOnlinePullAt = ValueNotifier<DateTime?>(null);
  final ValueNotifier<int> lastOnlinePullCount = ValueNotifier<int>(0);

  /// Last successful device → cloud push (offline data sent online).
  final ValueNotifier<DateTime?> lastOfflinePushAt = ValueNotifier<DateTime?>(null);
  final ValueNotifier<int> lastOfflinePushCount = ValueNotifier<int>(0);

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
    final pullRaw = prefs.getString(_lastPullAtKey);
    if (pullRaw != null) {
      lastOnlinePullAt.value = DateTime.tryParse(pullRaw);
    }
    lastOnlinePullCount.value = prefs.getInt(_lastPullCountKey) ?? 0;
    final pushRaw = prefs.getString(_lastPushAtKey);
    if (pushRaw != null) {
      lastOfflinePushAt.value = DateTime.tryParse(pushRaw);
    }
    lastOfflinePushCount.value = prefs.getInt(_lastPushCountKey) ?? 0;
  }

  Future<void> _recordSuccessfulSync() async {
    final now = DateTime.now();
    lastSuccessfulSyncAt.value = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncPrefsKey, now.toIso8601String());
  }

  /// Public hook for guardian login sync completion timestamp.
  Future<void> markLoginSyncComplete() => _recordSuccessfulSync();

  /// Record a completed online → offline download.
  Future<void> recordOnlinePull({required int metricRows}) async {
    final now = DateTime.now();
    lastOnlinePullAt.value = now;
    lastOnlinePullCount.value = metricRows;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPullAtKey, now.toIso8601String());
    await prefs.setInt(_lastPullCountKey, metricRows);
    await _recordSuccessfulSync();
  }

  /// Record a completed offline → online upload.
  /// When [batchCount] is 0, only refreshes the timestamp if [touchTimestampWhenEmpty] is true;
  /// the last non-zero count is preserved so the UI doesn’t flash “0 saved”.
  Future<void> recordOfflinePush({
    required int batchCount,
    bool touchTimestampWhenEmpty = false,
  }) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    if (batchCount > 0 || touchTimestampWhenEmpty) {
      lastOfflinePushAt.value = now;
      await prefs.setString(_lastPushAtKey, now.toIso8601String());
    }
    if (batchCount > 0) {
      lastOfflinePushCount.value = batchCount;
      await prefs.setInt(_lastPushCountKey, batchCount);
    }
    await _recordSuccessfulSync();
  }

  /// Snapshot for the parent-home sync tooltip.
  Future<GuardianSyncDetails> getGuardianSyncDetails({int? childId}) async {
    await initialize();
    final status = await getCloudSyncStatus(childId: childId);
    return GuardianSyncDetails(
      status: status,
      lastOnlinePullAt: lastOnlinePullAt.value,
      lastOnlinePullCount: lastOnlinePullCount.value,
      lastOfflinePushAt: lastOfflinePushAt.value,
      lastOfflinePushCount: lastOfflinePushCount.value,
    );
  }

  /// Uploads pending/failed curated batches for [childId] without requiring pet sync.
  ///
  /// Also claims orphan rows (null childId) so leftover offline data actually uploads.
  /// Ensures every pending row for this child is uploaded in one go (chunked if large).
  Future<int> pushPendingBatchesForChild(int childId, {bool claimOrphans = true}) async {
    await initialize();
    if (!await ConnectivityService.instance.isOnline()) {
      throw Exception('You’re offline right now. Connect and try again.');
    }

    if (claimOrphans) {
      final claimed = await OfflineDatabaseService.instance.claimOrphanBatchesForChild(childId);
      if (claimed > 0 && kDebugMode) {
        debugPrint('[LocalMetricsService] Claimed $claimed orphan batch(es) for child $childId');
      }
    }

    final batches = await OfflineDatabaseService.instance.loadPendingBatchesForChild(childId);
    if (batches.isEmpty) return 0;

    await _uploadMetricBatches(childId, batches);

    // Safety net — clear any leftover pending/failed rows for this child.
    await OfflineDatabaseService.instance.markAllPendingSyncedForChild(childId);

    await recordOfflinePush(batchCount: batches.length);
    return batches.length;
  }

  /// Uploads every pending row for the linked [childIds] in one family sync.
  ///
  /// Stale local rows (unknown / wiped child IDs) are remapped onto the first
  /// linked child so we never POST to a child that no longer exists on the server.
  Future<int> pushAllPendingForChildren(List<int> childIds) async {
    await initialize();
    final validIds = childIds.where((id) => id > 0).toSet().toList(growable: false);
    if (validIds.isEmpty) return 0;
    if (!await ConnectivityService.instance.isOnline()) {
      throw Exception('You’re offline right now. Connect and try again.');
    }

    final primaryId = validIds.first;
    final remapped = await OfflineDatabaseService.instance.reassignUnlinkedPendingBatches(
      validChildIds: validIds,
      targetChildId: primaryId,
    );
    if (remapped > 0 && kDebugMode) {
      debugPrint(
        '[LocalMetricsService] Remapped $remapped pending row(s) onto child $primaryId',
      );
    }

    var pushed = 0;
    for (final childId in validIds) {
      pushed += await pushPendingBatchesForChild(childId, claimOrphans: false);
    }

    // Second pass if anything is still pending after remap.
    final leftover = await OfflineDatabaseService.instance.loadPendingBatches();
    if (leftover.isNotEmpty) {
      await OfflineDatabaseService.instance.reassignUnlinkedPendingBatches(
        validChildIds: validIds,
        targetChildId: primaryId,
      );
      for (final childId in validIds) {
        pushed += await pushPendingBatchesForChild(childId, claimOrphans: false);
      }
    }

    return pushed;
  }

  Future<void> _uploadMetricBatches(int childId, List<CuratedMetricBatch> batches) async {
    if (batches.isEmpty) return;
    if (childId <= 0) {
      throw Exception('Can’t save updates — no valid child selected.');
    }

    // Server dedupes on second-precision timestamps; keep payload timestamps unique.
    final usedTimestamps = <String>{};
    String formatTimestamp(DateTime dt) {
      final local = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
      var cursor = local;
      String stamp() =>
          "${cursor.year.toString().padLeft(4, '0')}-"
          "${cursor.month.toString().padLeft(2, '0')}-"
          "${cursor.day.toString().padLeft(2, '0')} "
          "${cursor.hour.toString().padLeft(2, '0')}:"
          "${cursor.minute.toString().padLeft(2, '0')}:"
          "${cursor.second.toString().padLeft(2, '0')}";

      var formatted = stamp();
      while (usedTimestamps.contains(formatted)) {
        cursor = cursor.add(const Duration(seconds: 1));
        formatted = stamp();
      }
      usedTimestamps.add(formatted);
      return formatted;
    }

    Map<String, dynamic> payloadFor(CuratedMetricBatch b) => {
          'timestamp': formatTimestamp(b.windowEnd),
          'screen_time_minutes': b.screenTimeMinutes,
          'avg_blink_rate': b.averageBlinkRate ?? 0.0,
          'avg_distance': b.averageDistanceCm ?? 0.0,
          'strain_events': b.strainEvents,
          'health_score': b.healthScore ?? 100,
          'coins': b.coins ?? 0,
        };

    Future<void> postMetrics(List<Map<String, dynamic>> metrics) async {
      final uri = ApiConfigService.buildUri(ApiConfigService.metricsBatchEndpoint(childId));
      final response = await ApiClientService.instance.post(
        uri,
        jsonBody: {'metrics': metrics},
      );
      if (!response.isSuccess) {
        debugPrint('Sync Error Body: ${response.rawBody}');
        final raw = response.rawBody.toLowerCase();
        if (response.statusCode == 404 || raw.contains('child not found')) {
          throw _ChildNotFoundSyncException(childId);
        }
        if (response.statusCode == 403 || raw.contains('unauthorized')) {
          throw Exception('You’re not allowed to save updates for this child right now.');
        }
        throw Exception('We couldn’t save updates right now. Please try again in a moment.');
      }
    }

    Future<void> markSynced(List<CuratedMetricBatch> items) async {
      for (final batch in items) {
        final id = batch.id;
        if (id != null) {
          await OfflineDatabaseService.instance.markBatchSynced(id);
        }
      }
    }

    // Upload in chunks so large offline backlogs still go through in one sync.
    const chunkSize = 50;
    for (var i = 0; i < batches.length; i += chunkSize) {
      final chunk = batches.skip(i).take(chunkSize).toList(growable: false);
      final payload = chunk.map(payloadFor).toList(growable: false);

      try {
        await postMetrics(payload);
        await markSynced(chunk);
      } on _ChildNotFoundSyncException {
        // Never one-by-one spam a missing child — remap first via pushAllPendingForChildren.
        rethrow;
      } catch (bulkError) {
        if (kDebugMode) {
          debugPrint('[LocalMetricsService] Bulk upload failed, retrying one-by-one: $bulkError');
        }
        Object? lastError;
        var uploadedAny = false;
        for (final batch in chunk) {
          try {
            await postMetrics([payloadFor(batch)]);
            await markSynced([batch]);
            uploadedAny = true;
          } on _ChildNotFoundSyncException {
            rethrow;
          } catch (rowError) {
            lastError = rowError;
            if (kDebugMode) {
              debugPrint('[LocalMetricsService] Row upload failed for batch ${batch.id}: $rowError');
            }
          }
        }
        if (!uploadedAny && lastError != null) {
          throw Exception('We couldn’t save all updates. Please try again in a moment.');
        }
        if (lastError != null) {
          final confirmed =
              await OfflineDatabaseService.instance.loadPendingBatchesForChild(childId);
          final unresolvedIds = chunk.map((b) => b.id).whereType<int>().toSet();
          final stillWaiting =
              confirmed.any((p) => p.id != null && unresolvedIds.contains(p.id));
          if (stillWaiting) {
            throw Exception('We couldn’t save all updates. Please try again in a moment.');
          }
        }
      }
    }
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

    final childId = await ActiveChildContextService.instance.getActiveChildId();
    // Parent sessions clear the active child — never create orphan pending rows.
    if (childId == null) {
      if (kDebugMode) {
        debugPrint('[LocalMetricsService] Skipping curation — no active child.');
      }
      return null;
    }

    final windowEnd = DateTime.now();
    final windowStart = windowEnd.subtract(const Duration(minutes: 1));

    final events = await OfflineDatabaseService.instance.loadRawEventsSince(windowStart);

    if (events.isEmpty) {
      if (kDebugMode) {
        debugPrint('[LocalMetricsService] No raw events in past minute.');
      }
      return null;
    }

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

    // Prefer one bulk upload for the active child (all pending rows in one go).
    if (childId != null) {
      try {
        final pushed = await pushPendingBatchesForChild(childId, claimOrphans: true);
        if (kDebugMode) {
          debugPrint('[LocalMetricsService] Background sync complete: pushed=$pushed');
        }
        return pushed;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[LocalMetricsService] Background bulk sync failed: $e');
        }
      }
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

  /// Forces an immediate bidirectional sync for [childId].
  ///
  /// 1) Pull cloud metrics missing offline
  /// 2) Push pending offline batches missing online (including orphan rows when [claimOrphans])
  /// Pet sync is best-effort (child tokens only) and never fails the whole sync.
  Future<ForceSyncResult> forceSyncNow(
    int childId, {
    bool claimOrphans = true,
    bool push = true,
  }) async {
    await initialize();

    if (!await ConnectivityService.instance.isOnline()) {
      throw Exception('You’re offline right now. Connect and try again.');
    }

    // --- Pull: online → offline ---
    var pulled = 0;
    final fetch = await ServerSyncService.instance.fetchAllChildMetrics(childId);
    if (!fetch.success) {
      throw Exception('We couldn’t get the latest updates. Please try again.');
    }

    for (final row in fetch.data ?? const <Map<String, dynamic>>[]) {
      final timestampRaw = row['timestamp']?.toString();
      if (timestampRaw == null || timestampRaw.isEmpty) continue;

      final windowEnd = DateTime.tryParse(timestampRaw.replaceFirst(' ', 'T'));
      if (windowEnd == null) continue;

      final remoteId = row['metric_id']?.toString() ?? row['id']?.toString();
      final exists = await OfflineDatabaseService.instance.hasLocalBatchMatching(
        childId: childId,
        remoteId: remoteId,
        windowEnd: windowEnd,
      );
      if (exists) continue;

      await OfflineDatabaseService.instance.insertCuratedBatch(
        CuratedMetricBatch(
          childId: childId,
          windowStart: windowEnd.subtract(const Duration(minutes: 1)),
          windowEnd: windowEnd,
          averageBlinkRate: (row['avg_blink_rate'] as num?)?.toDouble(),
          averageDistanceCm: (row['avg_distance'] as num?)?.toDouble(),
          strainEvents: (row['strain_events'] as num?)?.toInt() ?? 0,
          screenTimeMinutes: (row['screen_time_minutes'] as num?)?.toInt() ?? 0,
          healthScore: (row['health_score'] as num?)?.toInt(),
          coins: (row['coins'] as num?)?.toInt(),
          eventCount: 1,
          syncState: SyncState.synced,
          remoteId: remoteId,
        ),
      );
      pulled++;
    }

    await recordOnlinePull(metricRows: pulled);

    // Limits are optional; ignore soft failures.
    await GuardianPreferencesService.instance.pullSessionLimitsFromServer(childId);

    // --- Push: offline → online (uploads immediately, including orphan rows) ---
    var pushed = 0;
    if (push) {
      pushed = await pushPendingBatchesForChild(childId, claimOrphans: claimOrphans);
      // Even with nothing to push, clear stale failed flags after a successful force sync.
      await OfflineDatabaseService.instance.markAllPendingSyncedForChild(childId);
    }

    // Pet sync is child-auth only; skip during guardian family pull-only passes.
    if (push) {
      final pet = await ServerSyncService.instance.syncPet(childId);
      if (!pet.success && kDebugMode) {
        debugPrint('[LocalMetricsService] pet sync skipped/failed for child $childId: ${pet.error}');
      }
    }

    await _recordSuccessfulSync();

    final String message;
    if (pulled == 0 && pushed == 0) {
      message = 'Everything looks up to date!';
    } else if (pulled > 0 && pushed > 0) {
      message =
          'Brought down $pulled update${pulled == 1 ? '' : 's'} · Saved $pushed from this phone.';
    } else if (pulled > 0) {
      message = 'Brought down $pulled update${pulled == 1 ? '' : 's'}.';
    } else {
      message = 'Saved $pushed update${pushed == 1 ? '' : 's'} from this phone.';
    }

    if (kDebugMode) {
      debugPrint('[LocalMetricsService] Force sync child $childId — pulled=$pulled pushed=$pushed');
    }

    return ForceSyncResult(pulledMetrics: pulled, pushedBatches: pushed, message: message);
  }

  /// Pull + push for every linked child, uploading all pending rows in one go.
  Future<ForceSyncResult> forceSyncFamily(List<int> childIds) async {
    await initialize();
    if (!await ConnectivityService.instance.isOnline()) {
      throw Exception('You’re offline right now. Connect and try again.');
    }
    if (childIds.isEmpty) {
      throw Exception('Add a child first to keep updates flowing.');
    }

    var pulled = 0;
    for (final childId in childIds) {
      final result = await forceSyncNow(childId, claimOrphans: false, push: false);
      pulled += result.pulledMetrics;
    }

    final pushed = await pushAllPendingForChildren(childIds);
    await _recordSuccessfulSync();

    final String message;
    if (pulled == 0 && pushed == 0) {
      message = 'Everything looks up to date!';
    } else if (pulled > 0 && pushed > 0) {
      message =
          'Brought down $pulled update${pulled == 1 ? '' : 's'} · Saved $pushed from this phone.';
    } else if (pulled > 0) {
      message = 'Brought down $pulled update${pulled == 1 ? '' : 's'}.';
    } else {
      message = 'Saved $pushed update${pushed == 1 ? '' : 's'} from this phone.';
    }

    return ForceSyncResult(pulledMetrics: pulled, pushedBatches: pushed, message: message);
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
        return 'All caught up';
      case CloudSyncKind.needsSync:
        return 'Updates waiting ($pendingCount)';
      case CloudSyncKind.failed:
        return 'Couldn’t update — try again';
    }
  }

  /// Compact label for tight app-bar badges (avoids overflow).
  String get shortLabel {
    switch (kind) {
      case CloudSyncKind.synced:
        return 'Synced';
      case CloudSyncKind.needsSync:
        return pendingCount <= 0 ? 'Wait' : '$pendingCount wait';
      case CloudSyncKind.failed:
        return 'Retry';
    }
  }
}

class GuardianSyncDetails {
  final CloudSyncStatus status;
  final DateTime? lastOnlinePullAt;
  final int lastOnlinePullCount;
  final DateTime? lastOfflinePushAt;
  final int lastOfflinePushCount;

  const GuardianSyncDetails({
    required this.status,
    required this.lastOnlinePullAt,
    required this.lastOnlinePullCount,
    required this.lastOfflinePushAt,
    required this.lastOfflinePushCount,
  });
}

class ForceSyncResult {
  final int pulledMetrics;
  final int pushedBatches;
  final String message;

  const ForceSyncResult({
    required this.pulledMetrics,
    required this.pushedBatches,
    required this.message,
  });
}

class _ChildNotFoundSyncException implements Exception {
  final int childId;
  _ChildNotFoundSyncException(this.childId);

  @override
  String toString() => 'Child $childId was not found on the server.';
}