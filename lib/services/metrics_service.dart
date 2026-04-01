import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'gamification_service.dart';
import 'local_metrics_service.dart';
import 'rule_engine_service.dart';

class MetricsService {
  MetricsService._privateConstructor();
  static final MetricsService instance = MetricsService._privateConstructor();

  final List<int> _blinkTimestamps = [];

  final ValueNotifier<int> blinkCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> blinkRatePerMinNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> distanceCmNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> faceDetectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> calibratedNotifier = ValueNotifier<bool>(false);

  void _refreshOfflineEngines() {
    final blinkRate = blinkRatePerMinNotifier.value;
    final distance = distanceCmNotifier.value;
    final faceDetected = faceDetectedNotifier.value;

    RuleEngineService.instance.evaluateLiveMetrics(
      distanceCm: distance,
      blinkRatePerMin: blinkRate,
      faceDetected: faceDetected,
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
    final now = DateTime.now().millisecondsSinceEpoch;
    _blinkTimestamps.add(now);
    final cutoff = now - 60000;
    while (_blinkTimestamps.isNotEmpty && _blinkTimestamps.first < cutoff) {
      _blinkTimestamps.removeAt(0);
    }
    blinkCountNotifier.value = blinkCountNotifier.value + 1;
    blinkRatePerMinNotifier.value = _blinkTimestamps.length;
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
  }

  void setDistance(double cm) {
    distanceCmNotifier.value = cm;
    _refreshOfflineEngines();
    unawaited(LocalMetricsService.instance.logRawEvent('distanceCm', cm, DateTime.now()));
  }

  void setFaceDetected(bool v) {
    faceDetectedNotifier.value = v;
    _refreshOfflineEngines();
  }

  void setCalibrated(bool v) {
    calibratedNotifier.value = v;
    _refreshOfflineEngines();
  }
}
