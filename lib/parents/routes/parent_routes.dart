import 'package:flutter/material.dart';
import '../screens/parents_shell_screen.dart';

/// Route definition and generator for Parents / Guardian role codebase.
class ParentRoutes {
  static const String prefix = '/parents';
  static const String root = '/parents';
  static const String children = '/parents/children';
  static const String childPass = '/parents/child-pass';
  static const String chat = '/parents/chat';

  /// Generates routes matching the /parents namespace.
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    final routeName = settings.name ?? root;

    switch (routeName) {
      case root:
      case children:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ParentsShellScreen(initialTab: 0),
        );
      case childPass:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ParentsShellScreen(initialTab: 1),
        );
      case chat:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ParentsShellScreen(initialTab: 2),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ParentsShellScreen(initialTab: 0),
        );
    }
  }
}
