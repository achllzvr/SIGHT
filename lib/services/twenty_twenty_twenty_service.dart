import 'package:flutter/foundation.dart';
import 'dart:async';
import 'detection_service.dart';
import 'feedback_service.dart';

enum BreakState {
  inactive,
  scheduled,
  askingPermission,
  running,
  countdown,
  completed,
}

class TwentyTwentyBreakService {
  TwentyTwentyBreakService._private();
  static final TwentyTwentyBreakService instance = TwentyTwentyBreakService._private();

  final ValueNotifier<BreakState> stateNotifier = ValueNotifier<BreakState>(BreakState.inactive);
  final ValueNotifier<int> secondsRemainingNotifier = ValueNotifier<int>(20);
  final ValueNotifier<int> countdownNotifier = ValueNotifier<int>(0); // For 20-vibration countdown
  final ValueNotifier<bool> faceDetectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> recoverySecondsNotifier = ValueNotifier<int>(0); // 1 or 2 minutes chosen

  bool _initialized = false;
  Timer? _breakTimer;
  Timer? _countdownTimer;
  Timer? _autoTriggerTimer;
  Timer? _faceDetectionListener;
  
  bool _enforceCompletion = false; // Whether break is mandatory
  int _lastBreakTime = 0; // Timestamp of last break completion
  bool _breakJustCompleted = false; // Flag to prevent intervention immediately after break

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await DetectionService.instance.initialize();
    _initialized = true;

    // Start auto-trigger listener - every 20 minutes
    _setupAutoTrigger();

    if (kDebugMode) {
      debugPrint('[20-20-20 Service] Initialized');
    }
  }

  void _setupAutoTrigger() {
    _autoTriggerTimer?.cancel();
    // Check every 5 seconds if it's time for a break (20 mins = 1200 seconds)
    _autoTriggerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (stateNotifier.value == BreakState.inactive) {
        final elapsedSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - _lastBreakTime;
        if (elapsedSeconds >= 1200) { // 20 minutes
          _triggerAutoBreak();
        }
      }
    });
  }

  /// Trigger automatic break (enforced after permission period)
  void _triggerAutoBreak() {
    if (stateNotifier.value != BreakState.inactive) {
      return;
    }

    _enforceCompletion = true;
    stateNotifier.value = BreakState.askingPermission;
    
    if (kDebugMode) {
      debugPrint('[20-20-20 Service] Auto-triggered break');
    }
  }

  /// Request manual break - shows permission dialog
  void requestBreak() {
    if (stateNotifier.value != BreakState.inactive) {
      return;
    }

    _enforceCompletion = false;
    stateNotifier.value = BreakState.askingPermission;

    if (kDebugMode) {
      debugPrint('[20-20-20 Service] Manual break requested');
    }
  }

  /// User chooses recovery time and confirms break
  void confirmBreakWithRecoveryTime(int minutes) {
    if (stateNotifier.value != BreakState.askingPermission) {
      return;
    }

    if (minutes != 1 && minutes != 2) {
      return; // Invalid choice
    }

    recoverySecondsNotifier.value = minutes * 60;
    stateNotifier.value = BreakState.running;
    secondsRemainingNotifier.value = 20; // 20-second break timer
    _startBreakTimer();

    if (kDebugMode) {
      debugPrint('[20-20-20 Service] Break confirmed - $minutes min recovery time');
    }
  }

  /// Start the 20-second break timer
  void _startBreakTimer() {
    _breakTimer?.cancel();
    secondsRemainingNotifier.value = 20;
    _setupFaceDetectionListener();

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = secondsRemainingNotifier.value - 1;
      
      if (remaining <= 0) {
        _breakTimer?.cancel();
        _startCountdown(); // Start 20-vibration countdown
      } else {
        secondsRemainingNotifier.value = remaining;
      }
    });
  }

  /// Listen for face detection to restart timer
  void _setupFaceDetectionListener() {
    _faceDetectionListener?.cancel();
    _faceDetectionListener = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final faceDetected = DetectionService.instance.faceDetected.value;
      faceDetectedNotifier.value = faceDetected;

      // If face is detected while timer is running, restart it
      if (faceDetected && stateNotifier.value == BreakState.running) {
        secondsRemainingNotifier.value = 20; // Reset timer
        if (kDebugMode) {
          debugPrint('[20-20-20 Service] Face detected - timer reset to 20s');
        }
      }
    });
  }

  /// Start the 20-vibration countdown and completion sequence
  void _startCountdown() {
    if (stateNotifier.value != BreakState.running) {
      return;
    }

    _faceDetectionListener?.cancel();
    stateNotifier.value = BreakState.countdown;
    countdownNotifier.value = 20;

    // Provide 20 vibrations with 100ms spacing
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final remaining = countdownNotifier.value - 1;

      // Haptic feedback for each vibration
      FeedbackService.instance.blinkDetected();

      if (remaining <= 0) {
        _countdownTimer?.cancel();
        _completeBreak();
      } else {
        countdownNotifier.value = remaining;
      }
    });
  }

  /// Mark break as completed
  void _completeBreak() {
    stateNotifier.value = BreakState.completed;
    countdownNotifier.value = 0;
    _lastBreakTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _enforceCompletion = false;

    // Play success sound
    FeedbackService.instance.exerciseCompleted();

    if (kDebugMode) {
      debugPrint('[20-20-20 Service] Break completed successfully');
    }

    // Mark that break was just completed (prevents immediate intervention)
    _breakJustCompleted = true;
    Future.delayed(const Duration(seconds: 2), () {
      _breakJustCompleted = false;
    });
  }

  /// Check if break was just completed (used to prevent intervention immediately after)
  bool get breakJustCompleted => _breakJustCompleted;

  /// Cancel the break (only if not enforced)
  void cancelBreak() {
    if (_enforceCompletion) {
      return; // Cannot cancel enforced breaks
    }

    _breakTimer?.cancel();
    _countdownTimer?.cancel();
    _faceDetectionListener?.cancel();
    stateNotifier.value = BreakState.inactive;
    secondsRemainingNotifier.value = 20;
    recoverySecondsNotifier.value = 0;

    if (kDebugMode) {
      debugPrint('[20-20-20 Service] Break cancelled');
    }
  }

  /// Reset break state when user exits completion screen
  void resetBreakState() {
    if (stateNotifier.value == BreakState.completed) {
      stateNotifier.value = BreakState.inactive;
      secondsRemainingNotifier.value = 20;
      recoverySecondsNotifier.value = 0;
      countdownNotifier.value = 0;
    }
  }

  bool get canCancel => !_enforceCompletion;
  bool get isEnforced => _enforceCompletion;

  void dispose() {
    _breakTimer?.cancel();
    _countdownTimer?.cancel();
    _autoTriggerTimer?.cancel();
    _faceDetectionListener?.cancel();
  }
}
