import 'dart:async';
import 'package:flutter_background/flutter_background.dart';
import 'detection_service.dart';
import 'metrics_service.dart';

class BackgroundNotificationService {
  BackgroundNotificationService._private();
  static final BackgroundNotificationService instance = BackgroundNotificationService._private();

  Timer? _timer;
  bool _enabled = false;
  String? _lastError;

  String? get lastError => _lastError;

  Future<bool> _updateNotificationOnce() async {
    _lastError = null;
    final calibrated = MetricsService.instance.calibratedNotifier.value;
    if (!calibrated) {
      if (_enabled) {
        try {
          await DetectionService.instance.disableWakelock();
          await FlutterBackground.disableBackgroundExecution();
        } catch (_) {}
        _enabled = false;
      }
      return false;
    }

    await DetectionService.instance.enableWakelockForMonitoring();

    final blinksPerMin = MetricsService.instance.blinkRatePerMinNotifier.value;
    final dist = MetricsService.instance.distanceCmNotifier.value;
    final title = 'SIGHT monitoring active';
    final hasFreshFrames = DetectionService.instance.hasFreshFrames;
    final text = hasFreshFrames
        ? 'Blinks/min: $blinksPerMin • Distance: ${dist > 0 ? dist.toStringAsFixed(1) + "cm" : "--"}'
        : 'Camera paused in background • Last: ${dist > 0 ? dist.toStringAsFixed(1) + "cm" : "--"}';

    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: title,
      notificationText: text,
      enableWifiLock: true,
    );
    final ok = await FlutterBackground.initialize(androidConfig: androidConfig);
    if (!ok) {
      _lastError = 'FlutterBackground.initialize() returned false';
      return false;
    }

    if (!_enabled) {
      await FlutterBackground.enableBackgroundExecution();
      _enabled = true;
    }

    return true;
  }

  Future<bool> refreshNow() async {
    try {
      return await _updateNotificationOnce();
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<void> start() async {
    final initialOk = await refreshNow();
    if (!initialOk) {
      // Keep timer running so service can recover when permissions/settings change.
    }
    if (_timer != null) return;

    _timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      await refreshNow();
    });
  }

  Future<void> stop() async {
    try {
      await DetectionService.instance.disableWakelock();
      await FlutterBackground.disableBackgroundExecution();
    } catch (_) {}
    _enabled = false;
    _timer?.cancel();
    _timer = null;
  }
}
