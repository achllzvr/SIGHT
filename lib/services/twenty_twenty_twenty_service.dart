import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'detection_service.dart';
import 'feedback_service.dart';
import 'gamification_service.dart';
import 'watch_tracking_session.dart';

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

  static const int breakIntervalSeconds = 1200; // 20 minutes of Watch Area time
  static const int resumeGraceSeconds = 3;

  final ValueNotifier<BreakState> stateNotifier = ValueNotifier<BreakState>(BreakState.inactive);
  final ValueNotifier<int> secondsRemainingNotifier = ValueNotifier<int>(20);
  final ValueNotifier<int> countdownNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> faceDetectedNotifier = ValueNotifier<bool>(false);

  bool _initialized = false;
  Timer? _breakTimer;
  Timer? _countdownTimer;
  Timer? _autoTriggerTimer;
  Timer? _faceDetectionListener;

  bool _enforceCompletion = false;
  bool _breakJustCompleted = false;
  bool _holdingCamera = false;
  bool _autoEnforceBreaks = true;

  /// Watch-Area seconds accumulated since last completed break (paused while away).
  int _accumulatedWatchSeconds = 0;
  DateTime? _watchSegmentStartedAt;
  DateTime? _resumeGraceUntil;
  bool _watchSessionActive = false;

  Future<void> initialize({bool startDetection = false}) async {
    if (_initialized) {
      return;
    }

    if (startDetection) {
      await DetectionService.instance.initialize();
    }
    _initialized = true;
    _accumulatedWatchSeconds = 0;
    _setupAutoTrigger();

    if (kDebugMode) {
      debugPrint('[Eye Rest Service] Initialized');
    }
  }

  void setAutoEnforceBreaks(bool enabled) {
    _autoEnforceBreaks = enabled;
  }

  /// Call when entering Watch Area — resumes intervention clock with a short grace.
  void resumeWatchSession() {
    if (_watchSessionActive) return;
    _watchSessionActive = true;
    _watchSegmentStartedAt = DateTime.now();
    _resumeGraceUntil = DateTime.now().add(const Duration(seconds: resumeGraceSeconds));
    if (kDebugMode) {
      debugPrint('[Eye Rest] Watch session resumed (accumulated=${_accumulatedWatchSeconds}s)');
    }
  }

  /// Call when leaving Watch Area — freezes intervention clock (away time does not count).
  void pauseWatchSession() {
    if (!_watchSessionActive) return;
    _flushOpenSegment();
    _watchSessionActive = false;
    _watchSegmentStartedAt = null;
    _resumeGraceUntil = null;
    if (kDebugMode) {
      debugPrint('[Eye Rest] Watch session paused (accumulated=${_accumulatedWatchSeconds}s)');
    }
  }

  void _flushOpenSegment() {
    if (_watchSegmentStartedAt == null) return;
    final delta = DateTime.now().difference(_watchSegmentStartedAt!).inSeconds;
    if (delta > 0) {
      _accumulatedWatchSeconds += delta;
    }
    _watchSegmentStartedAt = null;
  }

  int _currentWatchElapsedSeconds() {
    var total = _accumulatedWatchSeconds;
    if (_watchSessionActive && _watchSegmentStartedAt != null) {
      total += DateTime.now().difference(_watchSegmentStartedAt!).inSeconds;
    }
    return total;
  }

  void _setupAutoTrigger() {
    _autoTriggerTimer?.cancel();
    _autoTriggerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_watchSessionActive) return;
      if (_resumeGraceUntil != null && DateTime.now().isBefore(_resumeGraceUntil!)) {
        return;
      }
      if (stateNotifier.value != BreakState.inactive) return;
      if (!WatchTrackingSession.instance.active.value) return;
      if (!_autoEnforceBreaks) return;

      if (_currentWatchElapsedSeconds() >= breakIntervalSeconds) {
        _triggerAutoBreak();
      }
    });
  }

  void _triggerAutoBreak() {
    if (!WatchTrackingSession.instance.active.value) {
      return;
    }
    if (stateNotifier.value != BreakState.inactive) {
      return;
    }

    _enforceCompletion = true;
    stateNotifier.value = BreakState.askingPermission;

    if (kDebugMode) {
      debugPrint('[Eye Rest] Auto-triggered break');
    }
  }

  void requestBreak() {
    if (stateNotifier.value != BreakState.inactive) {
      return;
    }

    _enforceCompletion = false;
    stateNotifier.value = BreakState.askingPermission;
  }

  /// Start the 20-second look-away break (no 1/2 min recovery choice).
  Future<void> startBreak() async {
    if (stateNotifier.value != BreakState.askingPermission) {
      return;
    }

    await DetectionService.instance.acquireMonitoring(resolution: ResolutionPreset.low);
    _holdingCamera = true;
    DetectionService.instance.faceDetected.value = false;
    faceDetectedNotifier.value = false;

    stateNotifier.value = BreakState.running;
    secondsRemainingNotifier.value = 20;
    _startBreakTimer();
  }

  /// Backward-compatible alias — minutes ignored; always 20s look-away.
  Future<void> confirmBreakWithRecoveryTime(int minutes) => startBreak();

  void _startBreakTimer() {
    _breakTimer?.cancel();
    secondsRemainingNotifier.value = 20;
    _setupFaceDetectionListener();

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isLookingAtPhone()) {
        return;
      }

      final remaining = secondsRemainingNotifier.value - 1;
      if (remaining <= 0) {
        _breakTimer?.cancel();
        _startCountdown();
      } else {
        secondsRemainingNotifier.value = remaining;
      }
    });
  }

  bool _isLookingAtPhone() {
    final detection = DetectionService.instance;
    if (!detection.hasFreshFrames) {
      return false;
    }
    return detection.faceDetected.value;
  }

  void _setupFaceDetectionListener() {
    _faceDetectionListener?.cancel();
    _faceDetectionListener = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final looking = _isLookingAtPhone();
      faceDetectedNotifier.value = looking;

      if (looking && stateNotifier.value == BreakState.running) {
        secondsRemainingNotifier.value = 20;
      }
    });
  }

  void _startCountdown() {
    if (stateNotifier.value != BreakState.running) {
      return;
    }

    _faceDetectionListener?.cancel();
    stateNotifier.value = BreakState.countdown;
    countdownNotifier.value = 10;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final remaining = countdownNotifier.value - 1;
      FeedbackService.instance.blinkDetected();

      if (remaining <= 0) {
        _countdownTimer?.cancel();
        unawaited(_completeBreak());
      } else {
        countdownNotifier.value = remaining;
      }
    });
  }

  Future<void> _completeBreak() async {
    await _releaseCameraIfHeld();
    stateNotifier.value = BreakState.completed;
    countdownNotifier.value = 0;
    _accumulatedWatchSeconds = 0;
    if (_watchSessionActive) {
      _watchSegmentStartedAt = DateTime.now();
    }
    _enforceCompletion = false;
    FeedbackService.instance.exerciseCompleted();
    unawaited(GamificationService.instance.recordBreakCompleted202020());

    _breakJustCompleted = true;
    Future.delayed(const Duration(seconds: 2), () {
      _breakJustCompleted = false;
    });
  }

  Future<void> _releaseCameraIfHeld() async {
    if (!_holdingCamera) return;
    _holdingCamera = false;
    await DetectionService.instance.releaseMonitoring();
  }

  bool get breakJustCompleted => _breakJustCompleted;

  Future<void> cancelBreak() async {
    if (_enforceCompletion) {
      return;
    }

    _breakTimer?.cancel();
    _countdownTimer?.cancel();
    _faceDetectionListener?.cancel();
    await _releaseCameraIfHeld();
    stateNotifier.value = BreakState.inactive;
    secondsRemainingNotifier.value = 20;
    faceDetectedNotifier.value = false;
  }

  Future<void> resetBreakState() async {
    if (stateNotifier.value == BreakState.completed) {
      await _releaseCameraIfHeld();
      stateNotifier.value = BreakState.inactive;
      secondsRemainingNotifier.value = 20;
      countdownNotifier.value = 0;
      faceDetectedNotifier.value = false;
    }
  }

  bool get canCancel => !_enforceCompletion;
  bool get isEnforced => _enforceCompletion;

  void dispose() {
    _breakTimer?.cancel();
    _countdownTimer?.cancel();
    _autoTriggerTimer?.cancel();
    _faceDetectionListener?.cancel();
    unawaited(_releaseCameraIfHeld());
  }
}
