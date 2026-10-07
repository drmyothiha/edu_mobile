import '../models/user_role.dart';

/// Central route constants and role-to-route mappings.
class AppRoutes {
  static const String initial = '/';
  static const String login = '/login';
  static const String settings = '/settings';
  static const String parents = '/parents';
  static const String students = '/students';

  /// Resolves the canonical root route for a given RBAC role.
  static String getRouteForRole(AppUserRole role) {
    switch (role) {
      case AppUserRole.guardian:
        return parents;
      case AppUserRole.student:
        return students;
    }
  }
}
