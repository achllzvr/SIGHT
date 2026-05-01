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
    // Hide the overlay immediately when this is called, 
    // even if the timer is already technically running.
    isPausedNotifier.value = false; 

    // Now check if we actually need to start a new ticker
    if (_isRunning || isTimeUpNotifier.value) return;
    
    _isRunning = true;
    
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSecondsNotifier.value > 0) {
        remainingSecondsNotifier.value--;
        
        if (remainingSecondsNotifier.value == 120) {
          FeedbackService.instance.interventionTriggered();
        }
      } else {
        isTimeUpNotifier.value = true;
        pauseTracking();
        FeedbackService.instance.negativeAction(); 
      }
    });
  }

  void pauseTracking() {
    _ticker?.cancel();
    _isRunning = false;
    isPausedNotifier.value = true;
  }

  void dispose() {
    pauseTracking();
    _initialized = false;
  }
}