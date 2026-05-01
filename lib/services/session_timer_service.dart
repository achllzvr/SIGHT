import 'dart:async';
import 'package:flutter/foundation.dart';

import 'guardian_preferences_service.dart';
import 'feedback_service.dart';

class SessionTimerService {
  SessionTimerService._private();
  static final SessionTimerService instance = SessionTimerService._private();

  // Tracks remaining time in seconds
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(0);
  
  // Triggers the "Time's Up" lock screen
  final ValueNotifier<bool> isTimeUpNotifier = ValueNotifier<bool>(false);

  // Resume
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);

  Timer? _ticker;
  bool _initialized = false;
  bool _isRunning = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    final prefs = await GuardianPreferencesService.instance.loadPreferences();
    
    // Convert guardian's minute limit to seconds
    remainingSecondsNotifier.value = prefs.dailyScreenLimitMinutes * 60;
    _initialized = true;
  }

  void startTracking() {
    if (_isRunning || isTimeUpNotifier.value) return;
    
    _isRunning = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSecondsNotifier.value > 0) {
        remainingSecondsNotifier.value--;
        
        // 2-Minute Wrap-Up Warning
        if (remainingSecondsNotifier.value == 120) {
          FeedbackService.instance.interventionTriggered();
          if (kDebugMode) debugPrint('[SessionTimer] 2 minutes remaining!');
        }
      } else {
        // Time's Up!
        isTimeUpNotifier.value = true;
        pauseTracking();
        FeedbackService.instance.negativeAction(); // Long vibration
      }
    });
  }

  void pauseTracking() {
    _ticker?.cancel();
    _isRunning = false;
  }

  void dispose() {
    pauseTracking();
    _initialized = false;
  }
}