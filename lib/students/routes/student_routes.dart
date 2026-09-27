import 'package:flutter/material.dart';
import '../screens/student_shell_screen.dart';

/// Route definition and generator for Student role codebase.
class StudentRoutes {
  static const String prefix = '/students';
  static const String root = '/students';
  static const String wallet = '/students/wallet';
  static const String attendance = '/students/attendance';
  static const String notices = '/students/notices';

  /// Generates routes matching the /students namespace.
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    final routeName = settings.name ?? root;

    switch (routeName) {
      case root:
      case wallet:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudentShellScreen(initialTab: 0),
        );
      case attendance:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudentShellScreen(initialTab: 1),
        );
      case notices:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudentShellScreen(initialTab: 2),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudentShellScreen(initialTab: 0),
        );
    }
  }
}
