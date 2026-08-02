import 'dart:async';
import 'package:flutter/foundation.dart';
import 'active_child_context_service.dart';
import 'offline_database_service.dart';
import 'guardian_preferences_service.dart';
import 'gamification_service.dart';
import 'feedback_service.dart';

class SessionTimerService {
  SessionTimerService._private();
  static final SessionTimerService instance = SessionTimerService._private();

  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isTimeUpNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);
  
  // NEW: Triggers the Wrap-up overlay
  final ValueNotifier<bool> showWrapUpWarningNotifier = ValueNotifier<bool>(false);

  Timer? _ticker;
  bool _initialized = false;
  bool _isRunning = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    final prefs = await GuardianPreferencesService.instance.loadPreferences();
    await _applyDailyLimit(prefs.dailyScreenLimitMinutes);
    _initialized = true;
  }

  /// Re-read guardian prefs and refresh remaining time (call after limit changes).
  Future<void> reloadFromPreferences() async {
    final prefs = await GuardianPreferencesService.instance.loadPreferences();
    await _applyDailyLimit(prefs.dailyScreenLimitMinutes);
  }

  Future<void> _applyDailyLimit(int dailyLimitMinutes) async {
    final childId = await ActiveChildContextService.instance.getActiveChildId();
    
    int elapsedMinutes = 0;
    if (childId != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      
      final todayBatches = await OfflineDatabaseService.instance.loadBatchesForChild(childId, today, tomorrow);
      elapsedMinutes = todayBatches.fold<int>(0, (sum, b) => sum + b.screenTimeMinutes);
    }

    final remainingMins = dailyLimitMinutes - elapsedMinutes;
    remainingSecondsNotifier.value = remainingMins > 0 ? remainingMins * 60 : 0;
    isTimeUpNotifier.value = remainingSecondsNotifier.value <= 0;
  }

  void startTracking() {
    isPausedNotifier.value = false;
    if (_isRunning || isTimeUpNotifier.value) return;
    _isRunning = true;
    
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSecondsNotifier.value > 0) {
        remainingSecondsNotifier.value--;
        
        // Trigger Wrap-up warning at 2 minutes left
        if (remainingSecondsNotifier.value == 120) {
          showWrapUpWarningNotifier.value = true;
          FeedbackService.instance.interventionTriggered();
        }
      } else {
        isTimeUpNotifier.value = true;
        showWrapUpWarningNotifier.value = false;
        pauseTracking();
        FeedbackService.instance.negativeAction();
      }
    });
  }

  void wrapUpEarly() {
    // Reward Early Bird Bonus
    GamificationService.instance.coinsNotifier.value += 20;
    isTimeUpNotifier.value = true;
    showWrapUpWarningNotifier.value = false;
    pauseTracking();
  }

  void ignoreWrapUp() {
    showWrapUpWarningNotifier.value = false;
  }

  void pauseTracking() {
    _ticker?.cancel();
    _isRunning = false;
    isPausedNotifier.value = true;
  }

  /// Pause timer without the Session Paused gate (silent background pause).
  void pauseTrackingQuietly() {
    _ticker?.cancel();
    _isRunning = false;
    isPausedNotifier.value = false;
  }

  void dispose() {
    pauseTracking();
    _initialized = false;
  }
}