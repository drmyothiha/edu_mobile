import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/models/user_role.dart';
import 'package:edu_mobile/services/storage_service.dart';
import 'package:edu_mobile/parents/screens/parents_shell_screen.dart';
import 'package:edu_mobile/students/screens/student_shell_screen.dart';
import 'package:edu_mobile/students/screens/student_under13_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RBAC & Age Verification Logic', () {
    test('Student under 13 correctly identified via age or birthdate', () {
      final dobUnder13 = DateTime.now().subtract(const Duration(days: 10 * 365));
      final userUnder13 = AppUser(
        id: 'u1',
        email: 'su.g5@intaing.edu.local',
        fullName: 'Ma Su Myat Noe',
        role: AppUserRole.student,
        dateOfBirth: dobUnder13,
      );

      final dobOver13 = DateTime.now().subtract(const Duration(days: 14 * 365));
      final userOver13 = AppUser(
        id: 'u2',
        email: 'student.alice@edu.local',
        fullName: 'Alice Walker',
        role: AppUserRole.student,
        dateOfBirth: dobOver13,
      );

      expect(userUnder13.isUnder13, isTrue);
      expect(userOver13.isUnder13, isFalse);
    });

    test('Grade level heuristic correctly classifies primary grades as under 13', () {
      final userG5 = AppUser(
        id: 'u3',
        email: 'primary@edu.local',
        fullName: 'Primary Student',
        role: AppUserRole.student,
        gradeLevel: 'Grade 5-A',
      );

      final userG8 = AppUser(
        id: 'u4',
        email: 'middle@edu.local',
        fullName: 'Middle Student',
        role: AppUserRole.student,
        gradeLevel: 'Grade 8',
      );

      expect(userG5.isUnder13, isTrue);
      expect(userG8.isUnder13, isFalse);
    });

    test('Role parsing handles "parent" and "guardian" interchangeably', () {
      expect(AppUserRoleExtension.fromString('guardian'), AppUserRole.guardian);
      expect(AppUserRoleExtension.fromString('parent'), AppUserRole.guardian);
      expect(AppUserRoleExtension.fromString('student'), AppUserRole.student);
    });
  });

  group('RBAC Widget Navigation Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTesting();
      await StorageService.clearSession();
    });

    testWidgets('Renders Guardian view when logged in as Guardian', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await StorageService.saveSession(
        token: 'mock-guardian-token',
        user: {
          'id': 'parent-id-01',
          'email': 'parent.clark@edu.local',
          'full_name': 'Daw Khin Mar',
          'role': 'guardian',
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ParentsShellScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('GUARDIAN'), findsWidgets);
      expect(find.text('Children'), findsOneWidget);
    });

    testWidgets('Renders Student Shell when student >= 13 logs in', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await StorageService.saveSession(
        token: 'mock-student-token',
        user: {
          'id': 'student-id-01',
          'email': 'student.alice@edu.local',
          'full_name': 'Alice Walker',
          'role': 'student',
          'grade_level': 'Grade 8',
          'date_of_birth': '2012-03-15T00:00:00Z',
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: StudentShellScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('အချိန်ဇယား'), findsOneWidget);
      expect(find.text('ကတ်ပြား'), findsOneWidget);
    });

    testWidgets('Renders StudentUnder13Screen when student < 13 logs in', (WidgetTester tester) async {
      final childUser = AppUser(
        id: 'child-id-01',
        email: 'su.g5@intaing.edu.local',
        fullName: 'Ma Su Myat Noe',
        role: AppUserRole.student,
        gradeLevel: 'Grade 5-A',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 10 * 365)),
        guardianName: 'Daw Khin Mar',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentUnder13Screen(
            user: childUser,
            onSwitchToGuardian: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Child Safety Policy'), findsOneWidget);
      expect(find.textContaining('Ma Su Myat Noe'), findsOneWidget);
    });
  });
}
