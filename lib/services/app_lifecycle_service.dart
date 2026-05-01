import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';

import 'detection_service.dart';
import 'local_metrics_service.dart';
import 'metrics_service.dart';

class AppLifecycleService {
  AppLifecycleService._private();
  static final AppLifecycleService instance = AppLifecycleService._private();

  bool _backgroundServicesInitialized = false;
  bool _isBackgroundMode = false;
  Future<void> _transitionQueue = Future<void>.value();

  /// Initialize background services (keeps metrics active)
  Future<void> initializeBackgroundServices() async {
    if (_backgroundServicesInitialized) return;

    try {
      await LocalMetricsService.instance.initialize();
      MetricsService.instance.ensureMinuteCounterActive();
      _backgroundServicesInitialized = true;

      if (kDebugMode) debugPrint('[AppLifecycleService] Background services initialized');
    } catch (e) {
      if (kDebugMode) debugPrint('[AppLifecycleService] Error initializing background services: $e');
    }
  }

  /// When app is backgrounded, pause ML Kit camera preview to avoid native issues.
  Future<void> handleAppBackgrounded() async {
    if (_isBackgroundMode) return;
    _isBackgroundMode = true;

    try {
      DetectionService.instance.controller?.pausePreview();
      if (kDebugMode) debugPrint('[AppLifecycleService] Paused camera preview for backgrounded app');
    } catch (e) {
      if (kDebugMode) debugPrint('[AppLifecycleService] Error pausing preview: $e');
    }
  }

  /// When app returns to foreground, resume ML Kit camera preview.
  Future<void> handleAppForegrounded() async {
    if (!_isBackgroundMode) return;
    _isBackgroundMode = false;

    try {
      DetectionService.instance.controller?.resumePreview();
      if (kDebugMode) debugPrint('[AppLifecycleService] Resumed camera preview on foreground');
    } catch (e) {
      if (kDebugMode) debugPrint('[AppLifecycleService] Error resuming preview: $e');
    }
  }

  /// Track app lifecycle state changes
  Future<void> trackScreenState(AppLifecycleState state) async {
    _transitionQueue = _transitionQueue.then((_) async {
      switch (state) {
        case AppLifecycleState.resumed:
          await handleAppForegrounded();
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.hidden:
          await handleAppBackgrounded();
          break;
        case AppLifecycleState.inactive:
          // Ignore transient inactive events
          break;
        case AppLifecycleState.detached:
          await handleAppBackgrounded();
          break;
      }
    }).catchError((e) {
      if (kDebugMode) debugPrint('[AppLifecycleService] Lifecycle transition failed: $e');
    });

    await _transitionQueue;
  }

  /// Cleanup
  Future<void> dispose() async {
    try {
      await LocalMetricsService.instance.dispose();
    } catch (_) {}
    if (kDebugMode) debugPrint('[AppLifecycleService] Disposed');
  }
}