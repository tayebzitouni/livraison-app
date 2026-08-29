import 'package:flutter/foundation.dart';

enum UserRole { client, driver, restaurant, supplier, admin }

class SessionUser {
  final String username;
  final UserRole role;
  const SessionUser(this.username, this.role);

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

  SessionUser? login(String email, String password) {
    const roles = <String, UserRole>{
      '1': UserRole.client,
      '2': UserRole.driver,
      '3': UserRole.restaurant,
      '4': UserRole.supplier,
      '5': UserRole.admin,
    };
    final role = roles[email.trim()];
    if (role == null || password.trim() != email.trim()) return null;
    currentUser = SessionUser('demo_${email.trim()}', role);
    notifyListeners();
    return currentUser;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }
}
