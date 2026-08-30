import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBackend {
  SupabaseBackend._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  static SupabaseClient? client;

  static bool get configured =>
      client != null && url.isNotEmpty && publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (url.isEmpty || publishableKey.isEmpty) return;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    client = Supabase.instance.client;
  }
}
