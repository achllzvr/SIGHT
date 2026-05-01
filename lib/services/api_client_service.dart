import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session_service.dart';

class ApiClientResponse {
  final int statusCode;
  final dynamic data;
  final String rawBody;

  const ApiClientResponse({
    required this.statusCode,
    required this.data,
    required this.rawBody,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class ApiClientService {
  ApiClientService._private();

  static final ApiClientService instance = ApiClientService._private();

  static const Duration _timeout = Duration(seconds: 12);

  Future<Map<String, String>> _headers() async {
    final token = await AuthSessionService.instance.loadAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<ApiClientResponse> get(Uri uri) async {
    final response = await http.get(uri, headers: await _headers()).timeout(_timeout);
    return _parse(response);
  }

  Future<ApiClientResponse> post(Uri uri, {Map<String, dynamic>? jsonBody}) async {
    final response = await http
        .post(
          uri,
          headers: await _headers(),
          body: jsonBody == null ? null : jsonEncode(jsonBody),
        )
        .timeout(_timeout);
    return _parse(response);
  }

  Future<ApiClientResponse> put(Uri uri, {Map<String, dynamic>? jsonBody}) async {
    final response = await http
        .put(
          uri,
          headers: await _headers(),
          body: jsonBody == null ? null : jsonEncode(jsonBody),
        )
        .timeout(_timeout);
    return _parse(response);
  }

  ApiClientResponse _parse(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    return ApiClientResponse(
      statusCode: response.statusCode,
      data: decoded,
      rawBody: response.body,
    );
  }
}