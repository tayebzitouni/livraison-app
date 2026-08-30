import 'package:flutter/foundation.dart';
import 'supabase_backend.dart';

enum UserRole { client, driver, restaurant, supplier, admin }

class SessionUser {
  final String id;
  final String username;
  final UserRole role;
  const SessionUser(this.id, this.username, this.role);

  String get roleLabel => switch (role) {
    UserRole.client => 'الزبون',
    UserRole.driver => 'السائق',
    UserRole.restaurant => 'المطعم',
    UserRole.supplier => 'المورد',
    UserRole.admin => 'المدير العام',
  };
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  SessionUser? currentUser;

  Future<SessionUser?> login(String email, String password) async {
    if (SupabaseBackend.configured) {
      try {
        final response = await SupabaseBackend.client!.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        final authUser = response.user;
        if (authUser == null) return null;
        final profile = await SupabaseBackend.client!
            .from('profiles')
            .select('full_name, role')
            .eq('id', authUser.id)
            .single();
        final role = _parseRole(profile['role'] as String? ?? 'customer');
        currentUser = SessionUser(
          authUser.id,
          profile['full_name'] as String? ?? authUser.email ?? 'user',
          role,
        );
        notifyListeners();
        return currentUser;
      } catch (_) {
        return null;
      }
    }

    const roles = <String, UserRole>{
      '1': UserRole.client,
      '2': UserRole.driver,
      '3': UserRole.restaurant,
      '4': UserRole.supplier,
      '5': UserRole.admin,
    };
    final role = roles[email.trim()];
    if (role == null || password.trim() != email.trim()) return null;
    currentUser = SessionUser(
      'demo_${email.trim()}',
      'demo_${email.trim()}',
      role,
    );
    notifyListeners();
    return currentUser;
  }

  void logout() {
    if (SupabaseBackend.configured) {
      SupabaseBackend.client!.auth.signOut();
    }
    currentUser = null;
    notifyListeners();
  }

  UserRole _parseRole(String role) => switch (role) {
    'driver' => UserRole.driver,
    'cook' || 'restaurant' => UserRole.restaurant,
    'supplier' => UserRole.supplier,
    'admin' => UserRole.admin,
    _ => UserRole.client,
  };
}
