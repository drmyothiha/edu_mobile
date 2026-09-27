import 'package:flutter/material.dart';
import '../screens/teacher_shell_screen.dart';
import '../screens/scan_history_screen.dart';

/// Route definition and generator for Teacher role codebase.
class TeacherRoutes {
  static const String prefix = '/teacher';
  static const String root = '/teacher';
  static const String kiosk = '/teacher/kiosk';
  static const String classroomSync = '/teacher/sync';
  static const String scanHistory = '/teacher/history';
  static const String messages = '/teacher/messages';

  /// Generates routes matching the /teacher namespace.
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    final routeName = settings.name ?? root;

    switch (routeName) {
      case root:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const TeacherShellScreen(initialTab: 0),
        );
      case kiosk:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const TeacherShellScreen(initialTab: 0),
        );
      case classroomSync:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const TeacherShellScreen(initialTab: 1),
        );
      case messages:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const TeacherShellScreen(initialTab: 2),
        );
      case scanHistory:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ScanHistoryScreen(),
        );
      default:
        // Fallback to teacher shell
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const TeacherShellScreen(initialTab: 0),
        );
    }
  }
}
