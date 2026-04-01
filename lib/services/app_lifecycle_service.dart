import 'package:flutter/widgets.dart';

import 'detection_service.dart';
import 'local_metrics_service.dart';

class AppLifecycleService {
  AppLifecycleService._private();
  static final AppLifecycleService instance = AppLifecycleService._private();

  Future<void> handleAppBackgrounded() async {
    await DetectionService.instance.enableWakelockForMonitoring();
    await LocalMetricsService.instance.curateThirtyMinuteBatch();
    await LocalMetricsService.instance.attemptBackgroundSync();
  }

  Future<void> trackScreenState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await DetectionService.instance.forceHardRestart();
        await LocalMetricsService.instance.attemptBackgroundSync();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        await handleAppBackgrounded();
        break;
    }
  }
}