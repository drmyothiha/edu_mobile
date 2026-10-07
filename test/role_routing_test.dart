import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/models/user_role.dart';
import 'package:edu_mobile/services/storage_service.dart';
import 'package:edu_mobile/services/jwt_decoder.dart';
import 'package:edu_mobile/routes/app_routes.dart';
import 'package:edu_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JWT Role-Based Routing & UI Rendering', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTesting();
      await StorageService.clearSession();
    });

    test('Correctly extracts guardian role from real JWT payload', () {
      final guardianJwt = JwtDecoder.generateMockToken(
        role: 'guardian',
        email: 'parent.clark@edu.local',
        userId: 'guardian-uuid-2',
      );

      final claims = JwtDecoder.decode(guardianJwt);
      expect(claims, isNotNull);
      expect(claims!['role'], 'guardian');
      expect(claims['email'], 'parent.clark@edu.local');

      final role = JwtDecoder.getRole(guardianJwt);
      expect(role, AppUserRole.guardian);
    });

    test('AppRoutes correctly resolves routes for guardian and student', () {
      expect(AppRoutes.getRouteForRole(AppUserRole.guardian), AppRoutes.parents);
      expect(AppRoutes.getRouteForRole(AppUserRole.student), AppRoutes.students);
    });

    testWidgets('User with JWT role=guardian routes to Parents folder and renders Guardian UI', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final parentJwt = JwtDecoder.generateMockToken(
        role: 'guardian',
        email: 'parent.clark@edu.local',
        userId: 'parent-id-02',
      );

      await StorageService.saveSession(
        token: parentJwt,
        user: {
          'id': 'parent-id-02',
          'email': 'parent.clark@edu.local',
          'full_name': 'Daw Khin Mar',
          'role': 'guardian',
        },
      );

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      // Check Guardian Shell UI elements
      expect(find.textContaining('GUARDIAN'), findsWidgets);
      expect(find.text('Children'), findsOneWidget);
      expect(find.text('Child Pass'), findsOneWidget);
    });

    testWidgets('User with JWT role=student (age >= 13) routes to Students folder and renders Student UI', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final studentJwt = JwtDecoder.generateMockToken(
        role: 'student',
        email: 'student.alice@edu.local',
        userId: 'student-id-03',
      );

      await StorageService.saveSession(
        token: studentJwt,
        user: {
          'id': 'student-id-03',
          'email': 'student.alice@edu.local',
          'full_name': 'Alice Walker',
          'role': 'student',
          'grade_level': 'Grade 8',
          'date_of_birth': '2012-03-15T00:00:00Z',
        },
      );

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      // Check Student Shell UI navigation elements
      expect(find.text('အချိန်ဇယား'), findsOneWidget);
      expect(find.text('ကတ်ပြား'), findsOneWidget);
    });

    testWidgets('Under-13 student triggers Child Protection Guard and offers switch to Guardian', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final childJwt = JwtDecoder.generateMockToken(
        role: 'student',
        email: 'su.g5@intaing.edu.local',
        userId: 'child-under13-id',
      );

      await StorageService.saveSession(
        token: childJwt,
        user: {
          'id': 'child-under13-id',
          'email': 'su.g5@intaing.edu.local',
          'full_name': 'Ma Su Myat Noe',
          'role': 'student',
          'grade_level': 'Grade 5-A',
          'date_of_birth': '2016-04-12T00:00:00Z',
          'guardian_name': 'Daw Khin Mar',
        },
      );

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      // Should render Child Safety Mode screen
      expect(find.textContaining('Child Safety Policy'), findsWidgets);
      expect(find.textContaining('Ma Su Myat Noe'), findsOneWidget);
      expect(find.textContaining('Switch to Guardian Account'), findsOneWidget);
    });

    testWidgets('Direct route navigation with initialRoute /parents renders Parents UI', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const EduMobileApp(initialRoute: AppRoutes.parents));
      await tester.pumpAndSettle();

      expect(find.textContaining('GUARDIAN'), findsWidgets);
    });

    testWidgets('Direct route navigation with initialRoute /students renders Student UI', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const EduMobileApp(initialRoute: AppRoutes.students));
      await tester.pumpAndSettle();

      expect(find.text('အချိန်ဇယား'), findsOneWidget);
      expect(find.text('ကတ်ပြား'), findsOneWidget);
    });
  });
}
