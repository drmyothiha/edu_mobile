import '../models/user_role.dart';

/// Central route constants and role-to-route mappings.
class AppRoutes {
  static const String initial = '/';
  static const String login = '/login';
  static const String settings = '/settings';
  static const String update = '/update';
  static const String teacher = '/teacher';
  static const String parents = '/parents';
  static const String students = '/students';
  static const String admin = '/admin';

  /// Resolves the canonical root route for a given RBAC role.
  static String getRouteForRole(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return admin;
      case AppUserRole.teacher:
        return teacher;
      case AppUserRole.guardian:
        return parents;
      case AppUserRole.student:
        return students;
    }
  }
}
