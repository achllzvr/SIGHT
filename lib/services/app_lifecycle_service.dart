import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';

import 'background_foreground_service.dart';
import 'detection_service.dart';
import 'local_metrics_service.dart';
import 'metrics_service.dart';

class AppLifecycleService {
  AppLifecycleService._private();
  static final AppLifecycleService instance = AppLifecycleService._private();

  bool _backgroundServicesInitialized = false;
  Timer? _backgroundHeartbeat;

  /// Initialize background services (must be called during app startup)
  Future<void> initializeBackgroundServices() async {
    if (_backgroundServicesInitialized) {
      return;
    }

    try {
      // Initialize local metrics service
      await LocalMetricsService.instance.initialize();
      MetricsService.instance.ensureMinuteCounterActive();

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

  Future<void> _runBackgroundHeartbeatTick() async {
    try {
      await DetectionService.instance.ensureContinuousMonitoring();

      final hasFreshFrames = DetectionService.instance.hasFreshFrames;
      final distance = MetricsService.instance.distanceCmNotifier.value;
      final minuteBlinks = MetricsService.instance.currentMinuteBlinkCountNotifier.value;
      final status = hasFreshFrames ? 'active' : 'recovering';
      final distanceText = distance > 0 ? '${distance.toStringAsFixed(1)}cm' : '--';

      await BackgroundForegroundService.instance.updateNotification(
        title: 'SIGHT monitoring $status',
        message: 'Blinks this min: $minuteBlinks • Distance: $distanceText',
      );

      await BackgroundForegroundService.instance.updateFloatingBubble(
        blinkCountThisMinute: minuteBlinks,
        distanceCm: distance,
        isTracking: hasFreshFrames,
      );

      if (!hasFreshFrames) {
        await DetectionService.instance.forceHardRestart();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppLifecycleService] Background heartbeat tick failed: $e');
      }
    }
  }

  void _startBackgroundHeartbeat() {
    if (_backgroundHeartbeat != null) {
      return;
    }

    _backgroundHeartbeat = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_runBackgroundHeartbeatTick());
    });
  }

  void _stopBackgroundHeartbeat() {
    _backgroundHeartbeat?.cancel();
    _backgroundHeartbeat = null;
  }

  /// Start background monitoring (called when app is backgrounded)
  Future<void> handleAppBackgrounded() async {
    try {
      // Enable wakelock to keep device awake during background monitoring
      await DetectionService.instance.enableWakelockForMonitoring();

      // Start the foreground service (Android) or configure background modes (iOS)
      await BackgroundForegroundService.instance.startBackgroundMonitoring();

      final canDrawOverlay = await BackgroundForegroundService.instance.canDrawOverlays();
      if (canDrawOverlay) {
        await BackgroundForegroundService.instance.showFloatingBubble();
      }

      // Ensure detection continues in background
      await DetectionService.instance.ensureContinuousMonitoring();
      _startBackgroundHeartbeat();
      await _runBackgroundHeartbeatTick();

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
      _stopBackgroundHeartbeat();
      await BackgroundForegroundService.instance.hideFloatingBubble();
      await BackgroundForegroundService.instance.stopBackgroundMonitoring();

      // Force hard restart of detection to ensure fresh camera stream
      await DetectionService.instance.forceHardRestart();
      await DetectionService.instance.ensureMonitoringWithRetry();

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
    _stopBackgroundHeartbeat();
    await BackgroundForegroundService.instance.dispose();
    await LocalMetricsService.instance.dispose();

    if (kDebugMode) {
      debugPrint('[AppLifecycleService] Disposed');
    }
  }
}