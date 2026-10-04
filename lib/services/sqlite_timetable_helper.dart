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
  static const int dbVersion = 1;

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
              id TEXT PRIMARY KEY,
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
              shift_section TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableMetadata (
              meta_key TEXT PRIMARY KEY,
              meta_value TEXT
            )
          ''');
        },
      );
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
  }) async {
    final db = await getDatabase();
    if (db == null) return false;

    try {
      await db.transaction((txn) async {
        final batch = txn.batch();

        if (shift != null && shift.isNotEmpty) {
          batch.delete(tablePeriods, where: 'shift_section = ?', whereArgs: [shift]);
        } else {
          batch.delete(tablePeriods);
        }

        for (final period in periods) {
          batch.insert(
            tablePeriods,
            period.toSqliteMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        if (shift != null) {
          batch.insert(
            tableMetadata,
            {'meta_key': 'school_shift', 'meta_value': shift},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        if (className != null) {
          batch.insert(
            tableMetadata,
            {'meta_key': 'class_name', 'meta_value': className},
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
        batch.insert(
          tableMetadata,
          {'meta_key': 'last_sync_time', 'meta_value': DateTime.now().toIso8601String()},
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

  /// Fetch all cached periods for the given shift from SQLite
  static Future<List<CurriculumPeriod>?> getPeriods({String? shift}) async {
    final db = await getDatabase();
    if (db == null) return null;

    try {
      List<Map<String, dynamic>> maps;
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

      if (maps.isEmpty) return null;
      return maps.map((m) => CurriculumPeriod.fromSqliteMap(m)).toList();
    } catch (e) {
      debugPrint('[SQLite] Error querying periods: $e');
      return null;
    }
  }

  /// Fetch cached periods for a single day of week (1=Mon ... 7=Sun) from SQLite
  static Future<List<CurriculumPeriod>?> getPeriodsForDay(int dayOfWeek, {String? shift}) async {
    final db = await getDatabase();
    if (db == null) return null;

    try {
      List<Map<String, dynamic>> maps;
      if (shift != null && shift.isNotEmpty) {
        maps = await db.query(
          tablePeriods,
          where: 'day_of_week = ? AND shift_section = ?',
          whereArgs: [dayOfWeek, shift],
          orderBy: 'start_hour ASC, start_minute ASC',
        );
      } else {
        maps = await db.query(
          tablePeriods,
          where: 'day_of_week = ?',
          whereArgs: [dayOfWeek],
          orderBy: 'start_hour ASC, start_minute ASC',
        );
      }

      if (maps.isEmpty) return null;
      return maps.map((m) => CurriculumPeriod.fromSqliteMap(m)).toList();
    } catch (e) {
      debugPrint('[SQLite] Error querying periods for day: $e');
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
