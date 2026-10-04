import 'package:flutter/material.dart';
import '../screens/student_shell_screen.dart';

/// Route definition and generator for Student role codebase.
class StudentRoutes {
  static const String prefix = '/students';
  static const String root = '/students';
  static const String curriculum = '/students/curriculum';
  static const String wallet = '/students/wallet';
  static const String notices = '/students/notices';
  static const String settings = '/students/settings';

  /// Generates routes matching the /students namespace.
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    final routeName = settings.name ?? root;

    switch (routeName) {
      case root:
      case curriculum:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudentShellScreen(initialTab: 0),
        );
      case wallet:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudentShellScreen(initialTab: 1),
        );
      case notices:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudentShellScreen(initialTab: 2),
        );
      case StudentRoutes.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudentShellScreen(initialTab: 3),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StudentShellScreen(initialTab: 0),
        );
    }
  }
}
