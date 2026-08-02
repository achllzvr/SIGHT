import 'api_client_service.dart';
import 'api_config_service.dart';

class TemporaryAccessService {
  TemporaryAccessService._private();
  static final TemporaryAccessService instance = TemporaryAccessService._private();

  Future<Map<String, dynamic>?> generateToken(int childId) async {
    final uri = ApiConfigService.buildUri('/api/mobile/children/$childId/access-tokens');
    final response = await ApiClientService.instance.post(uri, jsonBody: {});
    if (response.isSuccess && response.data != null) {
      final data = response.data['data'];
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getActiveSession(int childId) async {
    final uri = ApiConfigService.buildUri('/api/mobile/children/$childId/access-session');
    final response = await ApiClientService.instance.get(uri);
    if (response.isSuccess && response.data != null) {
      final data = response.data['data'];
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }

  Future<bool> endSession(int sessionId) async {
    final uri = ApiConfigService.buildUri('/api/mobile/access-sessions/$sessionId/end');
    final response = await ApiClientService.instance.post(uri, jsonBody: {});
    return response.isSuccess;
  }

  Future<List<dynamic>> getAccessLogs(int childId) async {
    final uri = ApiConfigService.buildUri('/api/mobile/children/$childId/access-logs');
    final response = await ApiClientService.instance.get(uri);
    if (response.isSuccess && response.data != null) {
      final data = response.data['data'];
      if (data is Map && data['logs'] is List) {
        return data['logs'] as List<dynamic>;
      }
    }
    return [];
  }

  Future<bool> ingestActivity({
    required String eventTag,
    int? childId,
    dynamic oldValue,
    dynamic newValue,
  }) async {
    final uri = ApiConfigService.buildUri('/api/mobile/activity-logs');
    final response = await ApiClientService.instance.post(uri, jsonBody: {
      'event_tag': eventTag,
      if (childId != null) 'child_id': childId,
      'old_value': oldValue,
      'new_value': newValue,
      'occurred_at': DateTime.now().toIso8601String(),
    });
    return response.isSuccess;
  }
}
