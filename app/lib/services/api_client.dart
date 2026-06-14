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
  // Defaults to the compile-time value; can be overridden at runtime (e.g. to
  // point a test build at a LAN backend or your Render URL) via setBaseUrl.
  String baseUrl = ApiConfig.baseUrl;

  /// Called when an AUTHENTICATED request comes back 401 (expired/revoked
  /// token). Lets the app sign the user out instead of leaving them stuck in a
  /// broken signed-in state. Not fired for unauthenticated calls (e.g. a
  /// wrong-password login, which legitimately returns 401).
  void Function()? onUnauthorized;

  void setToken(String? token) => _token = token;

  void setBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isNotEmpty) {
      // Drop any trailing slash so path concatenation stays clean.
      baseUrl = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

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
    // Session expiry: an authenticated request was rejected. Notify the app so
    // it can sign out. (_token is cleared on sign-out, so a subsequent login's
    // 401 won't re-trigger this.)
    if (res.statusCode == 401 && _token != null) {
      onUnauthorized?.call();
    }
    String message = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) message = body['error'];
    } catch (_) {}
    throw ApiException(res.statusCode, message);
  }
}
