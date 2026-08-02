import 'dart:async';
import 'package:flutter/foundation.dart';

import 'gamification_service.dart';
import 'local_metrics_service.dart';
import 'offline_models.dart';
import 'rule_engine_service.dart';
import 'watch_tracking_session.dart';

class MetricsService {
  MetricsService._privateConstructor();
  static final MetricsService instance = MetricsService._privateConstructor();

  final List<int> _blinkTimestamps = [];
  Timer? _minuteResetTimer;
  int _currentMinuteStamp = _minuteStamp(DateTime.now());

  final ValueNotifier<int> blinkCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> blinkRatePerMinNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentMinuteBlinkCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> distanceCmNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> faceDetectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> calibratedNotifier = ValueNotifier<bool>(false);

  /// After Watch leave/return, blink rate is cold until warm-up completes.
  bool _blinkRateWarm = true;
  DateTime? _faceWarmSince;
  bool _distanceSampleReady = true;

  static const Duration watchResumeGrace = Duration(seconds: 5);
  static const Duration faceWarmDuration = Duration(seconds: 8);
  static const int blinkWarmSampleCount = 5;

  static int _minuteStamp(DateTime value) =>
      value.year * 100000000 + value.month * 1000000 + value.day * 10000 + value.hour * 100 + value.minute;

  bool get blinkRateWarm => _blinkRateWarm;
  bool get distanceSampleReady => _distanceSampleReady;

  void _scheduleMinuteReset() {
    _minuteResetTimer?.cancel();
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final delay = nextMinute.difference(now);
    _minuteResetTimer = Timer(delay, () {
      _rollMinuteWindow(DateTime.now());
      _scheduleMinuteReset();
    });
  }

  void _rollMinuteWindow(DateTime now) {
    final stamp = _minuteStamp(now);
    if (stamp == _currentMinuteStamp) {
      return;
    }

    _currentMinuteStamp = stamp;
    currentMinuteBlinkCountNotifier.value = 0;
  }

  void _ensureMinuteCounterInitialized() {
    if (_minuteResetTimer != null) {
      return;
    }

    _currentMinuteStamp = _minuteStamp(DateTime.now());
    currentMinuteBlinkCountNotifier.value = 0;
    _scheduleMinuteReset();
  }

  DateTime? _evaluationsResumeAt;

  void beginWatchEvaluationGrace() {
    _evaluationsResumeAt = DateTime.now().add(watchResumeGrace);
    _blinkRateWarm = false;
    _faceWarmSince = null;
    _distanceSampleReady = false;
  }

  bool get _inEvaluationGrace {
    final until = _evaluationsResumeAt;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _evaluationsResumeAt = null;
    return false;
  }

  void _updateBlinkWarmth({required bool faceDetected}) {
    if (_blinkRateWarm) return;

    if (!faceDetected) {
      _faceWarmSince = null;
      return;
    }

    _faceWarmSince ??= DateTime.now();
    final faceOkLongEnough =
        DateTime.now().difference(_faceWarmSince!) >= faceWarmDuration;
    final enoughSamples = _blinkTimestamps.length >= blinkWarmSampleCount;
    if (faceOkLongEnough || enoughSamples) {
      _blinkRateWarm = true;
    }
  }

  void _refreshOfflineEngines() {
    if (!WatchTrackingSession.instance.active.value) {
      return;
    }
    if (_inEvaluationGrace) {
      return;
    }

    final blinkRate = blinkRatePerMinNotifier.value;
    final distance = distanceCmNotifier.value;
    final faceDetected = faceDetectedNotifier.value;

    _updateBlinkWarmth(faceDetected: faceDetected);

    RuleEngineService.instance.evaluateLiveMetrics(
      distanceCm: distance,
      blinkRatePerMin: blinkRate,
      faceDetected: faceDetected,
      blinkRateWarm: _blinkRateWarm,
      distanceSampleReady: _distanceSampleReady,
    );

    unawaited(
      GamificationService.instance.recordLiveSample(
        distanceCm: distance,
        blinkRatePerMin: blinkRate,
        faceDetected: faceDetected,
      ),
    );
  }

  void registerBlink() {
    _ensureMinuteCounterInitialized();
    _rollMinuteWindow(DateTime.now());

    final now = DateTime.now().millisecondsSinceEpoch;
    _blinkTimestamps.add(now);
    final cutoff = now - 60000;
    while (_blinkTimestamps.isNotEmpty && _blinkTimestamps.first < cutoff) {
      _blinkTimestamps.removeAt(0);
    }
    blinkCountNotifier.value = blinkCountNotifier.value + 1;
    currentMinuteBlinkCountNotifier.value = currentMinuteBlinkCountNotifier.value + 1;
    blinkRatePerMinNotifier.value = _blinkTimestamps.length;
    unawaited(GamificationService.instance.recordHealthyBlinkLogged());
    _refreshOfflineEngines();
    unawaited(
      LocalMetricsService.instance.logRawEvent(
        'blinkRate',
        blinkRatePerMinNotifier.value.toDouble(),
        DateTime.now(),
      ),
    );
  }

  void resetBlinks() {
    _blinkTimestamps.clear();
    blinkCountNotifier.value = 0;
    blinkRatePerMinNotifier.value = 0;
    currentMinuteBlinkCountNotifier.value = 0;
    _currentMinuteStamp = _minuteStamp(DateTime.now());
    _ensureMinuteCounterInitialized();
  }

  void setDistance(double cm) {
    distanceCmNotifier.value = cm;
    if (cm > 0) {
      _distanceSampleReady = true;
    }
    _refreshOfflineEngines();
    unawaited(LocalMetricsService.instance.logRawEvent('distanceCm', cm, DateTime.now()));
  }

  void setFaceDetected(bool v) {
    faceDetectedNotifier.value = v;

    if (!WatchTrackingSession.instance.active.value) {
      GamificationService.instance.stopFaceLossPenalty();
      return;
    }

    if (!v) {
      _faceWarmSince = null;
      GamificationService.instance.startFaceLossPenalty();
    } else {
      GamificationService.instance.stopFaceLossPenalty();
    }

    _refreshOfflineEngines();
  }

  /// Clear live tracking state when leaving Watch Area without starting face-loss.
  void clearLiveTrackingState() {
    faceDetectedNotifier.value = false;
    distanceCmNotifier.value = 0.0;
    _blinkTimestamps.clear();
    blinkRatePerMinNotifier.value = 0;
    currentMinuteBlinkCountNotifier.value = 0;
    _blinkRateWarm = false;
    _faceWarmSince = null;
    _distanceSampleReady = false;
    GamificationService.instance.stopFaceLossPenalty();
    RuleEngineService.instance.triggerOverlay(AlertLevel.none, 'tracking inactive');
  }

  void setCalibrated(bool v) {
    calibratedNotifier.value = v;
    _refreshOfflineEngines();
  }

  void ensureMinuteCounterActive() {
    _ensureMinuteCounterInitialized();
    _rollMinuteWindow(DateTime.now());
  }

  /// Clear all metrics and reset notifiers (used on logout)
  void clearAllMetrics() {
    _blinkTimestamps.clear();
    _minuteResetTimer?.cancel();
    _minuteResetTimer = null;

    blinkCountNotifier.value = 0;
    blinkRatePerMinNotifier.value = 0;
    currentMinuteBlinkCountNotifier.value = 0;
    distanceCmNotifier.value = 0.0;
    faceDetectedNotifier.value = false;
    calibratedNotifier.value = false;
    _blinkRateWarm = true;
    _faceWarmSince = null;
    _distanceSampleReady = true;

    _currentMinuteStamp = _minuteStamp(DateTime.now());
  }
}
