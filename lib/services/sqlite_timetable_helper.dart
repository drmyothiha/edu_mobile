import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/curriculum_period.dart';

/// SQLite Database Helper for Student Curriculum Timetable offline storage.
///
/// Ensures offline access on Android & iOS devices even with zero internet connectivity.
/// Falls back safely when running in web or unit tests without native SQLite bindings.
class SqliteTimetableHelper {
  static const String dbName = 'student_timetable.db';
  static const int dbVersion = 2;

  static const String tablePeriods = 'curriculum_periods';
  static const String tableMetadata = 'timetable_metadata';

  static Database? _database;
  static bool _sqliteAvailable = true;

  @visibleForTesting
  static void setMockDatabase(Database? db) {
    _database = db;
    _sqliteAvailable = db != null;
  }

  static bool get isSqliteAvailable => _sqliteAvailable;

  /// Returns active SQLite database instance
  static Future<Database?> getDatabase() async {
    if (!_sqliteAvailable) return null;
    if (_database != null && _database!.isOpen) return _database!;

    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, dbName);

      _database = await openDatabase(
        path,
        version: dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $tablePeriods (
              id TEXT,
              student_id TEXT,
              grade_level TEXT,
              subject_code TEXT,
              subject_name TEXT,
              subject_name_my TEXT,
              teacher_name TEXT,
              room TEXT,
              day_of_week INTEGER,
              start_hour INTEGER,
              start_minute INTEGER,
              end_hour INTEGER,
              end_minute INTEGER,
              color_value INTEGER,
              chapter_title TEXT,
              chapter_description TEXT,
              homework TEXT,
              shift_section TEXT,
              PRIMARY KEY (id, student_id)
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableMetadata (
              meta_key TEXT PRIMARY KEY,
              meta_value TEXT
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            try {
              await db.execute('ALTER TABLE $tablePeriods ADD COLUMN student_id TEXT DEFAULT ""');
            } catch (_) {}
            try {
              await db.execute('ALTER TABLE $tablePeriods ADD COLUMN grade_level TEXT DEFAULT ""');
            } catch (_) {}
          }
        },
      );

      // Defensive migration check
      try {
        final cols = await _database!.rawQuery('PRAGMA table_info($tablePeriods)');
        final colNames = cols.map((c) => c['name']?.toString()).toSet();
        if (!colNames.contains('student_id')) {
          await _database!.execute('ALTER TABLE $tablePeriods ADD COLUMN student_id TEXT DEFAULT ""');
        }
        if (!colNames.contains('grade_level')) {
          await _database!.execute('ALTER TABLE $tablePeriods ADD COLUMN grade_level TEXT DEFAULT ""');
        }
      } catch (_) {}

      _sqliteAvailable = true;
      return _database;
    } catch (e) {
      // In headless unit tests or Web, sqflite platform channels may be absent
      debugPrint('[SQLite] Note: Native SQLite not initialized ($e), using local fallback.');
      _sqliteAvailable = false;
      return null;
    }
  }

  /// Bulk insert or update periods in SQLite database inside a transaction
  static Future<bool> savePeriods(
    List<CurriculumPeriod> periods, {
    String? shift,
    String? className,
    String? classId,
    String? studentId,
    String? gradeLevel,
  }) async {
    final db = await getDatabase();
    if (db == null) return false;

    try {
      await db.transaction((txn) async {
        final batch = txn.batch();

        if (studentId != null && studentId.isNotEmpty) {
          if (shift != null && shift.isNotEmpty) {
            batch.delete(
              tablePeriods,
              where: 'student_id = ? AND shift_section = ?',
              whereArgs: [studentId, shift],
            );
          } else {
            batch.delete(
              tablePeriods,
              where: 'student_id = ?',
              whereArgs: [studentId],
            );
          }
        } else if (shift != null && shift.isNotEmpty) {
          batch.delete(tablePeriods, where: 'shift_section = ?', whereArgs: [shift]);
        } else {
          batch.delete(tablePeriods);
        }

        for (final period in periods) {
          final map = period.toSqliteMap();
          if (studentId != null && studentId.isNotEmpty) {
            map['student_id'] = studentId;
          }
          if (gradeLevel != null && gradeLevel.isNotEmpty) {
            map['grade_level'] = gradeLevel;
          }
          batch.insert(
            tablePeriods,
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        if (shift != null) {
          final shiftKey = (studentId != null && studentId.isNotEmpty)
              ? 'school_shift_$studentId'
              : 'school_shift';
          batch.insert(
            tableMetadata,
            {'meta_key': shiftKey, 'meta_value': shift},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        if (className != null) {
          final classKey = (studentId != null && studentId.isNotEmpty)
              ? 'class_name_$studentId'
              : 'class_name';
          batch.insert(
            tableMetadata,
            {'meta_key': classKey, 'meta_value': className},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        if (classId != null) {
          batch.insert(
            tableMetadata,
            {'meta_key': 'class_id', 'meta_value': classId},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        final syncKey = (studentId != null && studentId.isNotEmpty)
            ? 'last_sync_time_$studentId'
            : 'last_sync_time';
        batch.insert(
          tableMetadata,
          {'meta_key': syncKey, 'meta_value': DateTime.now().toIso8601String()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await batch.commit(noResult: true);
      });
      return true;
    } catch (e) {
      debugPrint('[SQLite] Error saving periods: $e');
      return false;
    }
  }

  /// Fetch all cached periods for the given student/grade and shift from SQLite
  static Future<List<CurriculumPeriod>?> getPeriods({
    String? shift,
    String? studentId,
    String? gradeLevel,
  }) async {
    final db = await getDatabase();
    if (db == null) return null;

    try {
      List<Map<String, dynamic>> maps = [];

      // 1. Try querying with exact studentId
      if (studentId != null && studentId.isNotEmpty) {
        if (shift != null && shift.isNotEmpty) {
          maps = await db.query(
            tablePeriods,
            where: 'student_id = ? AND shift_section = ?',
            whereArgs: [studentId, shift],
            orderBy: 'day_of_week ASC, start_hour ASC, start_minute ASC',
          );
        } else {
          maps = await db.query(
            tablePeriods,
            where: 'student_id = ?',
            whereArgs: [studentId],
            orderBy: 'day_of_week ASC, start_hour ASC, start_minute ASC',
          );
        }
      }

      // 2. If empty and gradeLevel provided, query by gradeLevel
      if (maps.isEmpty && gradeLevel != null && gradeLevel.isNotEmpty) {
        if (shift != null && shift.isNotEmpty) {
          maps = await db.query(
            tablePeriods,
            where: 'grade_level = ? AND shift_section = ?',
            whereArgs: [gradeLevel, shift],
            orderBy: 'day_of_week ASC, start_hour ASC, start_minute ASC',
          );
        } else {
          maps = await db.query(
            tablePeriods,
            where: 'grade_level = ?',
            whereArgs: [gradeLevel],
            orderBy: 'day_of_week ASC, start_hour ASC, start_minute ASC',
          );
        }
      }

      // 3. Fallback to generic shift query
      if (maps.isEmpty && (studentId == null || studentId.isEmpty)) {
        if (shift != null && shift.isNotEmpty) {
          maps = await db.query(
            tablePeriods,
            where: 'shift_section = ?',
            whereArgs: [shift],
            orderBy: 'day_of_week ASC, start_hour ASC, start_minute ASC',
          );
        } else {
          maps = await db.query(
            tablePeriods,
            orderBy: 'day_of_week ASC, start_hour ASC, start_minute ASC',
          );
        }
      }

      if (maps.isEmpty) return null;
      return maps.map((m) => CurriculumPeriod.fromSqliteMap(m)).toList();
    } catch (e) {
      debugPrint('[SQLite] Error querying periods: $e');
      return null;
    }
  }

  /// Fetch cached periods for a single day of week (1=Mon ... 7=Sun) from SQLite
  static Future<List<CurriculumPeriod>?> getPeriodsForDay(
    int dayOfWeek, {
    String? shift,
    String? studentId,
    String? gradeLevel,
  }) async {
    final db = await getDatabase();
    if (db == null) return null;

    try {
      String whereClause = 'day_of_week = ?';
      List<dynamic> whereArgs = [dayOfWeek];

      if (studentId != null && studentId.isNotEmpty) {
        whereClause += ' AND student_id = ?';
        whereArgs.add(studentId);
      } else if (gradeLevel != null && gradeLevel.isNotEmpty) {
        whereClause += ' AND grade_level = ?';
        whereArgs.add(gradeLevel);
      }

      if (shift != null && shift.isNotEmpty) {
        whereClause += ' AND shift_section = ?';
        whereArgs.add(shift);
      }

      final maps = await db.query(
        tablePeriods,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'start_hour ASC, start_minute ASC',
      );

      if (maps.isEmpty) return null;
      return maps.map((m) => CurriculumPeriod.fromSqliteMap(m)).toList();
    } catch (e) {
      debugPrint('[SQLite] Error querying day periods: $e');
      return null;
    }
  }

  /// Set metadata item in SQLite
  static Future<void> setMetadata(String key, String value) async {
    final db = await getDatabase();
    if (db == null) return;
    try {
      await db.insert(
        tableMetadata,
        {'meta_key': key, 'meta_value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  /// Get metadata item from SQLite
  static Future<String?> getMetadata(String key) async {
    final db = await getDatabase();
    if (db == null) return null;
    try {
      final res = await db.query(
        tableMetadata,
        where: 'meta_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (res.isNotEmpty) {
        return res.first['meta_value'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Clear all cached timetable SQLite data
  static Future<void> clearAll() async {
    final db = await getDatabase();
    if (db == null) return;
    try {
      await db.delete(tablePeriods);
      await db.delete(tableMetadata);
    } catch (_) {}
  }
}
