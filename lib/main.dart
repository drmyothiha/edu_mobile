import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'routes/app_routes.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const EduMobileApp());
}

class EduMobileApp extends StatelessWidget {
  final String? initialRoute;

  const EduMobileApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Myanmar Edu Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute ?? AppRoutes.initial,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

/// Backward compatibility alias for test suites and existing callers
typedef MainNavigationScreen = RoleDispatcherScreen;
