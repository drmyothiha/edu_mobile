import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/models/curriculum_period.dart';
import 'package:edu_mobile/services/timetable_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CurriculumPeriod Backend & SQLite Serialization Tests', () {
    test('CurriculumPeriod.fromBackendJson parses backend DTO correctly', () {
      final backendJson = {
        'id': 'per-class123-1-1',
        'class_id': 'class123',
        'grade_level': 'Grade 8',
        'section': 'Section A',
        'day_of_week': 1,
        'start_time': '08:00',
        'end_time': '09:00',
        'period_index': 1,
        'subject_name': 'Mathematics',
        'subject_name_my': 'သင်္ချာ',
        'subject_code': 'MTH-301',
        'teacher_name': 'ဒေါ်သီတာ (Daw Thida)',
        'room_number': 'Room 302',
        'color_hex': '#3B82F6',
        'topic': 'Chapter 1: Quadratic Equations',
        'shift_type': 'morning',
      };

      final period = CurriculumPeriod.fromBackendJson(backendJson);

      expect(period.id, equals('per-class123-1-1'));
      expect(period.subjectName, equals('Mathematics'));
      expect(period.subjectNameMy, equals('သင်္ချာ'));
      expect(period.subjectCode, equals('MTH-301'));
      expect(period.teacherName, equals('ဒေါ်သီတာ (Daw Thida)'));
      expect(period.room, equals('Room 302'));
      expect(period.dayOfWeek, equals(1));
      expect(period.startTime.hour, equals(8));
      expect(period.startTime.minute, equals(0));
      expect(period.endTime.hour, equals(9));
      expect(period.endTime.minute, equals(0));
      expect(period.color, equals(const Color(0xFF3B82F6)));
      expect(period.chapterTitle, equals('Chapter 1: Quadratic Equations'));
      expect(period.shiftSection, equals('morning'));
      expect(period.timeRangeString, equals('08:00 - 09:00'));
    });

    test('CurriculumPeriod SQLite round-trip through toSqliteMap and fromSqliteMap', () {
      const original = CurriculumPeriod(
        id: 'test-period-2',
        subjectCode: 'ENG-201',
        subjectName: 'English',
        subjectNameMy: 'အင်္ဂလိပ်စာ',
        teacherName: 'ဦးမောင်မောင် (U Maung Maung)',
        room: 'Room 101',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 0),
        color: Color(0xFF10B981),
        chapterTitle: 'Unit 2: Active & Passive Voice',
        chapterDescription: 'Grammar practice and essay writing',
        homework: 'Complete exercise 3 on page 42',
        shiftSection: 'full_day',
      );

      final map = original.toSqliteMap();
      expect(map['id'], equals('test-period-2'));
      expect(map['subject_code'], equals('ENG-201'));
      expect(map['day_of_week'], equals(2));
      expect(map['start_hour'], equals(9));
      expect(map['end_hour'], equals(10));
      expect(map['homework'], equals('Complete exercise 3 on page 42'));

      final restored = CurriculumPeriod.fromSqliteMap(map);
      expect(restored.id, equals(original.id));
      expect(restored.subjectCode, equals(original.subjectCode));
      expect(restored.subjectName, equals(original.subjectName));
      expect(restored.subjectNameMy, equals(original.subjectNameMy));
      expect(restored.teacherName, equals(original.teacherName));
      expect(restored.room, equals(original.room));
      expect(restored.dayOfWeek, equals(original.dayOfWeek));
      expect(restored.startTime.hour, equals(original.startTime.hour));
      expect(restored.endTime.hour, equals(original.endTime.hour));
      expect(restored.color.toARGB32(), equals(original.color.toARGB32()));
      expect(restored.chapterTitle, equals(original.chapterTitle));
      expect(restored.homework, equals(original.homework));
      expect(restored.shiftSection, equals(original.shiftSection));
    });
  });

  group('TimetableStorageService Offline Storage & Shift Tests', () {
    test('Default timetable seed is provided when empty', () async {
      final periods = await TimetableStorageService.getPeriods(shift: 'full_day');
      expect(periods, isNotEmpty);
      expect(periods.length, greaterThanOrEqualTo(5));

      final mondayPeriods = await TimetableStorageService.getPeriodsForDay(1, shift: 'full_day');
      expect(mondayPeriods, isNotEmpty);
      expect(mondayPeriods.first.dayOfWeek, equals(1));
    });

    test('Save and retrieve updated timetable periods with shift section', () async {
      final updatedPeriod = CurriculumPeriod.fromBackendJson({
        'id': 'p-custom-1',
        'subject_code': 'SCI-401',
        'subject_name': 'Science',
        'subject_name_my': 'သိပ္ပံ',
        'teacher_name': 'ဒေါ်နွယ်နွယ် (Daw Nwe Nwe)',
        'room_number': 'Lab 1',
        'day_of_week': 3,
        'start_time': '10:00',
        'end_time': '11:00',
        'color_hex': '#8B5CF6',
        'topic': 'Electricity & Magnetism',
        'shift_type': 'morning',
      });

      await TimetableStorageService.savePeriods(
        [updatedPeriod],
        shift: 'morning',
        className: 'Grade 8-B',
        classId: 'class-8b-id',
      );

      final retrieved = await TimetableStorageService.getPeriods(shift: 'morning');
      expect(retrieved.length, equals(1));
      expect(retrieved.first.subjectName, equals('Science'));
      expect(retrieved.first.subjectCode, equals('SCI-401'));
      expect(retrieved.first.teacherName, equals('ဒေါ်နွယ်နွယ် (Daw Nwe Nwe)'));

      final className = await TimetableStorageService.getClassName();
      expect(className, equals('Grade 8-B'));
    });

    test('Offline sync fallback gracefully provides cached periods without crashing', () async {
      final result = await TimetableStorageService.syncWithBackend();
      expect(result.periods, isNotEmpty);
      expect(result.shift, isNotEmpty);
    });
  });
}
