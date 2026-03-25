import 'dart:async';
import 'package:flutter_background/flutter_background.dart';
import 'metrics_service.dart';

class BackgroundNotificationService {
  BackgroundNotificationService._private();
  static final BackgroundNotificationService instance = BackgroundNotificationService._private();

  Timer? _timer;
  bool _enabled = false;

  Future<void> start() async {
    // Listen to calibration state and enable/disable background notification
    // Simple polling approach: update notification periodically when calibrated
    _timer = Timer.periodic(const Duration(seconds: 3), (t) async {
      final calibrated = MetricsService.instance.calibratedNotifier.value;
      if (!calibrated) {
        if (_enabled) {
          try {
            await FlutterBackground.disableBackgroundExecution();
          } catch (_) {}
          _enabled = false;
        }
        return;
      }
      final blinks = MetricsService.instance.blinkCountNotifier.value;
      final dist = MetricsService.instance.distanceCmNotifier.value;
      final title = 'Sight running';
      final text = 'Distance: ${dist > 0 ? dist.toStringAsFixed(1) + "cm" : "--"} • Blinks: $blinks';
      try {
        final androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: title,
          notificationText: text,
          enableWifiLock: true,
        );
        final ok = await FlutterBackground.initialize(androidConfig: androidConfig);
        if (ok && !_enabled) {
          await FlutterBackground.enableBackgroundExecution();
          _enabled = true;
        }
      } catch (e) {
        // ignore
      }
    });
  }

  Future<void> stop() async {
    try {
      await FlutterBackground.disableBackgroundExecution();
    } catch (_) {}
    _enabled = false;
    _timer?.cancel();
  }
}
