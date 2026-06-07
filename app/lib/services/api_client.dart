import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Thin REST client for the MileWorth backend. Injects the bearer token and
/// decodes JSON, raising [ApiException] on non-2xx responses.
class ApiClient {
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<dynamic> get(String path) async {
    final res = await http.get(_uri(path), headers: _headers);
    return _decode(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(_uri(path), headers: _headers, body: jsonEncode(body));
    return _decode(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(_uri(path), headers: _headers, body: jsonEncode(body));
    return _decode(res);
  }

  Future<void> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers);
    if (res.statusCode >= 400) _throw(res);
  }

  /// Download raw bytes (e.g. a generated PDF/CSV report) with auth.
  Future<Uint8List> getBytes(String path) async {
    final res = await http.get(_uri(path), headers: _headers);
    if (res.statusCode >= 400) _throw(res);
    return res.bodyBytes;
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 400) _throw(res);
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Never _throw(http.Response res) {
    String message = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) message = body['error'];
    } catch (_) {}
    throw ApiException(res.statusCode, message);
  }
}
