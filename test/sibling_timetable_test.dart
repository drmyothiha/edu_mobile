import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/models/curriculum_period.dart';
import 'package:edu_mobile/services/timetable_storage_service.dart';
import 'package:edu_mobile/services/storage_service.dart';
import 'package:edu_mobile/services/nfc_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Sibling-Aware Offline Timetable & Hot-Swapping Tests', () {
    test('CurriculumPeriod generator returns grade-appropriate subjects', () {
      final kgPeriods = CurriculumPeriod.getCurriculumForGrade(
        'Kindergarten (KG)',
        studentId: 'stu-kg-001',
      );
      final g5Periods = CurriculumPeriod.getCurriculumForGrade(
        'Grade 5-A',
        studentId: 'stu-g5-001',
      );
      final g8Periods = CurriculumPeriod.getCurriculumForGrade(
        'Grade 8',
        studentId: 'stu-g8-001',
      );

      // Verify KG subjects
      expect(kgPeriods.any((p) => p.subjectCode.contains('KG-SPK')), isTrue);
      expect(kgPeriods.any((p) => p.subjectCode.contains('KG-ART')), isTrue);
      expect(kgPeriods.first.studentId, 'stu-kg-001');

      // Verify Grade 5 subjects
      expect(g5Periods.any((p) => p.subjectCode.contains('MYAN-5')), isTrue);
      expect(g5Periods.any((p) => p.subjectCode.contains('SCI-5')), isTrue);
      expect(g5Periods.first.studentId, 'stu-g5-001');

      // Verify Grade 8 subjects
      expect(g8Periods.any((p) => p.subjectCode.contains('MYAN-8')), isTrue);
      expect(g8Periods.any((p) => p.subjectCode.contains('SCI-8')), isTrue);
    });

    test('TimetableStorageService partitions offline periods between siblings without collision', () async {
      const siblingAId = 'sibling-a-kg-uuid';
      const siblingBId = 'sibling-b-g5-uuid';

      // 1. Save Sibling A (KG) periods
      final kgPeriods = CurriculumPeriod.getCurriculumForGrade(
        'Kindergarten (KG)',
        studentId: siblingAId,
      );
      await TimetableStorageService.savePeriods(
        kgPeriods,
        studentId: siblingAId,
        gradeLevel: 'Kindergarten (KG)',
      );

      // 2. Save Sibling B (Grade 5) periods
      final g5Periods = CurriculumPeriod.getCurriculumForGrade(
        'Grade 5-A',
        studentId: siblingBId,
      );
      await TimetableStorageService.savePeriods(
        g5Periods,
        studentId: siblingBId,
        gradeLevel: 'Grade 5-A',
      );

      // 3. Query Sibling A periods specifically
      final loadedA = await TimetableStorageService.getPeriods(
        studentId: siblingAId,
        gradeLevel: 'Kindergarten (KG)',
      );

      // 4. Query Sibling B periods specifically
      final loadedB = await TimetableStorageService.getPeriods(
        studentId: siblingBId,
        gradeLevel: 'Grade 5-A',
      );

      // Verify separation: Sibling A has KG subjects, Sibling B has Grade 5 subjects
      expect(loadedA.any((p) => p.subjectCode.contains('KG-SPK')), isTrue);
      expect(loadedA.any((p) => p.subjectCode.contains('MYAN-5')), isFalse);

      expect(loadedB.any((p) => p.subjectCode.contains('MYAN-5')), isTrue);
      expect(loadedB.any((p) => p.subjectCode.contains('KG-SPK')), isFalse);
    });

    test('Hot-swapping student via NfcAuthService updates active session context', () async {
      // 1. Sibling A logs in
      final resA = await NfcAuthService.simulateDemoCardLogin(
        studentName: 'Maung Aung Kaung Myat',
        rollNumber: 'ROLL-KG-001',
        gradeLevel: 'Kindergarten (KG)',
      );
      expect(resA.success, isTrue);

      var currentUser = await StorageService.getCurrentUser();
      expect(currentUser?.fullName, 'Maung Aung Kaung Myat');

      // Load timetable in Sibling A context
      var currentPeriods = await TimetableStorageService.getPeriods(
        studentId: currentUser?.id,
        gradeLevel: currentUser?.gradeLevel,
      );
      expect(currentPeriods.any((p) => p.subjectCode.contains('KG-')), isTrue);

      // 2. Sibling B taps their card (Hot-Swap)
      final resB = await NfcAuthService.simulateDemoCardLogin(
        studentName: 'Ma Su Myat Noe',
        rollNumber: 'ROLL-G5-001',
        gradeLevel: 'Grade 5-A',
      );
      expect(resB.success, isTrue);

      currentUser = await StorageService.getCurrentUser();
      expect(currentUser?.fullName, 'Ma Su Myat Noe');

      // Load timetable in Sibling B context
      currentPeriods = await TimetableStorageService.getPeriods(
        studentId: currentUser?.id,
        gradeLevel: currentUser?.gradeLevel,
      );
      expect(currentPeriods.any((p) => p.subjectCode.contains('MYAN-5')), isTrue);
    });
  });
}
