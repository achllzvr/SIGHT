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
  final String type;
  final double value;
  final DateTime timestamp;

  const LocalMetricEvent({
    this.id,
    required this.type,
    required this.value,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'value': value,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory LocalMetricEvent.fromMap(Map<String, dynamic> map) {
    return LocalMetricEvent(
      id: map['id'] as int?,
      type: map['type'] as String,
      value: (map['value'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class CuratedMetricBatch {
  final int? id;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double? averageBlinkRate;
  final double? averageDistanceCm;
  final int eventCount;
  final bool synced;

  const CuratedMetricBatch({
    this.id,
    required this.windowStart,
    required this.windowEnd,
    required this.averageBlinkRate,
    required this.averageDistanceCm,
    required this.eventCount,
    required this.synced,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'windowStart': windowStart.millisecondsSinceEpoch,
      'windowEnd': windowEnd.millisecondsSinceEpoch,
      'averageBlinkRate': averageBlinkRate,
      'averageDistanceCm': averageDistanceCm,
      'eventCount': eventCount,
      'synced': synced ? 1 : 0,
    };
  }

  factory CuratedMetricBatch.fromMap(Map<String, dynamic> map) {
    return CuratedMetricBatch(
      id: map['id'] as int?,
      windowStart: DateTime.fromMillisecondsSinceEpoch(map['windowStart'] as int),
      windowEnd: DateTime.fromMillisecondsSinceEpoch(map['windowEnd'] as int),
      averageBlinkRate: (map['averageBlinkRate'] as num?)?.toDouble(),
      averageDistanceCm: (map['averageDistanceCm'] as num?)?.toDouble(),
      eventCount: (map['eventCount'] as num?)?.toInt() ?? 0,
      synced: (map['synced'] as num?)?.toInt() == 1,
    );
  }
}

class GamificationState {
  final int sessionXp;
  final int dailyStreak;
  final PetMood petMood;
  final String lastComplianceDateIso;

  const GamificationState({
    required this.sessionXp,
    required this.dailyStreak,
    required this.petMood,
    required this.lastComplianceDateIso,
  });

  const GamificationState.defaults()
      : sessionXp = 0,
        dailyStreak = 0,
        petMood = PetMood.happy,
        lastComplianceDateIso = '';

  Map<String, dynamic> toJson() {
    return {
      'sessionXp': sessionXp,
      'dailyStreak': dailyStreak,
      'petMood': petMood.key,
      'lastComplianceDateIso': lastComplianceDateIso,
    };
  }

  factory GamificationState.fromJson(Map<String, dynamic> json) {
    return GamificationState(
      sessionXp: (json['sessionXp'] as num?)?.toInt() ?? 0,
      dailyStreak: (json['dailyStreak'] as num?)?.toInt() ?? 0,
      petMood: PetMoodX.fromKey(json['petMood'] as String?),
      lastComplianceDateIso: json['lastComplianceDateIso'] as String? ?? '',
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

class RuleEvaluationResult {
  final AlertLevel alertLevel;
  final String reason;

  const RuleEvaluationResult({required this.alertLevel, required this.reason});
}