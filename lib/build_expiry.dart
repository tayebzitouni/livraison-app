import 'package:shared_preferences/shared_preferences.dart';

import 'data/cloudflare_backend.dart';

/// Preview APKs pass `PREVIEW_EXPIRES_AT` (ISO-8601 UTC) at build time.
/// Dev/tests omit it so the app stays unlimited.
class BuildExpiry {
  static const raw = String.fromEnvironment('PREVIEW_EXPIRES_AT');
  static const _firstSeenKey = 'preview_first_seen_utc';

  static DateTime? get deadlineUtc {
    if (raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static bool get enabled => deadlineUtc != null;

  static Future<bool> isExpired() async {
    final deadline = deadlineUtc;
    if (deadline == null) return false;

    final nowLocal = DateTime.now().toUtc();
    if (!nowLocal.isBefore(deadline)) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_firstSeenKey);
      if (stored == null) {
        await prefs.setString(_firstSeenKey, nowLocal.toIso8601String());
      } else {
        final firstSeen = DateTime.tryParse(stored)?.toUtc();
        if (firstSeen != null) {
          if (nowLocal.isBefore(
            firstSeen.subtract(const Duration(minutes: 5)),
          )) {
            return true;
          }
          if (!nowLocal.isBefore(firstSeen.add(const Duration(hours: 24)))) {
            return true;
          }
        }
      }
    } catch (_) {}

    final server = await CloudflareBackend.serverTimeUtc();
    if (server != null && !server.isBefore(deadline)) return true;
    return false;
  }
}
