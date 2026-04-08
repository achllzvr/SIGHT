import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'background_foreground_service.dart';
import 'detection_service.dart';
import 'local_metrics_service.dart';

class AppLifecycleService {
  AppLifecycleService._private();
  static final AppLifecycleService instance = AppLifecycleService._private();

  bool _backgroundServicesInitialized = false;

  /// Initialize background services (must be called during app startup)
  Future<void> initializeBackgroundServices() async {
    if (_backgroundServicesInitialized) {
      return;
    }

    try {
      // Initialize local metrics service
      await LocalMetricsService.instance.initialize();

      _backgroundServicesInitialized = true;

      if (kDebugMode) {
        debugPrint('[AppLifecycleService] Background services initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppLifecycleService] Error initializing background services: $e');
      }
    }
  }

  /// Start background monitoring (called when app is backgrounded)
  Future<void> handleAppBackgrounded() async {
    try {
      // Enable wakelock to keep device awake during background monitoring
      await DetectionService.instance.enableWakelockForMonitoring();

      // Start the foreground service (Android) or configure background modes (iOS)
      await BackgroundForegroundService.instance.startBackgroundMonitoring();

      // Ensure detection continues in background
      await DetectionService.instance.ensureContinuousMonitoring();

      // Attempt immediate sync of any pending batches
      await LocalMetricsService.instance.attemptBackgroundSync();

      if (kDebugMode) {
        debugPrint('[AppLifecycleService] App backgrounded - background monitoring started');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppLifecycleService] Error in handleAppBackgrounded: $e');
      }
    }
  }

  /// Resume foreground monitoring (called when app is foregrounded)
  Future<void> handleAppForegrounded() async {
    try {
      // Force hard restart of detection to ensure fresh camera stream
      await DetectionService.instance.forceHardRestart();

      // Attempt to sync any new data
      await LocalMetricsService.instance.attemptBackgroundSync();

      if (kDebugMode) {
        debugPrint('[AppLifecycleService] App foregrounded - detection restarted');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppLifecycleService] Error in handleAppForegrounded: $e');
      }
    }
  }

  /// Track app lifecycle state changes
  Future<void> trackScreenState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await handleAppForegrounded();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        await handleAppBackgrounded();
        break;
    }
  }

  /// Cleanup and shutdown
  Future<void> dispose() async {
    await BackgroundForegroundService.instance.dispose();
    await LocalMetricsService.instance.dispose();

    if (kDebugMode) {
      debugPrint('[AppLifecycleService] Disposed');
    }
  }
}