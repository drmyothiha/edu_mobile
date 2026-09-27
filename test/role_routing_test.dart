import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/main.dart';
import 'package:edu_mobile/models/user_role.dart';
import 'package:edu_mobile/services/jwt_decoder.dart';
import 'package:edu_mobile/services/storage_service.dart';
import 'package:edu_mobile/services/sse_notification_service.dart';
import 'package:edu_mobile/routes/app_routes.dart';
import 'package:edu_mobile/routes/app_router.dart';
import 'package:edu_mobile/teacher/routes/teacher_routes.dart';
import 'package:edu_mobile/parents/routes/parent_routes.dart';
import 'package:edu_mobile/students/routes/student_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JWT Claims Decoder & Role Extraction Tests', () {
    test('Correctly extracts teacher role from real JWT payload', () {
      final token = JwtDecoder.generateMockToken(
        role: 'teacher',
        email: 'teacher.smith@edu.local',
        userId: 'teacher-uuid-1',
      );

      final claims = JwtDecoder.decode(token);
      expect(claims, isNotNull);
      expect(claims!['role'], 'teacher');
      expect(claims['email'], 'teacher.smith@edu.local');

      final role = JwtDecoder.getRole(token);
      expect(role, AppUserRole.teacher);
    });

    test('Correctly extracts guardian / parent role from JWT payload', () {
      final token = JwtDecoder.generateMockToken(
        role: 'guardian',
        email: 'parent.clark@edu.local',
      );

      final role = JwtDecoder.getRole(token);
      expect(role, AppUserRole.guardian);

      // Verify "parent" synonym in JWT maps to guardian
      final parentToken = JwtDecoder.generateMockToken(
        role: 'parent',
        email: 'parent.clark@edu.local',
      );
      expect(JwtDecoder.getRole(parentToken), AppUserRole.guardian);
    });

    test('Correctly extracts student role from JWT payload', () {
      final token = JwtDecoder.generateMockToken(
        role: 'student',
        email: 'student.alice@edu.local',
      );

      final role = JwtDecoder.getRole(token);
      expect(role, AppUserRole.student);
    });

    test('Handles malformed or non-JWT tokens without throwing', () {
      expect(JwtDecoder.decode('invalid-token'), isNull);
      expect(JwtDecoder.getRole('not-a-jwt'), isNull);
      expect(JwtDecoder.decode(''), isNull);
      expect(JwtDecoder.decode(null), isNull);
    });
  });

  group('Role Namespace Route Generators', () {
    test('TeacherRoutes generates valid MaterialPageRoute instances', () {
      final rootRoute = TeacherRoutes.generateRoute(const RouteSettings(name: '/teacher'));
      expect(rootRoute, isNotNull);

      final kioskRoute = TeacherRoutes.generateRoute(const RouteSettings(name: '/teacher/kiosk'));
      expect(kioskRoute, isNotNull);

      final syncRoute = TeacherRoutes.generateRoute(const RouteSettings(name: '/teacher/sync'));
      expect(syncRoute, isNotNull);
    });

    test('ParentRoutes generates valid MaterialPageRoute instances', () {
      final rootRoute = ParentRoutes.generateRoute(const RouteSettings(name: '/parents'));
      expect(rootRoute, isNotNull);

      final passRoute = ParentRoutes.generateRoute(const RouteSettings(name: '/parents/child-pass'));
      expect(passRoute, isNotNull);
    });

    test('StudentRoutes generates valid MaterialPageRoute instances', () {
      final rootRoute = StudentRoutes.generateRoute(const RouteSettings(name: '/students'));
      expect(rootRoute, isNotNull);

      final walletRoute = StudentRoutes.generateRoute(const RouteSettings(name: '/students/wallet'));
      expect(walletRoute, isNotNull);
    });

    test('AppRouter dispatches to role routes based on namespace', () {
      final teacherRoute = AppRouter.onGenerateRoute(const RouteSettings(name: '/teacher/sync'));
      expect(teacherRoute, isNotNull);

      final parentRoute = AppRouter.onGenerateRoute(const RouteSettings(name: '/parents/child-pass'));
      expect(parentRoute, isNotNull);

      final studentRoute = AppRouter.onGenerateRoute(const RouteSettings(name: '/students/wallet'));
      expect(studentRoute, isNotNull);
    });
  });

  group('JWT Role-Based Routing & UI Rendering', () {
    setUp(() {
      SseNotificationService.stopListening();
    });

    tearDown(() {
      SseNotificationService.stopListening();
    });

    testWidgets('User with JWT role=teacher routes to Teacher folder and renders Teacher UI', (WidgetTester tester) async {
      final teacherJwt = JwtDecoder.generateMockToken(
        role: 'teacher',
        email: 'teacher.smith@edu.local',
        userId: 'teacher-id-01',
      );

      SharedPreferences.setMockInitialValues({
        'auth_token': teacherJwt,
        'auth_user': json.encode({
          'id': 'teacher-id-01',
          'email': 'teacher.smith@edu.local',
          'full_name': 'Daw Thida (ဒေါ်သီတာ)',
          'role': 'teacher',
          'school_name': 'BEHS Intaing (အင်းတိုင် အထက)',
        }),
      });
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      // Check Teacher Shell UI elements
      expect(find.text('TEACHER'), findsOneWidget);
      expect(find.text('Daw Thida (ဒေါ်သီတာ)'), findsOneWidget);
      expect(find.text('BEHS Intaing (အင်းတိုင် အထက)'), findsOneWidget);

      // Check Teacher navigation tabs
      expect(find.text('Kiosk'), findsOneWidget);
      expect(find.text('Whole-Child'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('User with JWT role=guardian routes to Parents folder and renders Parents UI', (WidgetTester tester) async {
      final guardianJwt = JwtDecoder.generateMockToken(
        role: 'guardian',
        email: 'parent.clark@edu.local',
        userId: 'guardian-id-01',
      );

      SharedPreferences.setMockInitialValues({
        'auth_token': guardianJwt,
        'auth_user': json.encode({
          'id': 'guardian-id-01',
          'email': 'parent.clark@edu.local',
          'full_name': 'Daw Khin Mar (ဒေါ်ခင်မာ)',
          'role': 'guardian',
        }),
      });
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      // Check Parents Shell UI elements
      expect(find.text('GUARDIAN'), findsOneWidget);
      expect(find.text('Daw Khin Mar (ဒေါ်ခင်မာ)'), findsOneWidget);
      expect(find.text('Guardian Portal'), findsOneWidget);

      // Check Parents navigation tabs
      expect(find.text('Children'), findsOneWidget);
      expect(find.text('Child Pass'), findsOneWidget);
      expect(find.text('Teacher Chat'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('User with JWT role=student (age >= 13) routes to Students folder and renders Student UI', (WidgetTester tester) async {
      final studentJwt = JwtDecoder.generateMockToken(
        role: 'student',
        email: 'student.alice@edu.local',
        userId: 'student-id-01',
      );

      SharedPreferences.setMockInitialValues({
        'auth_token': studentJwt,
        'auth_user': json.encode({
          'id': 'student-id-01',
          'email': 'student.alice@edu.local',
          'full_name': 'Alice Walker (Grade 8)',
          'role': 'student',
          'grade_level': 'Grade 8',
          'date_of_birth': DateTime(DateTime.now().year - 14, 1, 1).toIso8601String(),
        }),
      });
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      // Check Student Shell UI elements
      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('Alice Walker (Grade 8)'), findsOneWidget);
      expect(find.text('Student ID Wallet'), findsOneWidget);

      // Check Student navigation tabs
      expect(find.text('ID Card'), findsOneWidget);
      expect(find.text('Whole-Child'), findsOneWidget);
      expect(find.text('Notices'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('Direct route navigation with initialRoute /teacher renders Teacher UI', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp(initialRoute: AppRoutes.teacher));
      await tester.pumpAndSettle();

      expect(find.text('TEACHER'), findsOneWidget);
      expect(find.text('Kiosk'), findsOneWidget);
      expect(find.text('Whole-Child'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('Direct route navigation with initialRoute /parents renders Parents UI', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp(initialRoute: AppRoutes.parents));
      await tester.pumpAndSettle();

      expect(find.text('GUARDIAN'), findsOneWidget);
      expect(find.text('Children'), findsOneWidget);
      expect(find.text('Child Pass'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('Direct route navigation with initialRoute /students renders Student UI', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp(initialRoute: AppRoutes.students));
      await tester.pumpAndSettle();

      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('ID Card'), findsOneWidget);
      expect(find.text('Whole-Child'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });
  });
}
