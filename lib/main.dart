import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'routes/app_routes.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

/// Custom HttpOverrides to accept self-signed certificates on Android/iOS
/// for development and on-premise cloud servers.
class EduHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Accept self-signed certificates for custom server IP / host
        return true;
      };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    HttpOverrides.global = EduHttpOverrides();
  } else {
    SemanticsBinding.instance.ensureSemantics();
  }
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
      title: 'AugmentEd',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute ?? AppRoutes.initial,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

/// Backward compatibility alias for test suites and existing callers
typedef MainNavigationScreen = RoleDispatcherScreen;
