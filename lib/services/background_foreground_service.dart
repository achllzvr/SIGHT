import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// BackgroundForegroundService manages native background monitoring:
/// - Android: Foreground service to keep camera and detection running in background
/// - iOS: Background app refresh modes and local notifications
class BackgroundForegroundService {
  BackgroundForegroundService._private();

  static final BackgroundForegroundService instance = BackgroundForegroundService._private();

  static const MethodChannel _backgroundChannel =
      MethodChannel('com.example.sight_feasibility_lab/background_service');

  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Starts the background foreground service (Android) or background app refresh (iOS)
  /// Returns true if successfully started, false otherwise
  Future<bool> startBackgroundMonitoring() async {
    if (_isRunning) {
      if (kDebugMode) {
        debugPrint('[BackgroundForegroundService] Service already running');
      }
      return true;
    }

    try {
      if (Platform.isAndroid) {
        // Request notification permission for foreground service
        final notificationStatus = await Permission.notification.request();
        if (!notificationStatus.isGranted) {
          if (kDebugMode) {
            debugPrint('[BackgroundForegroundService] Notification permission denied');
          }
          return false;
        }

        // Invoke native method to start foreground service
        final result = await _backgroundChannel.invokeMethod<bool>('startForegroundService');
        _isRunning = result ?? false;

        if (_isRunning) {
          if (kDebugMode) {
            debugPrint('[BackgroundForegroundService] Android foreground service started');
          }
        }
      } else if (Platform.isIOS) {
        // For iOS, configure background app refresh modes
        final result = await _backgroundChannel.invokeMethod<bool>('configureBackgroundModes');
        _isRunning = result ?? false;

        if (_isRunning) {
          if (kDebugMode) {
            debugPrint('[BackgroundForegroundService] iOS background modes configured');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundForegroundService] Error starting service: $e');
      }
      _isRunning = false;
    }

    return _isRunning;
  }

  /// Stops the background foreground service
  Future<bool> stopBackgroundMonitoring() async {
    if (!_isRunning) {
      return true;
    }

    try {
      if (Platform.isAndroid) {
        final result = await _backgroundChannel.invokeMethod<bool>('stopForegroundService');
        _isRunning = !(result ?? true);

        if (!_isRunning) {
          if (kDebugMode) {
            debugPrint('[BackgroundForegroundService] Android foreground service stopped');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundForegroundService] Error stopping service: $e');
      }
    }

    return !_isRunning;
  }

  /// Updates the foreground service notification (Android only)
  /// Displays current metrics and status
  Future<bool> updateNotification({
    required String title,
    required String message,
  }) async {
    if (!Platform.isAndroid || !_isRunning) {
      return false;
    }

    try {
      final result = await _backgroundChannel.invokeMethod<bool>(
        'updateNotification',
        {
          'title': title,
          'message': message,
        },
      );
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundForegroundService] Error updating notification: $e');
      }
      return false;
    }
  }

  /// Checks foreground service permission status (Android)
  Future<bool> hasForegroundServicePermission() async {
    if (!Platform.isAndroid) {
      return true; // iOS doesn't require explicit foreground service permission
    }

    try {
      final result = await _backgroundChannel.invokeMethod<bool>('hasForegroundServicePermission');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundForegroundService] Error checking permission: $e');
      }
      return false;
    }
  }

  /// Requests foreground service permission (Android 12+)
  Future<bool> requestForegroundServicePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      final result = await _backgroundChannel.invokeMethod<bool>('requestForegroundServicePermission');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundForegroundService] Error requesting permission: $e');
      }
      return false;
    }
  }

  /// Cleanup and shutdown
  Future<void> dispose() async {
    await stopBackgroundMonitoring();
  }
}
