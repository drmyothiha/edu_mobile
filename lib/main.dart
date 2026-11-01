import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'routes/app_routes.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';
import 'services/fcm_service.dart';

/// Custom HttpOverrides to accept self-signed certificates on Android/iOS
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
    // Initialize Firebase Cloud Messaging asynchronously without blocking runApp
    FcmService.initialize().catchError((e) {
      debugPrint('[FCM] Initialization error: $e');
    });
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
  final GlobalKey<NavigatorState>? navigatorKey;

  const EduMobileApp({super.key, this.initialRoute, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey ?? AppRouter.navigatorKey,
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
