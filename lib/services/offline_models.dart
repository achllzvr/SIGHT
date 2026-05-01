// ignore: unused_import
import 'dart:convert';

enum AlertLevel { none, blinkBubble, redOverlay, screenLock }

extension AlertLevelX on AlertLevel {
  String get key => name;

  static AlertLevel fromKey(String? value) {
    switch (value) {
      case 'blinkBubble':
        return AlertLevel.blinkBubble;
      case 'redOverlay':
        return AlertLevel.redOverlay;
      case 'screenLock':
        return AlertLevel.screenLock;
      default:
        return AlertLevel.none;
    }
  }
}

enum PetMood { happy, sad, sleeping }

extension PetMoodX on PetMood {
  String get key => name;

  static PetMood fromKey(String? value) {
    switch (value) {
      case 'sad':
        return PetMood.sad;
      case 'sleeping':
        return PetMood.sleeping;
      default:
        return PetMood.happy;
    }
  }
}

class CachedRules {
  final double safeDistanceCm;
  final double warningDistanceCm;
  final double criticalDistanceCm;
  final int healthyBlinkRatePerMin;
  final int blinkBubbleThresholdPerMin;
  final int screenLockBlinkThresholdPerMin;
  final int sessionSecondsForXP;

  const CachedRules({
    required this.safeDistanceCm,
    required this.warningDistanceCm,
    required this.criticalDistanceCm,
    required this.healthyBlinkRatePerMin,
    required this.blinkBubbleThresholdPerMin,
    required this.screenLockBlinkThresholdPerMin,
    required this.sessionSecondsForXP,
  });

  const CachedRules.defaults()
      : safeDistanceCm = 30.0,
        warningDistanceCm = 25.0,
        criticalDistanceCm = 20.0,
        healthyBlinkRatePerMin = 10,
        blinkBubbleThresholdPerMin = 8,
        screenLockBlinkThresholdPerMin = 4,
        sessionSecondsForXP = 60;

  Map<String, dynamic> toJson() {
    return {
      'safeDistanceCm': safeDistanceCm,
      'warningDistanceCm': warningDistanceCm,
      'criticalDistanceCm': criticalDistanceCm,
      'healthyBlinkRatePerMin': healthyBlinkRatePerMin,
      'blinkBubbleThresholdPerMin': blinkBubbleThresholdPerMin,
      'screenLockBlinkThresholdPerMin': screenLockBlinkThresholdPerMin,
      'sessionSecondsForXP': sessionSecondsForXP,
    };
  }

  factory CachedRules.fromJson(Map<String, dynamic> json) {
    return CachedRules(
      safeDistanceCm: (json['safeDistanceCm'] as num?)?.toDouble() ?? 30.0,
      warningDistanceCm: (json['warningDistanceCm'] as num?)?.toDouble() ?? 25.0,
      criticalDistanceCm: (json['criticalDistanceCm'] as num?)?.toDouble() ?? 20.0,
      healthyBlinkRatePerMin: (json['healthyBlinkRatePerMin'] as num?)?.toInt() ?? 10,
      blinkBubbleThresholdPerMin: (json['blinkBubbleThresholdPerMin'] as num?)?.toInt() ?? 8,
      screenLockBlinkThresholdPerMin: (json['screenLockBlinkThresholdPerMin'] as num?)?.toInt() ?? 4,
      sessionSecondsForXP: (json['sessionSecondsForXP'] as num?)?.toInt() ?? 60,
    );
  }
}

class LocalMetricEvent {
  final int? id;
  final int? childId;
  final String type;
  final double value;
  final DateTime timestamp;

  const LocalMetricEvent({
    this.id,
    this.childId,
    required this.type,
    required this.value,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'type': type,
      'value': value,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory LocalMetricEvent.fromMap(Map<String, dynamic> map) {
    return LocalMetricEvent(
      id: map['id'] as int?,
      childId: (map['childId'] as num?)?.toInt(),
      type: map['type'] as String,
      value: (map['value'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

enum SyncState { pending, synced, failed }

extension SyncStateX on SyncState {
  String get key => name;

  static SyncState fromKey(String? value) {
    switch (value) {
      case 'synced':
        return SyncState.synced;
      case 'failed':
        return SyncState.failed;
      default:
        return SyncState.pending;
    }
  }
}

class CuratedMetricBatch {
  final int? id;
  final int? childId;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double? averageBlinkRate;
  final double? averageDistanceCm;
  final int strainEvents;
  final int screenTimeMinutes;
  final int? healthScore; // ADDED
  final int? coins;       // ADDED
  final int eventCount;
  final SyncState syncState;
  final int retryCount;
  final String? lastError;
  final DateTime? lastSyncAttemptAt;
  final String? remoteId;

  const CuratedMetricBatch({
    this.id,
    this.childId,
    required this.windowStart,
    required this.windowEnd,
    required this.averageBlinkRate,
    required this.averageDistanceCm,
    this.strainEvents = 0,
    this.screenTimeMinutes = 0,
    this.healthScore,     // ADDED
    this.coins,           // ADDED
    required this.eventCount,
    this.syncState = SyncState.pending,
    this.retryCount = 0,
    this.lastError,
    this.lastSyncAttemptAt,
    this.remoteId,
  });

  bool get synced => syncState == SyncState.synced;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'windowStart': windowStart.millisecondsSinceEpoch,
      'windowEnd': windowEnd.millisecondsSinceEpoch,
      'averageBlinkRate': averageBlinkRate,
      'averageDistanceCm': averageDistanceCm,
      'strainEvents': strainEvents,
      'screenTimeMinutes': screenTimeMinutes,
      'healthScore': healthScore, // ADDED
      'coins': coins,             // ADDED
      'eventCount': eventCount,
      'synced': synced ? 1 : 0,
      'syncState': syncState.key,
      'retryCount': retryCount,
      'lastError': lastError,
      'lastSyncAttemptAt': lastSyncAttemptAt?.millisecondsSinceEpoch,
      'remoteId': remoteId,
    };
  }

  factory CuratedMetricBatch.fromMap(Map<String, dynamic> map) {
    final fallbackSynced = (map['synced'] as num?)?.toInt() == 1;
    return CuratedMetricBatch(
      id: map['id'] as int?,
      childId: (map['childId'] as num?)?.toInt(),
      windowStart: DateTime.fromMillisecondsSinceEpoch(map['windowStart'] as int),
      windowEnd: DateTime.fromMillisecondsSinceEpoch(map['windowEnd'] as int),
      averageBlinkRate: (map['averageBlinkRate'] as num?)?.toDouble(),
      averageDistanceCm: (map['averageDistanceCm'] as num?)?.toDouble(),
      strainEvents: (map['strainEvents'] as num?)?.toInt() ?? 0,
      screenTimeMinutes: (map['screenTimeMinutes'] as num?)?.toInt() ?? 0,
      healthScore: (map['healthScore'] as num?)?.toInt(), // ADDED
      coins: (map['coins'] as num?)?.toInt(),             // ADDED
      eventCount: (map['eventCount'] as num?)?.toInt() ?? 0,
      syncState: map['syncState'] == null
          ? (fallbackSynced ? SyncState.synced : SyncState.pending)
          : SyncStateX.fromKey(map['syncState'] as String?),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      lastError: map['lastError'] as String?,
      lastSyncAttemptAt: map['lastSyncAttemptAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((map['lastSyncAttemptAt'] as num).toInt()),
      remoteId: map['remoteId'] as String?,
    );
  }
}

class GamificationState {
  final int healthScore;
  final int coins;
  final int dailyStreak;
  final PetMood petMood;
  final String lastComplianceDateIso;
  final String mascotName; // ADDED

  const GamificationState({
    required this.healthScore,
    required this.coins,
    required this.dailyStreak,
    required this.petMood,
    required this.lastComplianceDateIso,
    this.mascotName = 'LUMI', // ADDED
  });

  const GamificationState.defaults()
      : healthScore = 100,
        coins = 0,
        dailyStreak = 0,
        petMood = PetMood.happy,
        lastComplianceDateIso = '',
        mascotName = 'LUMI'; // ADDED

  Map<String, dynamic> toJson() {
    return {
      'healthScore': healthScore,
      'coins': coins,
      'dailyStreak': dailyStreak,
      'petMood': petMood.key,
      'lastComplianceDateIso': lastComplianceDateIso,
      'mascotName': mascotName, // ADDED
    };
  }

  factory GamificationState.fromJson(Map<String, dynamic> json) {
    return GamificationState(
      healthScore: (json['healthScore'] as num?)?.toInt() ?? 100,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      dailyStreak: (json['dailyStreak'] as num?)?.toInt() ?? 0,
      petMood: PetMoodX.fromKey(json['petMood'] as String?),
      lastComplianceDateIso: json['lastComplianceDateIso'] as String? ?? '',
      mascotName: json['mascotName'] as String? ?? 'LUMI', // ADDED
    );
  }
}

class RuleEvaluationResult {
  final AlertLevel alertLevel;
  final String reason;

  const RuleEvaluationResult({required this.alertLevel, required this.reason});
}