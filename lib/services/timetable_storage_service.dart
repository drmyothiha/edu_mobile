import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/curriculum_period.dart';
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

/// Direct API Service for Student Timetable and School Teaching Shifts.
/// Operates directly via the backend API without local SQLite databases.
class TimetableStorageService {
  static const String _keySchoolShift = 'server_assigned_school_shift';
  static const String _keyLastSync = 'student_timetable_last_sync';
  static const String _keyClassName = 'student_assigned_class_name';
  static const String _keyClassId = 'student_assigned_class_id';
  static const String _keyTimetablePeriods = 'cached_student_curriculum_periods';

  static SharedPreferences? _prefs;

  // In-memory cache for fast session access
  static final Map<String, List<CurriculumPeriod>> _memoryPeriodsCache = {};

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get the server-assigned teaching shift: 'full_day', 'morning', or 'afternoon'
  static Future<String> getSchoolShift() async {
    final prefs = await _instance;
    return prefs.getString(_keySchoolShift) ?? 'full_day';
  }

  /// Set the server-assigned teaching shift
  static Future<void> setSchoolShift(String shift) async {
    final prefs = await _instance;
    await prefs.setString(_keySchoolShift, shift);
  }

  /// Get the assigned class name
  static Future<String?> getClassName() async {
    final prefs = await _instance;
    return prefs.getString(_keyClassName);
  }

  /// Get the last sync timestamp
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await _instance;
    final prefStr = prefs.getString(_keyLastSync);
    if (prefStr != null) {
      try {
        return DateTime.parse(prefStr);
      } catch (_) {}
    }
    return null;
  }

  /// Load timetable periods directly from API or session memory
  static Future<List<CurriculumPeriod>> getPeriods({
    String? shift,
    String? studentId,
    String? gradeLevel,
    bool forceRefresh = false,
  }) async {
    final effectiveShift = shift ?? await getSchoolShift();

    // 1. Resolve student context
    if (studentId == null || gradeLevel == null) {
      final currentUser = await StorageService.getCurrentUser();
      studentId ??= currentUser?.id;
      gradeLevel ??= currentUser?.gradeLevel;
    }

    final cacheKey = '${studentId ?? "default"}_$effectiveShift';

    // Return in-memory cache if available and not forcing refresh
    if (!forceRefresh &&
        _memoryPeriodsCache.containsKey(cacheKey) &&
        _memoryPeriodsCache[cacheKey]!.isNotEmpty) {
      return _memoryPeriodsCache[cacheKey]!;
    }

    // Try direct API fetch
    try {
      final syncResult = await syncWithBackend();
      if (syncResult.periods.isNotEmpty) {
        return syncResult.periods;
      }
    } catch (e) {
      debugPrint('[TimetableService] Direct API fetch error, checking fallback: $e');
    }

    if (_memoryPeriodsCache.containsKey(cacheKey) &&
        _memoryPeriodsCache[cacheKey]!.isNotEmpty) {
      return _memoryPeriodsCache[cacheKey]!;
    }

    // Check SharedPreferences fallback
    final prefs = await _instance;
    final prefKey = '${_keyTimetablePeriods}_$cacheKey';
    final raw = prefs.getString(prefKey);
    if (raw != null) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        final periods = list
            .map((e) => CurriculumPeriod.fromJson(e as Map<String, dynamic>))
            .toList();
        if (periods.isNotEmpty) {
          _memoryPeriodsCache[cacheKey] = periods;
          return periods;
        }
      } catch (_) {}
    }

    // Default Seed according to student's exact grade if API was unreachable
    final defaultPeriods = CurriculumPeriod.getCurriculumForGrade(
      gradeLevel,
      shift: effectiveShift,
      studentId: studentId,
    );
    _memoryPeriodsCache[cacheKey] = defaultPeriods;
    return defaultPeriods;
  }

  /// Save timetable periods into in-memory session cache (and SharedPreferences for fast restore)
  static Future<void> savePeriods(
    List<CurriculumPeriod> periods, {
    String? shift,
    String? className,
    String? classId,
    String? studentId,
    String? gradeLevel,
  }) async {
    final effectiveShift = shift ?? await getSchoolShift();
    final cacheKey = '${studentId ?? "default"}_$effectiveShift';

    _memoryPeriodsCache[cacheKey] = periods;

    final prefs = await _instance;
    final encoded = json.encode(periods.map((p) => p.toJson()).toList());
    await prefs.setString('${_keyTimetablePeriods}_$cacheKey', encoded);
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
    final all = await getPeriods(
      shift: effectiveShift,
      studentId: studentId,
      gradeLevel: gradeLevel,
    );
    return all.where((p) => p.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) => a.startHourDecimal.compareTo(b.startHourDecimal));
  }

  /// Directly queries the backend API for the latest timetable
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
      debugPrint('[TimetableService] API fetch error ($e)');
      final currentShift = await getSchoolShift();
      final currentUser = await StorageService.getCurrentUser();
      final cacheKey = '${currentUser?.id ?? "default"}_$currentShift';

      final cachedPeriods = _memoryPeriodsCache[cacheKey] ??
          CurriculumPeriod.getCurriculumForGrade(
            currentUser?.gradeLevel,
            shift: currentShift,
            studentId: currentUser?.id,
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

  /// Clear in-memory cache (e.g. on logout)
  static void clearCache() {
    _memoryPeriodsCache.clear();
  }
}
