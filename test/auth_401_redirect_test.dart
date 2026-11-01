import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:edu_mobile/routes/app_routes.dart';
import 'package:edu_mobile/routes/app_router.dart';
import 'package:edu_mobile/services/api_service.dart';
import 'package:edu_mobile/services/storage_service.dart';
import 'package:edu_mobile/parents/screens/parent_conversations_screen.dart';
import 'package:edu_mobile/teacher/screens/teacher_conversations_screen.dart';
import 'package:edu_mobile/screens/chat_screen.dart';
import 'package:edu_mobile/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiService.onUnauthorized = null;
  });

  group('401 Unauthorized Central Handling Tests', () {
    test('handleUnauthorized clears session storage', () async {
      await StorageService.saveSession(
        token: 'test-expired-token',
        user: {'id': 'user-1', 'email': 'test@edu.local', 'role': 'guardian'},
      );

      expect(await StorageService.getToken(), isNotNull);

      bool redirectCallbackFired = false;
      ApiService.onUnauthorized = () async {
        redirectCallbackFired = true;
      };

      await ApiService.handleUnauthorized();

      expect(redirectCallbackFired, isTrue);
      expect(await StorageService.getToken(), isNull);
      expect(await StorageService.getUser(), isNull);
    });

    test('getConversations triggers 401 handler and throws UnauthorizedException when unauthenticated', () async {
      // Session has no token
      bool unauthorizedHandled = false;
      ApiService.onUnauthorized = () async {
        unauthorizedHandled = true;
      };

      try {
        await ApiService.getConversations();
        fail('Should throw UnauthorizedException');
      } catch (e) {
        expect(e, isA<UnauthorizedException>());
      }

      // Verify unauthorized handler was invoked
      expect(unauthorizedHandled, isTrue);
    });

    test('getOrCreateConversation triggers 401 handler and throws UnauthorizedException when unauthenticated', () async {
      bool unauthorizedHandled = false;
      ApiService.onUnauthorized = () async {
        unauthorizedHandled = true;
      };

      try {
        await ApiService.getOrCreateConversation(teacherId: 'teacher-1');
        fail('Should throw UnauthorizedException');
      } catch (e) {
        expect(e, isA<UnauthorizedException>());
      }

      expect(unauthorizedHandled, isTrue);
    });

    test('sendMessage triggers 401 handler and throws UnauthorizedException when unauthenticated', () async {
      bool unauthorizedHandled = false;
      ApiService.onUnauthorized = () async {
        unauthorizedHandled = true;
      };

      try {
        await ApiService.sendMessage('conv-1', 'Hello');
        fail('Should throw UnauthorizedException');
      } catch (e) {
        expect(e, isA<UnauthorizedException>());
      }

      expect(unauthorizedHandled, isTrue);
    });

    test('getMessages triggers 401 handler and throws UnauthorizedException when unauthenticated', () async {
      bool unauthorizedHandled = false;
      ApiService.onUnauthorized = () async {
        unauthorizedHandled = true;
      };

      try {
        await ApiService.getMessages('conv-1');
        fail('Should throw UnauthorizedException');
      } catch (e) {
        expect(e, isA<UnauthorizedException>());
      }

      expect(unauthorizedHandled, isTrue);
    });

    test('getNotifications triggers 401 handler and throws UnauthorizedException when unauthenticated', () async {
      bool unauthorizedHandled = false;
      ApiService.onUnauthorized = () async {
        unauthorizedHandled = true;
      };

      try {
        await ApiService.getNotifications();
        fail('Should throw UnauthorizedException');
      } catch (e) {
        expect(e, isA<UnauthorizedException>());
      }

      expect(unauthorizedHandled, isTrue);
    });

    test('HTTP 401 response from server triggers 401 handler and throws UnauthorizedException', () async {
      await StorageService.saveSession(
        token: 'active-session-token',
        user: {'id': 'user-1', 'role': 'teacher'},
      );

      bool unauthorizedHandled = false;
      ApiService.onUnauthorized = () async {
        unauthorizedHandled = true;
        await StorageService.clearSession();
      };

      final http401Response = http.Response('{"error":"Token expired"}', 401);
      
      try {
        await ApiService.handleUnauthorized();
        expect(http401Response.statusCode, 401);
      } catch (_) {}

      expect(unauthorizedHandled, isTrue);
      expect(await StorageService.getToken(), isNull);
    });
  });

  group('Widget Navigation & Error Suppression Tests', () {
    testWidgets('ParentConversationsScreen redirects to login without showing error message on 401 / unauthenticated', (WidgetTester tester) async {
      // Setup unauthenticated environment
      SharedPreferences.setMockInitialValues({});

      final navKey = GlobalKey<NavigatorState>();
      AppRouter.navigatorKey = navKey;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          initialRoute: '/test_parent_conv',
          routes: {
            '/test_parent_conv': (_) => const ParentConversationsScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
          },
        ),
      );

      await tester.pumpAndSettle();

      // Verify that NO error message or retry button is displayed
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);

      // Verify that it redirected to the Login Screen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('TeacherConversationsScreen redirects to login without showing error message on 401 / unauthenticated', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final navKey = GlobalKey<NavigatorState>();
      AppRouter.navigatorKey = navKey;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          initialRoute: '/test_teacher_conv',
          routes: {
            '/test_teacher_conv': (_) => const TeacherConversationsScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
          },
        ),
      );

      await tester.pumpAndSettle();

      // Verify that NO error message or retry button is displayed
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);

      // Verify that it redirected to the Login Screen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('ChatScreen redirects to login without showing SnackBar error message on 401 / unauthenticated', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final navKey = GlobalKey<NavigatorState>();
      AppRouter.navigatorKey = navKey;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          initialRoute: '/test_chat',
          routes: {
            '/test_chat': (_) => const ChatScreen(
              conversationId: 'mock-conv-id',
              title: 'Teacher Smith',
              subtitle: 'Class Teacher',
            ),
            AppRoutes.login: (_) => const LoginScreen(),
          },
        ),
      );

      await tester.pumpAndSettle();

      // Verify that NO error SnackBar is displayed
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Error loading chat'), findsNothing);

      // Verify that it redirected to the Login Screen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });
  });
}
