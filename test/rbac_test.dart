import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/main.dart';
import 'package:edu_mobile/models/user_role.dart';
import 'package:edu_mobile/services/storage_service.dart';
import 'package:edu_mobile/services/sse_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RBAC & Age Verification Logic', () {
    test('Student under 13 correctly identified via age or birthdate', () {
      final now = DateTime.now();
      final dob10YearsOld = DateTime(now.year - 10, now.month, now.day);
      final under13Student = AppUser(
        id: 'child-1',
        email: 'su.g5@intaing.edu.local',
        fullName: 'Ma Su Myat Noe',
        role: AppUserRole.student,
        dateOfBirth: dob10YearsOld,
        gradeLevel: 'Grade 5-A',
      );

      expect(under13Student.age, 10);
      expect(under13Student.isUnder13, true);

      final dob14YearsOld = DateTime(now.year - 14, now.month, now.day);
      final over13Student = AppUser(
        id: 'child-2',
        email: 'student.alice@edu.local',
        fullName: 'Alice Walker',
        role: AppUserRole.student,
        dateOfBirth: dob14YearsOld,
        gradeLevel: 'Grade 8',
      );

      expect(over13Student.age, 14);
      expect(over13Student.isUnder13, false);
    });

    test('Grade level heuristic correctly classifies primary grades as under 13', () {
      final kgStudent = AppUser(
        id: 'child-kg',
        email: 'aung.kg@intaing.edu.local',
        fullName: 'Maung Aung Kaung Myat',
        role: AppUserRole.student,
        gradeLevel: 'KG',
      );
      expect(kgStudent.isUnder13, true);

      final grade8Student = AppUser(
        id: 'child-g8',
        email: 'bob@edu.local',
        fullName: 'Bob Miller',
        role: AppUserRole.student,
        gradeLevel: 'Grade 8',
      );
      expect(grade8Student.isUnder13, false);
    });

    test('Role parsing handles "parent" and "guardian" interchangeably', () {
      expect(AppUserRoleExtension.fromString('guardian'), AppUserRole.guardian);
      expect(AppUserRoleExtension.fromString('parent'), AppUserRole.guardian);
      expect(AppUserRoleExtension.fromString('teacher'), AppUserRole.teacher);
      expect(AppUserRoleExtension.fromString('student'), AppUserRole.student);
    });
  });

  group('RBAC Widget Navigation Tests', () {
    setUp(() {
      SseNotificationService.stopListening();
    });

    tearDown(() {
      SseNotificationService.stopListening();
    });

    testWidgets('Renders Guardian view when logged in as Guardian', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'auth_user': json.encode({
          'id': 'g-1',
          'email': 'parent.clark@edu.local',
          'full_name': 'Daw Khin Mar',
          'role': 'guardian',
        }),
      });
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      expect(find.text('Daw Khin Mar'), findsOneWidget);
      expect(find.text('Children'), findsOneWidget);
      expect(find.text('Child Pass'), findsNothing);
      expect(find.text('Teacher Chat'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('Renders Under-13 Protection screen when child < 13 logs in directly', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'auth_user': json.encode({
          'id': 'c-1',
          'email': 'su.g5@intaing.edu.local',
          'full_name': 'Ma Su Myat Noe',
          'role': 'student',
          'grade_level': 'Grade 5-A',
          'date_of_birth': DateTime(DateTime.now().year - 10, 1, 1).toIso8601String(),
          'guardian_name': 'Daw Khin Mar',
        }),
      });
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      expect(find.text('Account Managed by Guardian'), findsOneWidget);
      expect(find.text('Child Safety Policy'), findsOneWidget);
      expect(find.textContaining('Child Digital Safety Standard'), findsOneWidget);
      expect(find.textContaining('Switch to Guardian Account'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('Renders Student ID Wallet when student >= 13 logs in', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'auth_user': json.encode({
          'id': 'c-2',
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

      expect(find.text('အချိန်ဇယား'), findsOneWidget);
      expect(find.text('ကတ်ပြား'), findsOneWidget);
      expect(find.text('သတင်းလွှာ'), findsOneWidget);
      expect(find.text('ဆက်တင်'), findsOneWidget);
      expect(find.text('Whole-Child'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });

    testWidgets('Renders Teacher tools when logged in as Teacher', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'auth_user': json.encode({
          'id': 't-1',
          'email': 'teacher.smith@edu.local',
          'full_name': 'Daw Thida',
          'role': 'teacher',
        }),
      });
      StorageService.resetForTesting();

      await tester.pumpWidget(const EduMobileApp());
      await tester.pumpAndSettle();

      expect(find.text('Kiosk'), findsOneWidget);
      expect(find.text('Whole-Child'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      SseNotificationService.stopListening();
    });
  });
}
