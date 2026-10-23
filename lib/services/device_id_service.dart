import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stable per-install device id so each phone gets its own Sanctum token
/// (per-device unlimited tokens — logging in elsewhere never revokes this device).
class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  static const _key = 'lumi_device_id';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _cached;

  Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;
    try {
      final existing = await _storage.read(key: _key);
      if (existing != null && existing.isNotEmpty) {
        _cached = existing;
        return existing;
      }
    } catch (_) {
      // Corrupt secure storage (e.g. BAD_DECRYPT) — fall through and mint a fresh id.
    }
    final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'other');
    final rand = List.generate(4, (_) => Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0')).join();
    final id = '$platform-$rand';
    try {
      await _storage.write(key: _key, value: id);
    } catch (_) {}
    _cached = id;
    return id;
  }
}
