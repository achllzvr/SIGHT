import 'package:shared_preferences/shared_preferences.dart';

import 'api_client_service.dart';
import 'api_config_service.dart';
import 'gamification_service.dart';
import 'guardian_preferences_service.dart';
import 'mascot_skin_service.dart';
import 'offline_database_service.dart';
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
              'avg_blink_rate': batch.averageBlinkRate,
              'avg_distance': batch.averageDistanceCm,
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

  /// Pulls all cloud metrics for a child (paginated). Used on guardian login.
  Future<SyncOperationResult<List<Map<String, dynamic>>>> fetchAllChildMetrics(int childId) async {
    if (!ApiConfigService.isConfigured) {
      return const SyncOperationResult(success: false, error: 'API base URL is not configured.');
    }

    try {
      final all = <Map<String, dynamic>>[];
      var page = 1;
      var totalPages = 1;

      while (page <= totalPages) {
        final uri = ApiConfigService.buildUri(
          '/api/shared/child/$childId/metrics',
          queryParameters: {
            'page': '$page',
            'per_page': '100',
          },
        );
        final response = await ApiClientService.instance.get(uri);
        if (!response.isSuccess) {
          return SyncOperationResult(
            success: false,
            error: 'Metrics fetch failed (${response.statusCode})',
          );
        }

        final data = response.data;
        if (data is! Map) {
          return const SyncOperationResult(success: false, error: 'Invalid metrics response.');
        }

        final items = data['data'];
        if (items is List) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              all.add(item);
            } else if (item is Map) {
              all.add(Map<String, dynamic>.from(item));
            }
          }
        }

        final pagination = data['pagination'];
        if (pagination is Map) {
          totalPages = (pagination['total_pages'] as num?)?.toInt() ?? page;
        } else {
          break;
        }
        page++;
      }

      return SyncOperationResult(success: true, data: all);
    } catch (e) {
      return SyncOperationResult(success: false, error: 'Metrics fetch exception: $e');
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
      if (data is Map) {
        final root = Map<String, dynamic>.from(data);
        if (root['data'] is Map) {
          source = Map<String, dynamic>.from(root['data'] as Map);
        } else {
          source = root;
        }
      }

      if (source == null) {
        return const SyncOperationResult(success: false, error: 'No session limits data found.');
      }

      bool asBool(dynamic value, {bool fallback = true}) {
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final normalized = value.trim().toLowerCase();
          if (normalized == '1' || normalized == 'true') return true;
          if (normalized == '0' || normalized == 'false') return false;
        }
        return fallback;
      }

      final preferences = const GuardianPreferences.defaults().copyWith(
        selectedChildId: childId,
        dailyScreenLimitMinutes: (source['daily_limit_minutes'] as num?)?.toInt() ?? 120,
        monitoringMode: (source['mode'] as String?) ?? 'Moderate',
        isActive: asBool(source['is_active']),
        distanceAlertThresholdCm: (source['harmful_distance_threshold'] as num?)?.toDouble() ?? 30,
        criticalDistanceThresholdCm: (source['critical_distance_threshold'] as num?)?.toDouble() ?? 10,
        autoEnforceBreaks: asBool(source['auto_enforce_breaks']),
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

  /// 60s Watch Area heartbeat — updates last_sync + child user presence for concurrent web viewing.
  Future<SyncOperationResult<void>> devicePing(int childId) async {
    if (!ApiConfigService.isConfigured) {
      return const SyncOperationResult(success: false, error: 'API base URL is not configured.');
    }
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.devicePingEndpoint);
      final response = await ApiClientService.instance.post(
        uri,
        jsonBody: {'child_id': childId},
      );
      if (!response.isSuccess) {
        return SyncOperationResult(
          success: false,
          error: 'Device ping failed (${response.statusCode})',
        );
      }
      return const SyncOperationResult(success: true);
    } catch (e) {
      return SyncOperationResult(success: false, error: 'Device ping exception: $e');
    }
  }

  /// Multi-horizon dashboard payload (alerts, OPI, usage tiers, series).
  Future<SyncOperationResult<Map<String, dynamic>>> fetchChildDashboard(
    int childId, {
    String range = '7d',
  }) async {
    if (!ApiConfigService.isConfigured) {
      return const SyncOperationResult(success: false, error: 'API base URL is not configured.');
    }
    try {
      final uri = ApiConfigService.buildUri(
        ApiConfigService.childDashboardEndpoint(childId),
        queryParameters: {'range': range},
      );
      final response = await ApiClientService.instance.get(uri);
      if (!response.isSuccess) {
        return SyncOperationResult(
          success: false,
          error: 'Dashboard fetch failed (${response.statusCode})',
        );
      }
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return SyncOperationResult(
          success: true,
          data: Map<String, dynamic>.from(data['data'] as Map),
        );
      }
      if (data is Map<String, dynamic>) {
        return SyncOperationResult(success: true, data: data);
      }
      return const SyncOperationResult(success: false, error: 'Invalid dashboard payload.');
    } catch (e) {
      return SyncOperationResult(success: false, error: 'Dashboard fetch exception: $e');
    }
  }

  // === Mascot skin inventory sync ===

  Future<SyncOperationResult<Map<String, dynamic>>> fetchInventory(int childId) async {
    if (!ApiConfigService.isConfigured) {
      return const SyncOperationResult(success: false, error: 'API base URL is not configured.');
    }
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.inventoryEndpoint(childId));
      final response = await ApiClientService.instance.get(uri);
      if (!response.isSuccess) {
        return SyncOperationResult(success: false, error: 'Inventory fetch failed (${response.statusCode})');
      }
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return SyncOperationResult(success: true, data: Map<String, dynamic>.from(data['data'] as Map));
      }
      return const SyncOperationResult(success: false, error: 'Invalid inventory payload.');
    } catch (e) {
      return SyncOperationResult(success: false, error: 'Inventory fetch exception: $e');
    }
  }

  /// Push one locally-purchased skin to the account. Safe to retry: the
  /// server records purchases idempotently.
  Future<bool> pushPurchase(int childId, String itemKey) async {
    if (!ApiConfigService.isConfigured) return false;
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.inventoryPurchaseEndpoint(childId));
      final response = await ApiClientService.instance.post(uri, jsonBody: {'item_key': itemKey});
      if (!response.isSuccess) return false;
      final data = response.data;
      final remoteId = (data is Map && data['data'] is Map) ? (data['data'] as Map)['inventory_id']?.toString() : null;
      await OfflineDatabaseService.instance.markInventoryItemSynced(childId: childId, itemKey: itemKey, remoteId: remoteId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pushEquip(int childId, String itemKey) async {
    if (!ApiConfigService.isConfigured) return false;
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.inventoryEquipEndpoint(childId));
      final response = await ApiClientService.instance.put(uri, jsonBody: {'item_key': itemKey});
      if (response.isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(GamificationService.equippedDirtyKeyFor(childId));
      }
      return response.isSuccess;
    } catch (_) {
      return false;
    }
  }

  /// Full reconcile for a child: push offline purchases, push the locally
  /// equipped skin, then pull the server record (account truth when online)
  /// into the local cache and equipped notifier.
  Future<void> syncInventoryForChild(int childId) async {
    final db = OfflineDatabaseService.instance;
    final pending = await db.listPendingInventoryItems(childId: childId);
    for (final row in pending) {
      final key = row['itemKey'] as String?;
      if (key != null && MascotSkinCatalog.isKnownKey(key)) {
        await pushPurchase(childId, key);
      }
    }
    // Only push the equipped skin if it was explicitly changed on this
    // device; otherwise the server's saved skin wins (reinstall restore).
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(GamificationService.equippedDirtyKeyFor(childId)) == true) {
      final localEquipped = GamificationService.instance.equippedItemKeyNotifier.value;
      await pushEquip(childId, localEquipped);
    }

    final result = await fetchInventory(childId);
    if (!result.success || result.data == null) return;
    final owned = result.data!['owned_item_keys'];
    if (owned is List) {
      for (final raw in owned) {
        final key = raw?.toString();
        if (key == null || !MascotSkinCatalog.isKnownKey(key) || key == MascotSkinCatalog.frogKey) continue;
        final skin = MascotSkinCatalog.byKey(key);
        await db.addInventoryItem(childId: childId, itemKey: skin.key, itemName: skin.name, cost: skin.cost, synced: true);
      }
    }
    await GamificationService.instance.applyEquippedSkin(result.data!['equipped_skin_key']?.toString());
  }

  Future<SyncOperationResult<List<Map<String, dynamic>>>> fetchPartneredProfessionals({
    String? specialty,
    String? query,
  }) async {
    if (!ApiConfigService.isConfigured) {
      return const SyncOperationResult(success: false, error: 'API base URL is not configured.');
    }
    try {
      final params = <String, String>{};
      if (specialty != null && specialty.isNotEmpty) params['specialty'] = specialty;
      if (query != null && query.isNotEmpty) params['q'] = query;
      final uri = ApiConfigService.buildUri(
        ApiConfigService.partneredProfessionalsEndpoint,
        queryParameters: params.isEmpty ? null : params,
      );
      final response = await ApiClientService.instance.get(uri);
      if (!response.isSuccess) {
        return SyncOperationResult(
          success: false,
          error: 'Professionals fetch failed (${response.statusCode})',
        );
      }
      final data = response.data;
      final list = <Map<String, dynamic>>[];
      if (data is Map) {
        final pros = data['data'] is Map
            ? (data['data'] as Map)['professionals']
            : data['professionals'];
        if (pros is List) {
          for (final item in pros) {
            if (item is Map) list.add(Map<String, dynamic>.from(item));
          }
        }
      }
      return SyncOperationResult(success: true, data: list);
    } catch (e) {
      return SyncOperationResult(success: false, error: 'Professionals fetch exception: $e');
    }
  }
}
