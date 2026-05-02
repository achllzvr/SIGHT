import 'api_client_service.dart';
import 'api_config_service.dart';

class ClinicianService {
  ClinicianService._private();
  static final ClinicianService instance = ClinicianService._private();

  Future<List<dynamic>> getAvailableDoctors() async {
    final uri = ApiConfigService.buildUri('/api/mobile/doctors');
    final response = await ApiClientService.instance.get(uri);
    if (response.isSuccess && response.data != null) {
      return response.data['data'] as List<dynamic>? ?? [];
    }
    return [];
  }

  Future<List<dynamic>> getChildLinks(int childId) async {
    final uri = ApiConfigService.buildUri('/api/mobile/child/$childId/clinician-links');
    final response = await ApiClientService.instance.get(uri);
    if (response.isSuccess && response.data != null) {
      return response.data['data'] as List<dynamic>? ?? [];
    }
    return [];
  }

  Future<bool> requestConnection(int childId, int doctorId) async {
    final uri = ApiConfigService.buildUri('/api/mobile/child/$childId/clinician-request');
    final response = await ApiClientService.instance.post(uri, jsonBody: {'doctor_id': doctorId});
    return response.isSuccess;
  }

  Future<bool> cancelConnection(int linkId) async {
    final uri = ApiConfigService.buildUri('/api/mobile/clinician-request/$linkId');
    final response = await ApiClientService.instance.delete(uri);
    return response.isSuccess;
  }
}