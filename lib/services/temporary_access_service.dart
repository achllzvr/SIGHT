import 'package:flutter/foundation.dart';

import 'api_client_service.dart';
import 'api_config_service.dart';

class TemporaryAccessResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? message;

  const TemporaryAccessResult({
    required this.success,
    this.data,
    this.message,
  });
}

class TemporaryAccessService {
  TemporaryAccessService._private();
  static final TemporaryAccessService instance = TemporaryAccessService._private();

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _messageFrom(ApiClientResponse response) {
    final data = response.data;
    if (data is Map) {
      final message = data['message']?.toString();
      if (message != null && message.trim().isNotEmpty) return message.trim();
    }
    if (response.statusCode == 401) return 'Please log in again to share with a doctor.';
    if (response.statusCode == 403) return 'You do not have permission to share this child.';
    if (response.statusCode == 404) return 'Child or guardian profile was not found.';
    if (response.statusCode >= 500) {
      return 'Server error while creating the share code. Please try again.';
    }
    return null;
  }

  Future<TemporaryAccessResult> generateToken(int childId) async {
    try {
      final uri = ApiConfigService.buildUri('/api/mobile/children/$childId/access-tokens');
      final response = await ApiClientService.instance.post(uri, jsonBody: {});
      if (response.isSuccess) {
        final root = _asMap(response.data);
        final data = _asMap(root?['data']);
        if (data != null) {
          return TemporaryAccessResult(success: true, data: data);
        }
        return const TemporaryAccessResult(
          success: false,
          message: 'Share code response was incomplete.',
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[TemporaryAccess] generateToken failed (${response.statusCode}): ${response.rawBody}',
        );
      }
      return TemporaryAccessResult(
        success: false,
        message: _messageFrom(response) ?? 'Could not generate access code.',
      );
    } catch (e) {
      return const TemporaryAccessResult(
        success: false,
        message: 'Network error while generating access code.',
      );
    }
  }

  Future<Map<String, dynamic>?> getActiveSession(int childId) async {
    try {
      final uri = ApiConfigService.buildUri('/api/mobile/children/$childId/access-session');
      final response = await ApiClientService.instance.get(uri);
      if (response.isSuccess) {
        final root = _asMap(response.data);
        return _asMap(root?['data']);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TemporaryAccess] getActiveSession: $e');
    }
    return null;
  }

  Future<bool> endSession(int sessionId) async {
    try {
      final uri = ApiConfigService.buildUri('/api/mobile/access-sessions/$sessionId/end');
      final response = await ApiClientService.instance.post(uri, jsonBody: {});
      return response.isSuccess;
    } catch (_) {
      return false;
    }
  }

  Future<AccessLogsResult> getAccessLogs(int childId) async {
    try {
      final uri = ApiConfigService.buildUri('/api/mobile/children/$childId/access-logs');
      final response = await ApiClientService.instance.get(uri);
      final parsed = _parseLogsResponse(response);
      if (parsed.error != null && kDebugMode) {
        debugPrint('[TemporaryAccess] getAccessLogs($childId): ${parsed.error}');
      }
      return AccessLogsResult(logs: parsed.logs, error: parsed.error);
    } catch (e) {
      if (kDebugMode) debugPrint('[TemporaryAccess] getAccessLogs: $e');
      return const AccessLogsResult(
        logs: [],
        error: 'Network error while loading viewing history.',
      );
    }
  }

  /// Viewing history across linked children.
  ///
  /// Tries the guardian-wide endpoint first, then falls back to fetching each
  /// child's `/access-logs` (needed when production has not deployed the newer route).
  Future<AccessLogsResult> getGuardianAccessLogs({List<int> childIds = const []}) async {
    try {
      final uri = ApiConfigService.buildUri('/api/mobile/guardian/access-logs');
      final response = await ApiClientService.instance.get(uri);
      final parsed = _parseLogsResponse(response);
      if (response.isSuccess) {
        return AccessLogsResult(logs: parsed.logs);
      }
      if (kDebugMode) {
        debugPrint(
          '[TemporaryAccess] guardian/access-logs failed (${response.statusCode}); falling back per child',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TemporaryAccess] getGuardianAccessLogs: $e');
    }

    if (childIds.isEmpty) {
      return const AccessLogsResult(
        logs: [],
        error: 'Could not load viewing history. Please try again.',
      );
    }

    final merged = <Map<String, dynamic>>[];
    String? lastError;
    for (final childId in childIds.where((id) => id > 0)) {
      try {
        final uri = ApiConfigService.buildUri('/api/mobile/children/$childId/access-logs');
        final response = await ApiClientService.instance.get(uri);
        final parsed = _parseLogsResponse(response);
        if (!response.isSuccess) {
          lastError = parsed.error ?? _messageFrom(response) ?? 'Could not load viewing history.';
          continue;
        }
        merged.addAll(parsed.logs);
      } catch (e) {
        lastError = 'Network error while loading viewing history.';
        if (kDebugMode) debugPrint('[TemporaryAccess] per-child access-logs($childId): $e');
      }
    }

    merged.sort((a, b) {
      final aAt = DateTime.tryParse(a['accessed_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = DateTime.tryParse(b['accessed_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });

    if (merged.isEmpty && lastError != null) {
      return AccessLogsResult(logs: const [], error: lastError);
    }
    return AccessLogsResult(logs: List<Map<String, dynamic>>.unmodifiable(merged));
  }

  _ParsedAccessLogs _parseLogsResponse(ApiClientResponse response) {
    if (!response.isSuccess) {
      if (kDebugMode) {
        debugPrint(
          '[TemporaryAccess] access-logs failed (${response.statusCode}): ${response.rawBody}',
        );
      }
      return _ParsedAccessLogs(
        logs: const [],
        error: _messageFrom(response) ?? 'Could not load viewing history (${response.statusCode}).',
      );
    }

    final root = _asMap(response.data);
    if (root == null) {
      return const _ParsedAccessLogs(logs: [], error: 'Unexpected viewing history response.');
    }

    dynamic logs = _asMap(root['data'])?['logs'];
    logs ??= root['logs'];
    if (logs == null && root['data'] is List) logs = root['data'];

    // Some hosts wrap payload as data: { data: { logs: [...] } }
    if (logs == null) {
      final nested = _asMap(_asMap(root['data'])?['data']);
      logs = nested?['logs'];
    }

    if (logs is! List) {
      return const _ParsedAccessLogs(logs: [], error: 'Viewing history response was incomplete.');
    }

    final mapped = logs
        .whereType<Object>()
        .map((item) {
          if (item is Map<String, dynamic>) return item;
          if (item is Map) return Map<String, dynamic>.from(item);
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return _ParsedAccessLogs(logs: mapped);
  }

  Future<bool> ingestActivity({
    required String eventTag,
    int? childId,
    dynamic oldValue,
    dynamic newValue,
  }) async {
    try {
      final uri = ApiConfigService.buildUri('/api/mobile/activity-logs');
      final response = await ApiClientService.instance.post(uri, jsonBody: {
        'event_tag': eventTag,
        if (childId != null) 'child_id': childId,
        'old_value': oldValue,
        'new_value': newValue,
        'occurred_at': DateTime.now().toIso8601String(),
      });
      return response.isSuccess;
    } catch (_) {
      return false;
    }
  }
}

class AccessLogsResult {
  final List<Map<String, dynamic>> logs;
  final String? error;

  const AccessLogsResult({
    required this.logs,
    this.error,
  });
}

class _ParsedAccessLogs {
  final List<Map<String, dynamic>> logs;
  final String? error;

  const _ParsedAccessLogs({
    required this.logs,
    this.error,
  });
}
