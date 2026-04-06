import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CriticalOverlayService {
  CriticalOverlayService._private();

  static final CriticalOverlayService instance = CriticalOverlayService._private();

  static const MethodChannel _channel = MethodChannel('com.example.sight_feasibility_lab/critical_overlay');

  Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final status = await Permission.systemAlertWindow.status;
    if (status.isGranted) {
      return true;
    }

    final requested = await Permission.systemAlertWindow.request();
    return requested.isGranted;
  }

  Future<bool> showCriticalOverlay() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final hasPermission = await ensurePermission();
    if (!hasPermission) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('showCriticalOverlay');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hideCriticalOverlay() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('hideCriticalOverlay');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isCriticalOverlayShowing() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('isCriticalOverlayShowing');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}