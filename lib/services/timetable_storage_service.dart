import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/curriculum_period.dart';
import 'sqlite_timetable_helper.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Result object for Timetable synchronization operations
class TimetableSyncResult {
  final bool success;
  final List<CurriculumPeriod> periods;
  final String shift;
  final String className;
  final DateTime? syncedAt;
  final bool isOffline;
  final String? errorMessage;

  const TimetableSyncResult({
    required this.success,
    required this.periods,
    required this.shift,
    required this.className,
    this.syncedAt,
    this.isOffline = false,
    this.errorMessage,
  });
}

/// Database & Local Storage Service for Student Timetable and School Teaching Shifts.
///
/// Features:
/// 1. Primary offline storage via SQLite (`student_timetable.db` using `sqflite`)
/// 2. Fast secondary cache in `SharedPreferences`
/// 3. Bi-directional sync with the Go backend when online
/// 4. Graceful zero-latency fallback to SQLite offline cache when offline
class TimetableStorageService {
  static const String _keyTimetablePeriods = 'cached_student_curriculum_periods';
  static const String _keySchoolShift = 'server_assigned_school_shift';
  static const String _keyLastSync = 'student_timetable_last_sync';
  static const String _keyClassName = 'student_assigned_class_name';
  static const String _keyClassId = 'student_assigned_class_id';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get the server-assigned teaching shift: 'full_day', 'morning', or 'afternoon'
  static Future<String> getSchoolShift() async {
    // 1. Try SQLite metadata
    final sqliteShift = await SqliteTimetableHelper.getMetadata('school_shift');
    if (sqliteShift != null && sqliteShift.isNotEmpty) {
      return sqliteShift;
    }

    // 2. Fallback to SharedPreferences
    final prefs = await _instance;
    return prefs.getString(_keySchoolShift) ?? 'full_day';
  }

  /// Set the server-assigned teaching shift
  static Future<void> setSchoolShift(String shift) async {
    await SqliteTimetableHelper.setMetadata('school_shift', shift);
    final prefs = await _instance;
    await prefs.setString(_keySchoolShift, shift);
  }

  /// Get the assigned class name
  static Future<String?> getClassName() async {
    final sqliteName = await SqliteTimetableHelper.getMetadata('class_name');
    if (sqliteName != null && sqliteName.isNotEmpty) {
      return sqliteName;
    }
    final prefs = await _instance;
    return prefs.getString(_keyClassName);
  }

  /// Get the last sync timestamp
  static Future<DateTime?> getLastSyncTime() async {
    final sqliteTimeStr = await SqliteTimetableHelper.getMetadata('last_sync_time');
    if (sqliteTimeStr != null && sqliteTimeStr.isNotEmpty) {
      try {
        return DateTime.parse(sqliteTimeStr);
      } catch (_) {}
    }
    final prefs = await _instance;
    final prefStr = prefs.getString(_keyLastSync);
    if (prefStr != null) {
      try {
        return DateTime.parse(prefStr);
      } catch (_) {}
    }
    return null;
  }

  /// Load all cached timetable periods for the student and school-assigned shift
  static Future<List<CurriculumPeriod>> getPeriods({
    String? shift,
    String? studentId,
    String? gradeLevel,
  }) async {
    final effectiveShift = shift ?? await getSchoolShift();

    // 1. Resolve student context if not passed
    if (studentId == null || gradeLevel == null) {
      final currentUser = await StorageService.getCurrentUser();
      studentId ??= currentUser?.id;
      gradeLevel ??= currentUser?.gradeLevel;
    }

    // 2. Query SQLite offline database (user context-aware)
    final sqlitePeriods = await SqliteTimetableHelper.getPeriods(
      shift: effectiveShift,
      studentId: studentId,
      gradeLevel: gradeLevel,
    );
    if (sqlitePeriods != null && sqlitePeriods.isNotEmpty) {
      return sqlitePeriods;
    }

    // 3. Query SharedPreferences backup cache (namespaced by student)
    final prefs = await _instance;
    final cacheKey = '${_keyTimetablePeriods}_${studentId ?? "default"}_$effectiveShift';
    final raw = prefs.getString(cacheKey);
    if (raw != null) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        final periods = list
            .map((e) => CurriculumPeriod.fromJson(e as Map<String, dynamic>))
            .toList();
        if (periods.isNotEmpty) {
          // Re-populate SQLite
          await SqliteTimetableHelper.savePeriods(
            periods,
            shift: effectiveShift,
            studentId: studentId,
            gradeLevel: gradeLevel,
          );
          return periods;
        }
      } catch (_) {}
    }

    // 4. Default Seed according to student's exact grade (KG, Grade 5, or Grade 8)
    final defaultPeriods = CurriculumPeriod.getCurriculumForGrade(
      gradeLevel,
      shift: effectiveShift,
      studentId: studentId,
    );
    await savePeriods(
      defaultPeriods,
      shift: effectiveShift,
      studentId: studentId,
      gradeLevel: gradeLevel,
    );
    return defaultPeriods;
  }

  /// Save timetable periods into offline local storage (SQLite + SharedPreferences)
  static Future<void> savePeriods(
    List<CurriculumPeriod> periods, {
    String? shift,
    String? className,
    String? classId,
    String? studentId,
    String? gradeLevel,
  }) async {
    final effectiveShift = shift ?? await getSchoolShift();

    // 1. Save to SQLite
    await SqliteTimetableHelper.savePeriods(
      periods,
      shift: effectiveShift,
      className: className,
      classId: classId,
      studentId: studentId,
      gradeLevel: gradeLevel,
    );

    // 2. Backup to SharedPreferences (namespaced by student)
    final prefs = await _instance;
    final encoded = json.encode(periods.map((p) => p.toJson()).toList());
    final cacheKey = '${_keyTimetablePeriods}_${studentId ?? "default"}_$effectiveShift';
    await prefs.setString(cacheKey, encoded);
    await prefs.setString(_keySchoolShift, effectiveShift);
    await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
    if (className != null) {
      await prefs.setString(_keyClassName, className);
    }
    if (classId != null) {
      await prefs.setString(_keyClassId, classId);
    }
  }

  /// Fetch periods for a specific day of the week (1 = Monday ... 7 = Sunday)
  static Future<List<CurriculumPeriod>> getPeriodsForDay(
    int dayOfWeek, {
    String? shift,
    String? studentId,
    String? gradeLevel,
  }) async {
    final effectiveShift = shift ?? await getSchoolShift();

    // 1. Query SQLite
    final sqliteDayPeriods = await SqliteTimetableHelper.getPeriodsForDay(
      dayOfWeek,
      shift: effectiveShift,
      studentId: studentId,
      gradeLevel: gradeLevel,
    );
    if (sqliteDayPeriods != null && sqliteDayPeriods.isNotEmpty) {
      return sqliteDayPeriods;
    }

    // 2. Fallback
    final all = await getPeriods(
      shift: effectiveShift,
      studentId: studentId,
      gradeLevel: gradeLevel,
    );
    return all.where((p) => p.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) => a.startHourDecimal.compareTo(b.startHourDecimal));
  }

  /// Syncs timetable with backend API and updates local SQLite offline storage
  static Future<TimetableSyncResult> syncWithBackend({String? classId}) async {
    try {
      final user = await StorageService.getUser();
      final studentId = user?['id']?.toString();
      final gradeLevel = user?['grade_level']?.toString();
      final targetClassId = classId ?? user?['class_id']?.toString();

      final data = await ApiService.fetchStudentTimetable(
        studentId: studentId,
        classId: targetClassId,
      );

      final shift = data['shift_type'] as String? ?? 'full_day';
      final className = data['class_name'] as String? ?? (gradeLevel ?? 'Grade 8');
      final rawPeriods = (data['periods'] as List<dynamic>?) ?? [];

      List<CurriculumPeriod> periods = [];
      if (rawPeriods.isNotEmpty) {
        periods = rawPeriods
            .map((p) => CurriculumPeriod.fromBackendJson(p as Map<String, dynamic>))
            .toList();
      } else {
        periods = CurriculumPeriod.getCurriculumForGrade(
          gradeLevel,
          shift: shift,
          studentId: studentId,
        );
      }

      // Persist into SQLite offline storage with student context
      await savePeriods(
        periods,
        shift: shift,
        className: className,
        classId: data['class_id']?.toString() ?? targetClassId,
        studentId: studentId,
        gradeLevel: gradeLevel,
      );

      return TimetableSyncResult(
        success: true,
        periods: periods,
        shift: shift,
        className: className,
        syncedAt: DateTime.now(),
        isOffline: false,
      );
    } catch (e) {
      debugPrint('[TimetableSync] Sync error ($e), falling back to offline SQLite database.');
      final currentShift = await getSchoolShift();
      final currentUser = await StorageService.getCurrentUser();
      final cachedPeriods = await getPeriods(
        shift: currentShift,
        studentId: currentUser?.id,
        gradeLevel: currentUser?.gradeLevel,
      );
      final className = await getClassName() ?? (currentUser?.gradeLevel ?? 'Grade 8');
      final lastSync = await getLastSyncTime();

      return TimetableSyncResult(
        success: false,
        periods: cachedPeriods,
        shift: currentShift,
        className: className,
        syncedAt: lastSync,
        isOffline: true,
        errorMessage: e.toString(),
      );
    }
  }
}
