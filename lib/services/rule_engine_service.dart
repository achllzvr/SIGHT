import 'package:flutter/foundation.dart';

import 'offline_database_service.dart';
import 'offline_models.dart';

class RuleEngineService {
  RuleEngineService._private();
  static final RuleEngineService instance = RuleEngineService._private();

  final ValueNotifier<AlertLevel> alertLevelNotifier = ValueNotifier<AlertLevel>(AlertLevel.none);
  final ValueNotifier<String> overlayMessageNotifier = ValueNotifier<String>('');

  CachedRules _rules = const CachedRules.defaults();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await OfflineDatabaseService.instance.initialize();
    _rules = await OfflineDatabaseService.instance.loadCachedRules() ?? const CachedRules.defaults();
    _initialized = true;
  }

  Future<CachedRules> loadCachedRules() async {
    await initialize();
    return _rules;
  }

  Future<void> saveCachedRules(CachedRules rules) async {
    await initialize();
    _rules = rules;
    await OfflineDatabaseService.instance.saveCachedRules(rules);
  }

  RuleEvaluationResult evaluateLiveMetrics({
    required double distanceCm,
    required int blinkRatePerMin,
    required bool faceDetected,
  }) {
    final rules = _rules;
    AlertLevel alertLevel = AlertLevel.none;
    String reason = 'tracking stable';

    if (!faceDetected) {
      alertLevel = AlertLevel.blinkBubble;
      reason = 'face temporarily lost';
    } else if (distanceCm <= rules.criticalDistanceCm || blinkRatePerMin <= rules.screenLockBlinkThresholdPerMin) {
      alertLevel = AlertLevel.screenLock;
      reason = 'critical proximity or eye fatigue';
    } else if (distanceCm < rules.warningDistanceCm || blinkRatePerMin < rules.healthyBlinkRatePerMin) {
      alertLevel = AlertLevel.redOverlay;
      reason = 'adjust distance or blink rhythm';
    } else if (distanceCm < rules.safeDistanceCm || blinkRatePerMin <= rules.blinkBubbleThresholdPerMin) {
      alertLevel = AlertLevel.blinkBubble;
      reason = 'minor correction needed';
    }

    triggerOverlay(alertLevel, reason);
    return RuleEvaluationResult(alertLevel: alertLevel, reason: reason);
  }

  void triggerOverlay(AlertLevel alertLevel, [String reason = '']) {
    alertLevelNotifier.value = alertLevel;
    overlayMessageNotifier.value = reason;
  }
}