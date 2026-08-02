import 'package:flutter/foundation.dart';

import 'auth_account_service.dart';
import 'connectivity_service.dart';
import 'guardian_preferences_service.dart';
import 'local_metrics_service.dart';
import 'offline_database_service.dart';
import 'offline_models.dart';
import 'server_sync_service.dart';

class GuardianLoginSyncResult {
  final bool success;
  final String message;
  final int pulledMetrics;
  final int pushedBatches;

  const GuardianLoginSyncResult({
    required this.success,
    required this.message,
    this.pulledMetrics = 0,
    this.pushedBatches = 0,
  });
}

/// Bidirectional sync that must finish before a parent reaches the dashboard.
///
/// Order:
/// 1. Refresh children from cloud into local cache
/// 2. Pull cloud metrics/limits that are missing offline
/// 3. Push offline pending metrics that are missing online
class GuardianLoginSyncService {
  GuardianLoginSyncService._();
  static final GuardianLoginSyncService instance = GuardianLoginSyncService._();

  /// Optional progress callback for login UI ("Getting ready…", etc.).
  Future<GuardianLoginSyncResult> syncAfterLogin(
    String guardianEmail, {
    void Function(String status)? onStatus,
  }) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const GuardianLoginSyncResult(
        success: false,
        message: 'Please connect so we can load your family’s data.',
      );
    }

    try {
      onStatus?.call('Finding your children…');
      final children = await AuthAccountService.instance.listChildrenForGuardian(guardianEmail);
      final childIds = children
          .map((c) => c.childId)
          .whereType<int>()
          .toList(growable: false);

      if (childIds.isEmpty) {
        onStatus?.call('You’re all set');
        return const GuardianLoginSyncResult(
          success: true,
          message: 'No children linked yet.',
        );
      }

      await LocalMetricsService.instance.initialize();
      await OfflineDatabaseService.instance.initialize();

      // --- Phase 1: online → offline ---
      onStatus?.call('Bringing down the latest…');
      var pulled = 0;
      for (final childId in childIds) {
        pulled += await _pullMetricsMissingLocally(childId);
        await _pullLimits(childId);
      }

      await LocalMetricsService.instance.recordOnlinePull(metricRows: pulled);

      // --- Phase 2: offline → online ---
      onStatus?.call('Saving this phone’s updates…');
      var pushed = 0;
      for (final childId in childIds) {
        pushed += await _pushPendingMetrics(childId);
        await OfflineDatabaseService.instance.markAllPendingSyncedForChild(childId);
      }

      await LocalMetricsService.instance.recordOfflinePush(batchCount: pushed);
      await LocalMetricsService.instance.markLoginSyncComplete();

      if (kDebugMode) {
        debugPrint(
          '[GuardianLoginSync] done for $guardianEmail — pulled=$pulled pushed=$pushed children=${childIds.length}',
        );
      }

      final String readyMessage;
      if (pulled == 0 && pushed == 0) {
        readyMessage = 'You’re all set — everything looks up to date.';
      } else if (pulled > 0 && pushed > 0) {
        readyMessage =
            'You’re ready — brought down $pulled and saved $pushed from this phone.';
      } else if (pulled > 0) {
        readyMessage = 'You’re ready — brought down $pulled update${pulled == 1 ? '' : 's'}.';
      } else {
        readyMessage =
            'You’re ready — saved $pushed update${pushed == 1 ? '' : 's'} from this phone.';
      }

      return GuardianLoginSyncResult(
        success: true,
        message: readyMessage,
        pulledMetrics: pulled,
        pushedBatches: pushed,
      );
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (kDebugMode) {
        debugPrint('[GuardianLoginSync] failed: $msg');
      }
      return GuardianLoginSyncResult(
        success: false,
        message: _looksTechnical(msg)
            ? 'We couldn’t finish updating. Please try again.'
            : (msg.isEmpty ? 'We couldn’t finish updating. Please try again.' : msg),
      );
    }
  }

  bool _looksTechnical(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('exception') ||
        lower.contains('stack') ||
        lower.contains('sql') ||
        lower.contains('http') ||
        lower.contains('statuscode') ||
        lower.contains('{') ||
        lower.contains('null') ||
        RegExp(r'\b\d{3}\b').hasMatch(msg);
  }

  Future<int> _pullMetricsMissingLocally(int childId) async {
    final result = await ServerSyncService.instance.fetchAllChildMetrics(childId);
    if (!result.success || result.data == null) {
      throw Exception('We couldn’t get the latest updates.');
    }

    var inserted = 0;
    for (final row in result.data!) {
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

      final windowStart = windowEnd.subtract(const Duration(minutes: 1));
      final batch = CuratedMetricBatch(
        childId: childId,
        windowStart: windowStart,
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
      );

      await OfflineDatabaseService.instance.insertCuratedBatch(batch);
      inserted++;
    }

    return inserted;
  }

  Future<void> _pullLimits(int childId) async {
    final result = await GuardianPreferencesService.instance.pullSessionLimitsFromServer(childId);
    // Limits may 404 for brand-new children — non-fatal.
    if (!result.success && kDebugMode) {
      debugPrint('[GuardianLoginSync] limits pull for $childId: ${result.error}');
    }
  }

  Future<int> _pushPendingMetrics(int childId) async {
    final pending = await OfflineDatabaseService.instance.loadPendingBatchesForChild(childId);
    if (pending.isEmpty) return 0;
    return LocalMetricsService.instance.pushPendingBatchesForChild(childId);
  }
}
