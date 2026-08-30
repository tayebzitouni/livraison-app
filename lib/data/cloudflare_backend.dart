import 'dart:convert';

import 'package:http/http.dart' as http;

/// Optional Cloudflare Workers + D1 client.
///
/// Enable it at build/run time with:
/// `flutter run --dart-define=API_BASE_URL=https://your-worker.workers.dev`
class CloudflareBackend {
  CloudflareBackend._();

  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static String? _token;

  static bool get configured => baseUrl.trim().isNotEmpty;

  static Uri _uri(String path) {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$root$path');
  }

  static Map<String, String> _headers({bool jsonBody = false}) => {
        if (jsonBody) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final response = await http.post(
      _uri('/api/auth/login'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _token = body['token'] as String?;
    return body['user'] as Map<String, dynamic>?;
  }

  static Future<void> logout() async {
    if (_token == null || !configured) return;
    try {
      await http.post(_uri('/api/auth/logout'), headers: _headers());
    } finally {
      _token = null;
    }
  }

  static Future<dynamic> get(String path) async {
    final response = await http.get(_uri(path), headers: _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudflare request failed (${response.statusCode})');
    }
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      _uri(path),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['error'] ?? 'Cloudflare request failed');
    }
    return decoded;
  }
}
