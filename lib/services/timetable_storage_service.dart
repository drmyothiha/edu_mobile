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

  /// Load all cached timetable periods for the school-assigned or given shift
  static Future<List<CurriculumPeriod>> getPeriods({String? shift}) async {
    final effectiveShift = shift ?? await getSchoolShift();

    // 1. Query SQLite offline database
    final sqlitePeriods = await SqliteTimetableHelper.getPeriods(shift: effectiveShift);
    if (sqlitePeriods != null && sqlitePeriods.isNotEmpty) {
      return sqlitePeriods;
    }

    // 2. Query SharedPreferences backup cache
    final prefs = await _instance;
    final raw = prefs.getString('${_keyTimetablePeriods}_$effectiveShift');
    if (raw != null) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        final periods = list.map((e) => CurriculumPeriod.fromJson(e as Map<String, dynamic>)).toList();
        if (periods.isNotEmpty) {
          // Re-populate SQLite
          await SqliteTimetableHelper.savePeriods(periods, shift: effectiveShift);
          return periods;
        }
      } catch (_) {}
    }

    // 3. Default Seed from Myanmar Grade 8 curriculum
    final defaultPeriods = CurriculumPeriod.getSampleGrade8Curriculum(shift: effectiveShift);
    await savePeriods(defaultPeriods, shift: effectiveShift);
    return defaultPeriods;
  }

  /// Save timetable periods into offline local storage (SQLite + SharedPreferences)
  static Future<void> savePeriods(
    List<CurriculumPeriod> periods, {
    String? shift,
    String? className,
    String? classId,
  }) async {
    final effectiveShift = shift ?? await getSchoolShift();

    // 1. Save to SQLite
    await SqliteTimetableHelper.savePeriods(
      periods,
      shift: effectiveShift,
      className: className,
      classId: classId,
    );

    // 2. Backup to SharedPreferences
    final prefs = await _instance;
    final encoded = json.encode(periods.map((p) => p.toJson()).toList());
    await prefs.setString('${_keyTimetablePeriods}_$effectiveShift', encoded);
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
  static Future<List<CurriculumPeriod>> getPeriodsForDay(int dayOfWeek, {String? shift}) async {
    final effectiveShift = shift ?? await getSchoolShift();

    // 1. Query SQLite
    final sqliteDayPeriods = await SqliteTimetableHelper.getPeriodsForDay(dayOfWeek, shift: effectiveShift);
    if (sqliteDayPeriods != null && sqliteDayPeriods.isNotEmpty) {
      return sqliteDayPeriods;
    }

    // 2. Fallback
    final all = await getPeriods(shift: effectiveShift);
    return all.where((p) => p.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) => a.startHourDecimal.compareTo(b.startHourDecimal));
  }

  /// Syncs timetable with backend API and updates local SQLite offline storage
  static Future<TimetableSyncResult> syncWithBackend({String? classId}) async {
    try {
      final user = await StorageService.getUser();
      final studentId = user?['id']?.toString();
      final targetClassId = classId ?? user?['class_id']?.toString();

      final data = await ApiService.fetchStudentTimetable(
        studentId: studentId,
        classId: targetClassId,
      );

      final shift = data['shift_type'] as String? ?? 'full_day';
      final className = data['class_name'] as String? ?? 'Grade 8';
      final rawPeriods = (data['periods'] as List<dynamic>?) ?? [];

      List<CurriculumPeriod> periods = [];
      if (rawPeriods.isNotEmpty) {
        periods = rawPeriods
            .map((p) => CurriculumPeriod.fromBackendJson(p as Map<String, dynamic>))
            .toList();
      } else {
        periods = CurriculumPeriod.getSampleGrade8Curriculum(shift: shift);
      }

      // Persist into SQLite offline storage
      await savePeriods(
        periods,
        shift: shift,
        className: className,
        classId: data['class_id']?.toString() ?? targetClassId,
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
      final cachedPeriods = await getPeriods(shift: currentShift);
      final className = await getClassName() ?? 'Grade 8';
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
