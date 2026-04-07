import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'server_sync_service.dart';

class GuardianPreferences {
  final int? selectedChildId;
  final int dailyScreenLimitMinutes;
  final String monitoringMode;
  final bool isActive;
  final bool autoEnforceBreaks;
  final bool weekendRelaxedMode;
  final double distanceAlertThresholdCm;
  final double criticalDistanceThresholdCm;
  final int blinkRateAlertThresholdPerMin;
  final bool parentNotificationsEnabled;

  const GuardianPreferences({
    required this.selectedChildId,
    required this.dailyScreenLimitMinutes,
    required this.monitoringMode,
    required this.isActive,
    required this.autoEnforceBreaks,
    required this.weekendRelaxedMode,
    required this.distanceAlertThresholdCm,
    required this.criticalDistanceThresholdCm,
    required this.blinkRateAlertThresholdPerMin,
    required this.parentNotificationsEnabled,
  });

  const GuardianPreferences.defaults()
      : selectedChildId = null,
        dailyScreenLimitMinutes = 120,
        monitoringMode = 'Moderate',
        isActive = true,
        autoEnforceBreaks = true,
        weekendRelaxedMode = false,
        distanceAlertThresholdCm = 30,
        criticalDistanceThresholdCm = 10,
        blinkRateAlertThresholdPerMin = 10,
        parentNotificationsEnabled = true;

  Map<String, dynamic> toJson() {
    return {
      'selectedChildId': selectedChildId,
      'dailyScreenLimitMinutes': dailyScreenLimitMinutes,
      'monitoringMode': monitoringMode,
      'isActive': isActive,
      'autoEnforceBreaks': autoEnforceBreaks,
      'weekendRelaxedMode': weekendRelaxedMode,
      'distanceAlertThresholdCm': distanceAlertThresholdCm,
      'criticalDistanceThresholdCm': criticalDistanceThresholdCm,
      'blinkRateAlertThresholdPerMin': blinkRateAlertThresholdPerMin,
      'parentNotificationsEnabled': parentNotificationsEnabled,
    };
  }

  factory GuardianPreferences.fromJson(Map<String, dynamic> json) {
    return GuardianPreferences(
      selectedChildId: (json['selectedChildId'] as num?)?.toInt(),
      dailyScreenLimitMinutes: (json['dailyScreenLimitMinutes'] as num?)?.toInt() ?? 120,
      monitoringMode: json['monitoringMode'] as String? ?? 'Moderate',
      isActive: json['isActive'] as bool? ?? true,
      autoEnforceBreaks: json['autoEnforceBreaks'] as bool? ?? true,
      weekendRelaxedMode: json['weekendRelaxedMode'] as bool? ?? false,
      distanceAlertThresholdCm: (json['distanceAlertThresholdCm'] as num?)?.toDouble() ?? 30,
      criticalDistanceThresholdCm: (json['criticalDistanceThresholdCm'] as num?)?.toDouble() ?? 10,
      blinkRateAlertThresholdPerMin: (json['blinkRateAlertThresholdPerMin'] as num?)?.toInt() ?? 10,
      parentNotificationsEnabled: json['parentNotificationsEnabled'] as bool? ?? true,
    );
  }

  GuardianPreferences copyWith({
    int? selectedChildId,
    bool clearSelectedChildId = false,
    int? dailyScreenLimitMinutes,
    String? monitoringMode,
    bool? isActive,
    bool? autoEnforceBreaks,
    bool? weekendRelaxedMode,
    double? distanceAlertThresholdCm,
    double? criticalDistanceThresholdCm,
    int? blinkRateAlertThresholdPerMin,
    bool? parentNotificationsEnabled,
  }) {
    return GuardianPreferences(
      selectedChildId: clearSelectedChildId ? null : (selectedChildId ?? this.selectedChildId),
      dailyScreenLimitMinutes: dailyScreenLimitMinutes ?? this.dailyScreenLimitMinutes,
      monitoringMode: monitoringMode ?? this.monitoringMode,
      isActive: isActive ?? this.isActive,
      autoEnforceBreaks: autoEnforceBreaks ?? this.autoEnforceBreaks,
      weekendRelaxedMode: weekendRelaxedMode ?? this.weekendRelaxedMode,
      distanceAlertThresholdCm: distanceAlertThresholdCm ?? this.distanceAlertThresholdCm,
      criticalDistanceThresholdCm: criticalDistanceThresholdCm ?? this.criticalDistanceThresholdCm,
      blinkRateAlertThresholdPerMin: blinkRateAlertThresholdPerMin ?? this.blinkRateAlertThresholdPerMin,
      parentNotificationsEnabled: parentNotificationsEnabled ?? this.parentNotificationsEnabled,
    );
  }
}

class GuardianPreferencesService {
  GuardianPreferencesService._private();

  static final GuardianPreferencesService instance = GuardianPreferencesService._private();

  static const _preferencesKey = 'guardian_preferences_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<GuardianPreferences> loadPreferences() async {
    final raw = await _storage.read(key: _preferencesKey);
    if (raw == null || raw.isEmpty) {
      return const GuardianPreferences.defaults();
    }

    return GuardianPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> savePreferences(GuardianPreferences preferences) async {
    await _storage.write(key: _preferencesKey, value: jsonEncode(preferences.toJson()));
  }

  Future<SyncOperationResult<GuardianPreferences>> pullSessionLimitsFromServer(int childId) async {
    final result = await ServerSyncService.instance.fetchSessionLimits(childId);
    if (!result.success || result.data == null) {
      return SyncOperationResult(success: false, error: result.error);
    }

    await savePreferences(result.data!);
    return SyncOperationResult(success: true, data: result.data);
  }

  Future<SyncOperationResult<void>> pushSessionLimitsToServer(GuardianPreferences preferences) async {
    return ServerSyncService.instance.upsertSessionLimits(preferences);
  }
}