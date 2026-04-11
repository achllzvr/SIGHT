import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ActiveChildContextService {
  ActiveChildContextService._private();

  static final ActiveChildContextService instance = ActiveChildContextService._private();

  static const _activeChildIdKey = 'active_child_id';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final ValueNotifier<int?> activeChildIdNotifier = ValueNotifier<int?>(null);
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final storedValue = await _storage.read(key: _activeChildIdKey);
    activeChildIdNotifier.value = int.tryParse(storedValue ?? '');
    _initialized = true;
  }

  Future<int?> getActiveChildId() async {
    await initialize();
    return activeChildIdNotifier.value;
  }

  Future<void> setActiveChildId(int? childId) async {
    await initialize();
    activeChildIdNotifier.value = childId;

    if (childId == null) {
      await _storage.delete(key: _activeChildIdKey);
      return;
    }

    await _storage.write(key: _activeChildIdKey, value: childId.toString());
  }

  /// Clear active child context (used on logout)
  Future<void> clearActiveChild() async {
    await setActiveChildId(null);
  }
}