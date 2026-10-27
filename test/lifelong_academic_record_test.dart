import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_mobile/models/lifelong_academic_record.dart';
import 'package:edu_mobile/widgets/lifelong_academic_record_sheet.dart';
import 'package:edu_mobile/parents/screens/guardian_dashboard_screen.dart';
import 'package:edu_mobile/teacher/screens/classroom_sync_screen.dart';
import 'package:edu_mobile/students/screens/student_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Lifelong Academic Record Model Tests (KG to PhD / Highest Level)', () {
    test('Student in KG has KG as highest active level and full pathway to PhD', () {
      final profile = LifelongAcademicProfile.fromStudentData(
        studentId: 'kg-001',
        studentName: 'Maung Aung Kaung Myat',
        rollNo: 'KG-01',
        gradeLevel: 'Kindergarten (KG)',
      );

      expect(profile.studentName, equals('Maung Aung Kaung Myat'));
      expect(profile.entries.length, equals(7));

      // Level 0: KG
      expect(profile.entries[0].stage, equals(AcademicStage.kg));
      expect(profile.entries[0].status, equals(AcademicStatus.current));
      expect(profile.entries[0].isHighestActiveLevel, isTrue);

      // Level 6: PhD
      expect(profile.entries[6].stage, equals(AcademicStage.phd));
      expect(profile.entries[6].status, equals(AcademicStatus.pathway));

      expect(profile.highestLevelEntry.stage, equals(AcademicStage.kg));
      expect(profile.highestLevelTitle, contains('Kindergarten'));
    });

    test('Student in Primary Grade 5 has completed KG, Primary as highest level, and pathway to PhD', () {
      final profile = LifelongAcademicProfile.fromStudentData(
        studentId: 'su-001',
        studentName: 'Ma Su Myat Noe (မစုမြတ်နိုး)',
        rollNo: '5A-01',
        gradeLevel: 'Grade 5-A',
      );

      expect(profile.entries.length, equals(7));

      // Level 0: KG is completed
      expect(profile.entries[0].stage, equals(AcademicStage.kg));
      expect(profile.entries[0].status, equals(AcademicStatus.completed));
      expect(profile.entries[0].isCompleted, isTrue);

      // Level 1: Primary is currently highest active
      expect(profile.entries[1].stage, equals(AcademicStage.primary));
      expect(profile.entries[1].status, equals(AcademicStatus.current));
      expect(profile.entries[1].isHighestActiveLevel, isTrue);

      // Middle, High, Bachelor, Master, PhD are future pathways
      expect(profile.entries[2].stage, equals(AcademicStage.middleSchool));
      expect(profile.entries[2].status, equals(AcademicStatus.pathway));
      expect(profile.entries[3].stage, equals(AcademicStage.highSchool));
      expect(profile.entries[4].stage, equals(AcademicStage.bachelor));
      expect(profile.entries[5].stage, equals(AcademicStage.master));
      expect(profile.entries[6].stage, equals(AcademicStage.phd));

      expect(profile.completedLevelsCount, equals(1));
      expect(profile.completedAndCurrentEntries.length, equals(2));
      expect(profile.highestLevelEntry.stage, equals(AcademicStage.primary));
    });

    test('Advanced Student / Researcher (Alice Walker) reaches PhD highest level', () {
      final profile = LifelongAcademicProfile.fromStudentData(
        studentId: 'alice-001',
        studentName: 'Alice Walker',
        rollNo: 'DOC-2026',
        gradeLevel: 'Doctoral Candidate (PhD Level)',
      );

      expect(profile.entries.length, equals(7));

      // KG to Master's completed
      for (int i = 0; i < 6; i++) {
        expect(profile.entries[i].status, equals(AcademicStatus.completed));
      }

      // PhD is active highest level
      expect(profile.entries[6].stage, equals(AcademicStage.phd));
      expect(profile.entries[6].status, equals(AcademicStatus.current));
      expect(profile.entries[6].isHighestActiveLevel, isTrue);
      expect(profile.highestLevelEntry.stage, equals(AcademicStage.phd));
      expect(profile.highestLevelTitle, contains('Doctor of Philosophy'));
      expect(profile.entries[6].thesisOrCapstoneTitle, isNotNull);
    });

    test('All entries carry W3C VC credential IDs and cryptographic proof hashes', () {
      final profile = LifelongAcademicProfile.fromStudentData(
        studentId: 'test-stu',
        studentName: 'Daw Thida',
        gradeLevel: 'Grade 11 (High School)',
      );

      for (final entry in profile.entries) {
        expect(entry.credentialId, startsWith('urn:uuid:vc-mmr-'));
        expect(entry.blockchainProofHash, startsWith('0x'));
        expect(entry.performanceRating.isNotEmpty, isTrue);
      }
    });
  });

  group('Lifelong Academic Record Modal UI Tests', () {
    testWidgets('Renders all levels from KG to PhD and expands cryptographic proof', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = LifelongAcademicProfile.fromStudentData(
        studentId: 'su-001',
        studentName: 'Ma Su Myat Noe',
        rollNo: '5A-01',
        gradeLevel: 'Grade 5-A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showLifelongAcademicRecordModal(ctx, profile: profile),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      // Open Modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Check header and identity
      expect(find.text('Lifelong Academic Record'), findsOneWidget);
      expect(find.text('Ma Su Myat Noe'), findsOneWidget);
      expect(find.text('HIGHEST LEVEL ATTAINED / ACTIVE'), findsOneWidget);

      // Check trajectory stepper nodes
      expect(find.text('KG'), findsWidgets);
      expect(find.text('BEPS'), findsWidgets);
      expect(find.text('BEMS'), findsWidgets);
      expect(find.text('BEHS'), findsWidgets);
      expect(find.text('B.Sc. / B.C.Sc.'), findsWidgets);
      expect(find.text('M.Sc.'), findsWidgets);
      expect(find.text('Ph.D.'), findsWidgets);

      // Check filter chips
      expect(find.text('All Levels (KG to PhD)'), findsOneWidget);
      expect(find.text('Highest Level & Completed'), findsOneWidget);

      // Tap filter "Highest Level & Completed"
      await tester.tap(find.text('Highest Level & Completed'));
      await tester.pumpAndSettle();

      // Tap back to "All Levels (KG to PhD)"
      await tester.tap(find.text('All Levels (KG to PhD)'));
      await tester.pumpAndSettle();

      // Expand W3C VC proof on first visible card
      final vcExpansion = find.text('W3C Verifiable Credential & Blockchain Proof').first;
      await tester.tap(vcExpansion);
      await tester.pumpAndSettle();

      expect(find.text('Credential URI'), findsOneWidget);
      expect(find.text('Polygon Proof Hash'), findsOneWidget);

      // Export Lifelong Transcript
      final exportBtn = find.text('Export Verifiable Lifelong Transcript (KG → PhD)');
      await tester.ensureVisible(exportBtn);
      await tester.tap(exportBtn);
      await tester.pump();

      expect(find.textContaining('Official Lifelong Transcript generated'), findsOneWidget);
    });
  });

  group('Parent Role Student Profile Lifelong Record Integration', () {
    testWidgets('Parent dashboard displays Lifelong Record button and opens modal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: GuardianDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check child card displays the KG -> PhD Record badge and lifelong record banner
      expect(find.text('KG → PhD Record'), findsOneWidget);
      expect(
        find.text('Lifelong Academic Record (KG to PhD Level)'),
        findsOneWidget,
      );

      // Tapping opens the Lifelong Academic Record modal
      final btn = find.text('Lifelong Academic Record (KG to PhD Level)');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Lifelong Academic Record'), findsOneWidget);
      expect(find.textContaining('Ma Su Myat Noe'), findsWidgets);
      expect(find.text('HIGHEST LEVEL ATTAINED / ACTIVE'), findsOneWidget);
    });
  });

  group('Teacher Role Student Profile Lifelong Record Integration', () {
    testWidgets('Classroom sync screen student card displays KG -> PhD button and opens modal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ClassroomSyncScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check student cards have KG -> PhD badge and full record button
      expect(find.text('KG → PhD'), findsWidgets);
      expect(
        find.text('View Lifelong Academic Record (KG to PhD Level)'),
        findsWidgets,
      );

      // Tap to view lifelong record
      final btn = find.text('View Lifelong Academic Record (KG to PhD Level)').first;
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Lifelong Academic Record'), findsOneWidget);
      expect(find.text('HIGHEST LEVEL ATTAINED / ACTIVE'), findsOneWidget);
    });
  });

  group('Student Role Profile Lifelong Record Integration', () {
    testWidgets('Student settings screen displays Lifelong Record pathway and opens modal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StudentSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check trajectory card and standards profile
      expect(find.text('Educational Pathway: KG to PhD Level'), findsOneWidget);
      expect(
        find.text('View Complete Lifelong Academic Record'),
        findsOneWidget,
      );

      // Tap to open full record
      final btn = find.text('View Complete Lifelong Academic Record');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Lifelong Academic Record'), findsOneWidget);
      expect(find.text('HIGHEST LEVEL ATTAINED / ACTIVE'), findsOneWidget);
    });
  });
}
