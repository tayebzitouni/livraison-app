import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Optional Cloudflare Workers + D1 client.
///
/// Enable it at build/run time with:
/// `flutter run --dart-define=API_BASE_URL=https://your-worker.workers.dev`
class CloudflareBackend {
  CloudflareBackend._();

  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static const _timeout = Duration(seconds: 15);
  static String? _token;

  static bool get configured => baseUrl.trim().isNotEmpty;

  static String absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$root${path.startsWith('/') ? path : '/$path'}';
  }

  static Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }

  static Map<String, String> _headers({bool jsonBody = false}) => {
    if (jsonBody) 'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    final response = await http
        .post(
          _uri('/api/auth/login'),
          headers: _headers(jsonBody: true),
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _token = body['token'] as String?;
    return body['user'] as Map<String, dynamic>?;
  }

  static Future<void> logout() async {
    if (_token == null || !configured) return;
    try {
      await http
          .post(_uri('/api/auth/logout'), headers: _headers())
          .timeout(_timeout);
    } finally {
      _token = null;
    }
  }

  static Future<DateTime?> serverTimeUtc() async {
    if (!configured) return null;
    try {
      final response = await http.get(_uri('/api/health')).timeout(_timeout);
      DateTime? fromBody;
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          fromBody = DateTime.tryParse('${body['now'] ?? ''}');
        }
      } catch (_) {}
      return (fromBody ?? _httpDate(response.headers['date']))?.toUtc();
    } catch (_) {
      return null;
    }
  }

  static DateTime? _httpDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso.toUtc();
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final parts = raw.replaceAll(',', '').split(RegExp(r'\s+'));
    if (parts.length < 5) return null;
    final day = int.tryParse(parts[1]);
    final month = months[parts[2]];
    final year = int.tryParse(parts[3]);
    final time = parts[4].split(':');
    if (day == null || month == null || year == null || time.length < 3) {
      return null;
    }
    return DateTime.utc(
      year,
      month,
      day,
      int.parse(time[0]),
      int.parse(time[1]),
      int.parse(time[2]),
    );
  }

  static Future<dynamic> get(String path) async {
    final response = await http
        .get(_uri(path), headers: _headers())
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudflare request failed (${response.statusCode})');
    }
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          _uri(path),
          headers: _headers(jsonBody: true),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> bootstrapAdmin({
    required String name,
    required String email,
    required String password,
    required String setupToken,
  }) async {
    final response = await http
        .post(
          _uri('/api/admin/bootstrap'),
          headers: {
            ..._headers(jsonBody: true),
            'X-Admin-Setup-Token': setupToken,
          },
          body: jsonEncode({
            'name': name,
            'email': email.trim(),
            'password': password,
          }),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .patch(
          _uri(path),
          headers: _headers(jsonBody: true),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> upload({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final response = await http
        .post(
          _uri('/api/media'),
          headers: {
            ..._headers(),
            'Content-Type': contentType,
            'X-File-Name': fileName,
          },
          body: bytes,
        )
        .timeout(const Duration(minutes: 2));
    return _decode(response);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['error'] ?? 'Cloudflare request failed');
    }
    return decoded;
  }
}
