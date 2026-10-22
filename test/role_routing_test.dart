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

      final settingsRoute = StudentRoutes.generateRoute(const RouteSettings(name: '/students/settings'));
      expect(settingsRoute, isNotNull);
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
      expect(find.text('Daw Khin Mar (ဒေါ်ခင်မာ)'), findsOneWidget);

      // Check Parents navigation tabs
      expect(find.text('Children'), findsOneWidget);
      expect(find.text('Child Pass'), findsNothing);
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

      // Check Student navigation tabs (1st = Curriculum/အချိန်ဇယား, 2nd = ID Card/ကတ်ပြား, 3rd = Notices/သတင်းလွှာ, 4th = Settings/ဆက်တင်)
      expect(find.text('အချိန်ဇယား'), findsOneWidget);
      expect(find.text('ကတ်ပြား'), findsOneWidget);
      expect(find.text('သတင်းလွှာ'), findsOneWidget);
      expect(find.text('ဆက်တင်'), findsOneWidget);
      expect(find.text('Whole-Child'), findsNothing);

      // Top bar removed to save space: starts directly with Week row at top
      expect(find.text('MON'), findsOneWidget);
      expect(find.text('SUN'), findsOneWidget);
      expect(find.text('လက်ရှိအချိန်'), findsOneWidget);
      expect(find.textContaining('Mathematics'), findsWidgets);
      expect(find.text('2026 / 9'), findsNothing);

      // Tap 4th tab (Settings) to verify Standards profile, settings, logout, and about
      await tester.tap(find.text('ဆက်တင်'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Settings & Profile'), findsOneWidget);
      expect(find.text('Alice Walker (Grade 8)'), findsAtLeastNWidgets(1));
      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.textContaining('Standards Profile'), findsWidgets);
      expect(find.text('Sign Out (အကောင့်မှ ထွက်မည်)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('Tapping curriculum period in week calendar opens syllabus bottom sheet', (WidgetTester tester) async {
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
          'full_name': 'Alice Walker',
          'role': 'student',
          'grade_level': 'Grade 8',
          'date_of_birth': DateTime(DateTime.now().year - 14, 1, 1).toIso8601String(),
        }),
      });
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      // Select Monday in the swipable week days bar
      final monFinder = find.text('MON');
      expect(monFinder, findsOneWidget);
      await tester.tap(monFinder);
      await tester.pumpAndSettle();

      // Verify Monday shows single subject for 09:00 AM (Mathematics by Daw May Thu)
      final mathFinder = find.textContaining('Mathematics').first;
      await tester.tap(mathFinder);
      await tester.pumpAndSettle();

      // Verify bottom sheet appears with syllabus details and learning objectives
      expect(find.text('သင်ရိုးမာတိကာ အကြောင်းအရာ'), findsOneWidget);
      expect(find.text('Daw May Thu'), findsOneWidget);
      expect(find.text('သင်ခန်းစာ မှတ်စုများ (PDF)'), findsOneWidget);

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

      expect(find.text('Guardian Portal'), findsOneWidget);
      expect(find.text('Children'), findsOneWidget);
      expect(find.text('Child Pass'), findsNothing);
      expect(find.text('Teacher Chat'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('Direct route navigation with initialRoute /students renders Student UI', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp(initialRoute: AppRoutes.students));
      await tester.pumpAndSettle();

      expect(find.text('အချိန်ဇယား'), findsOneWidget);
      expect(find.text('ကတ်ပြား'), findsOneWidget);
      expect(find.text('သတင်းလွှာ'), findsOneWidget);
      expect(find.text('ဆက်တင်'), findsOneWidget);
      expect(find.text('Whole-Child'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });
  });
}
