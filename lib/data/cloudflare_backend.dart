import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Error raised for every failed API call, so callers can tell a rejected
/// request (a [code] sent by the server) from a network problem.
class ApiException implements Exception {
  const ApiException(this.code, {this.statusCode, this.network = false});

  /// Machine readable error sent by the Worker, e.g. `email_exists`.
  final String code;
  final int? statusCode;

  /// True when the server could not be reached at all.
  final bool network;

  bool get unauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($code, status: $statusCode)';
}

/// A signed-in session returned by the server.
class AuthSession {
  const AuthSession(this.token, this.user);
  final String token;
  final Map<String, dynamic> user;

  static AuthSession _from(Map<String, dynamic> body) {
    final token = body['token'];
    final user = body['user'];
    if (token is! String || user is! Map<String, dynamic>) {
      throw const ApiException('bad_response');
    }
    return AuthSession(token, user);
  }
}

/// Optional Cloudflare Workers + D1 client.
///
/// Enable it at build/run time with:
/// `flutter run --dart-define=API_BASE_URL=https://your-worker.workers.dev`
class CloudflareBackend {
  CloudflareBackend._();

  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static const _timeout = Duration(seconds: 25);

  static bool get configured => baseUrl.trim().isNotEmpty;

  /// Current session token, kept by the store so a login survives restarts.
  static String? token;

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
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Runs [request] and turns transport failures into [ApiException]s.
  static Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    try {
      return await request().timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw const ApiException('timeout', network: true);
    } on SocketException {
      throw const ApiException('offline', network: true);
    } on http.ClientException {
      throw const ApiException('offline', network: true);
    }
  }

  static dynamic _body(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = _body(response);
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (!ok) {
      final code = decoded is Map<String, dynamic>
          ? '${decoded['error'] ?? 'http_${response.statusCode}'}'
          : 'http_${response.statusCode}';
      throw ApiException(code, statusCode: response.statusCode);
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('bad_response', statusCode: response.statusCode);
    }
    return decoded;
  }

  /// Returns the new session on success, `null` when the credentials are
  /// refused. Network problems are thrown so they are not mistaken for a wrong
  /// password.
  ///
  /// The token is deliberately *not* stored here: two sign-ins can overlap
  /// (the guest account connecting at startup while a partner signs in) and the
  /// caller decides which one becomes the active session.
  static Future<AuthSession?> login(String email, String password) async {
    final response = await _send(
      () => http.post(
        _uri('/api/auth/login'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );
    if (response.statusCode == 401 || response.statusCode == 403) return null;
    return AuthSession._from(_decode(response));
  }

  /// Creates the device-bound customer account used for guest checkout.
  static Future<AuthSession> createGuest(String email, String password) async {
    final response = await _send(
      () => http.post(
        _uri('/api/auth/guest'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
    return AuthSession._from(_decode(response));
  }

  /// Validates the stored token and returns the signed-in user.
  static Future<Map<String, dynamic>> me() async {
    final response = await _send(
      () => http.get(_uri('/api/auth/me'), headers: _headers()),
    );
    return _decode(response)['user'] as Map<String, dynamic>;
  }

  /// Ends a session that was never adopted (for example a sign-in refused
  /// because the account has another role).
  static Future<void> revoke(String sessionToken) async {
    try {
      await _send(
        () => http.post(
          _uri('/api/auth/logout'),
          headers: {'Authorization': 'Bearer $sessionToken'},
        ),
      );
    } on ApiException {
      // It expires by itself.
    }
  }

  static Future<void> logout() async {
    if (token == null || !configured) return;
    try {
      await _send(
        () => http.post(_uri('/api/auth/logout'), headers: _headers()),
      );
    } on ApiException {
      // The session is dropped locally either way.
    } finally {
      token = null;
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
    final response = await _send(
      () => http.get(_uri(path), headers: _headers()),
    );
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    final decoded = _body(response);
    if (!ok || decoded == null) {
      final code = decoded is Map<String, dynamic> && decoded['error'] != null
          ? '${decoded['error']}'
          : 'http_${response.statusCode}';
      throw ApiException(code, statusCode: response.statusCode);
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      () => http.post(
        _uri(path),
        headers: _headers(jsonBody: true),
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> bootstrapAdmin({
    required String name,
    required String email,
    required String password,
    required String setupToken,
  }) async {
    final response = await _send(
      () => http.post(
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
      ),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      () => http.patch(
        _uri(path),
        headers: _headers(jsonBody: true),
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> upload({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final response = await _send(
      () => http.post(
        _uri('/api/media'),
        headers: {
          ..._headers(),
          'Content-Type': contentType,
          'X-File-Name': Uri.encodeComponent(fileName),
        },
        body: bytes,
      ),
      timeout: const Duration(minutes: 3),
    );
    return _decode(response);
  }
}
