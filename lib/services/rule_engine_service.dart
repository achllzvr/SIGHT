import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../blink_test_screen.dart';
import 'guardian_preferences_service.dart';
import 'offline_database_service.dart';
import 'offline_models.dart';
import 'feedback_service.dart';
import 'watch_tracking_session.dart';
import 'twenty_twenty_twenty_service.dart';

class RuleEngineService {
  RuleEngineService._private();
  static final RuleEngineService instance = RuleEngineService._private();

  final ValueNotifier<AlertLevel> alertLevelNotifier = ValueNotifier<AlertLevel>(AlertLevel.none);
  final ValueNotifier<String> overlayMessageNotifier = ValueNotifier<String>('');

  CachedRules _rules = const CachedRules.defaults();
  bool _initialized = false;
  bool _criticalLockActive = false;
  bool _enforcementActive = true;
  bool _autoEnforceBreaks = true;
  String _monitoringMode = 'Strict';

  bool get autoEnforceBreaks => _autoEnforceBreaks;

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
    bool blinkRateWarm = true,
    bool distanceSampleReady = true,
  }) {
    if (!WatchTrackingSession.instance.active.value) {
      triggerOverlay(AlertLevel.none, 'tracking inactive');
      return const RuleEvaluationResult(alertLevel: AlertLevel.none, reason: 'tracking inactive');
    }

    if (!_enforcementActive) {
      triggerOverlay(AlertLevel.none, 'guardian enforcement paused');
      return const RuleEvaluationResult(alertLevel: AlertLevel.none, reason: 'guardian enforcement paused');
    }

    final rules = _rules;
    AlertLevel alertLevel = AlertLevel.none;
    String reason = 'tracking stable';
    // Cold blink window (just cleared on Watch leave) must not trip screenLock.
    final blinkThreshold = rules.screenLockBlinkThresholdPerMin;
    final blinkSuppressed = blinkRateWarm && faceDetected && blinkRatePerMin < blinkThreshold;
    final canJudgeDistance = distanceSampleReady && distanceCm > 0;
    final canJudgeBlinkRate = blinkRateWarm;
    // Still spinning camera up after Watch return — don't flash face-loss overlay.
    final stillWarmingUp = !blinkRateWarm && !distanceSampleReady;

    if (!faceDetected && !stillWarmingUp) {
      alertLevel = AlertLevel.redOverlay;
      reason = 'face not detected - critical tracking state';
      FeedbackService.instance.interventionTriggered();
    } else if (!faceDetected && stillWarmingUp) {
      alertLevel = AlertLevel.none;
      reason = 'waiting for camera warm-up';
    } else if (blinkSuppressed && _autoEnforceBreaks) {
      if (_monitoringMode == 'Relaxed') {
        alertLevel = AlertLevel.blinkBubble;
        reason = 'blink reminder';
      } else {
        alertLevel = AlertLevel.screenLock;
        reason = 'blink suppression detected';
        FeedbackService.instance.interventionTriggered();
      }
    } else if (canJudgeDistance && distanceCm <= rules.criticalDistanceCm) {
      alertLevel = AlertLevel.redOverlay;
      reason = 'critical proximity detected';
      FeedbackService.instance.interventionTriggered();
    } else if (canJudgeDistance &&
        (distanceCm < rules.warningDistanceCm ||
            (canJudgeBlinkRate && blinkRatePerMin < rules.healthyBlinkRatePerMin))) {
      alertLevel = AlertLevel.redOverlay;
      reason = 'adjust distance or blink rhythm';
      FeedbackService.instance.interventionTriggered();
    } else if (canJudgeDistance &&
        (distanceCm < rules.safeDistanceCm ||
            (canJudgeBlinkRate && blinkRatePerMin <= rules.blinkBubbleThresholdPerMin))) {
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

  Future<void> applyGuardianPreferences(GuardianPreferences preferences) async {
    await initialize();
    _enforcementActive = preferences.isActive;
    _autoEnforceBreaks = preferences.autoEnforceBreaks;
    _monitoringMode = preferences.monitoringMode == 'Relaxed' ? 'Relaxed' : 'Strict';

    final updatedRules = CachedRules(
      safeDistanceCm: preferences.distanceAlertThresholdCm,
      warningDistanceCm: preferences.distanceAlertThresholdCm,
      criticalDistanceCm: preferences.criticalDistanceThresholdCm,
      healthyBlinkRatePerMin: preferences.blinkRateAlertThresholdPerMin,
      blinkBubbleThresholdPerMin: _rules.blinkBubbleThresholdPerMin,
      screenLockBlinkThresholdPerMin: _rules.screenLockBlinkThresholdPerMin,
      sessionSecondsForXP: _rules.sessionSecondsForXP,
    );

    await saveCachedRules(updatedRules);
    TwentyTwentyBreakService.instance.setAutoEnforceBreaks(preferences.autoEnforceBreaks);
  }

  Future<void> triggerCriticalLock(BuildContext context, {bool skipIfJustCompleted = false}) async {
    if (!_autoEnforceBreaks) {
      return;
    }
    if (_criticalLockActive) {
      return;
    }

    // Skip if 20-20-20 break was just completed (prevents overlapping interventions)
    if (skipIfJustCompleted) {
      if (kDebugMode) {
        debugPrint('[RuleEngine] Skipping blink recovery after 20-20-20 break');
      }
      return;
    }

    _criticalLockActive = true;
    
    // Provide strong feedback for critical intervention
    FeedbackService.instance.interventionTriggered();
    
    try {
      if (!context.mounted) {
        return;
      }

      // In-app Blink Game only — do not show native Device Locked overlay
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const BlinkTestScreen(
            enforceCompletion: true,
            requiredIntentionalBlinks: 15,
          ),
          fullscreenDialog: true,
        ),
      );
    } finally {
      _criticalLockActive = false;
    }
  }
}