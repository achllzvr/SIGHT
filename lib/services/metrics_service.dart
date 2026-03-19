import 'dart:collection';
import 'package:flutter/foundation.dart';

class MetricsService {
  MetricsService._privateConstructor();
  static final MetricsService instance = MetricsService._privateConstructor();

  // Blink counts over time (milliseconds since epoch)
  final List<int> _blinkTimestamps = [];

  // Notifiers to expose to UI
  final ValueNotifier<int> blinkCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> blinkRatePerMinNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> distanceCmNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> faceDetectedNotifier = ValueNotifier<bool>(false);

  void registerBlink() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _blinkTimestamps.add(now);
    // prune older than 60s
    final cutoff = now - 60000;
    while (_blinkTimestamps.isNotEmpty && _blinkTimestamps.first < cutoff) {
      _blinkTimestamps.removeAt(0);
    }
    blinkCountNotifier.value = blinkCountNotifier.value + 1;
    blinkRatePerMinNotifier.value = _blinkTimestamps.length;
  }

  void resetBlinks() {
    _blinkTimestamps.clear();
    blinkCountNotifier.value = 0;
    blinkRatePerMinNotifier.value = 0;
  }

  void setDistance(double cm) {
    distanceCmNotifier.value = cm;
  }

  void setFaceDetected(bool v) {
    faceDetectedNotifier.value = v;
  }
}
