import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/verifiable_credential.dart';
import '../models/whole_child_record.dart';
import '../models/user_role.dart';
import '../models/guardian_child.dart';
import 'jwt_decoder.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';
  static const String _keyCachedCredential = 'cached_student_credential';
  static const String _keyScanHistory = 'gate_scan_history';
  static const String _keyServerUrl = 'server_api_base_url';
  static const String _keyAppMode =
      'app_current_mode'; // 'student' or 'inspector'
  static const String _keySelectedChild = 'guardian_selected_child_index';
  static const String _keyGuardianChildren = 'guardian_cached_children';

  // Default server API base URL (Production Server with SSL)
  static const String productionServerUrl = 'https://136.85.95.216';

  static String get defaultServerUrl => productionServerUrl;

  /// Normalizes user-entered IP or URL into a valid base URL.
  /// Examples:
  ///   "136.85.95.216" -> "https://136.85.95.216"
  ///   "10.0.2.2:8080" -> "http://10.0.2.2:8080"
  ///   "http://localhost:8080/" -> "http://localhost:8080"
  ///   "https://136.85.95.216/api/v1" -> "https://136.85.95.216"
  static String normalizeServerUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) {
      return defaultServerUrl;
    }

    // Strip trailing slashes
    while (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1).trim();
    }

    // Strip trailing /api or /api/v1 if inadvertently included
    if (raw.endsWith('/api/v1')) {
      raw = raw.substring(0, raw.length - 7);
    } else if (raw.endsWith('/api')) {
      raw = raw.substring(0, raw.length - 4);
    }

    // Add protocol if missing
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      if (raw.startsWith('10.0.2.2') ||
          raw.startsWith('localhost') ||
          raw.startsWith('127.0.0.1') ||
          raw.contains(':8080') ||
          raw.contains(':3000')) {
        raw = 'http://$raw';
      } else {
        // Standard production cloud IP or domain with SSL
        raw = 'https://$raw';
      }
    }

    return raw;
  }

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @visibleForTesting
  static void resetForTesting() {
    _prefs = null;
  }

  // Current Mode: 'student' or 'inspector'
  static Future<String> getAppMode() async {
    final prefs = await _instance;
    return prefs.getString(_keyAppMode) ?? 'student';
  }

  static Future<void> setAppMode(String mode) async {
    final prefs = await _instance;
    await prefs.setString(_keyAppMode, mode);
  }

  // Server Base URL
  static Future<String> getServerUrl() async {
    final prefs = await _instance;
    final saved = prefs.getString(_keyServerUrl);
    if (saved == null || saved.trim().isEmpty) {
      return defaultServerUrl;
    }
    // Compatibility auto-fix: if running on Web or non-Android platform but saved URL points to Android emulator 10.0.2.2
    if ((kIsWeb || defaultTargetPlatform != TargetPlatform.android) &&
        saved.contains('10.0.2.2')) {
      final normalized = saved.replaceAll('10.0.2.2', 'localhost');
      await prefs.setString(_keyServerUrl, normalized);
      return normalizeServerUrl(normalized);
    }
    return normalizeServerUrl(saved);
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await _instance;
    final normalized = normalizeServerUrl(url);
    await prefs.setString(_keyServerUrl, normalized);
  }

  static Future<void> resetServerUrl() async {
    final prefs = await _instance;
    await prefs.remove(_keyServerUrl);
  }

  // Auth Session
  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await _instance;
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, json.encode(user));
  }

  static Future<String?> getToken() async {
    final prefs = await _instance;
    return prefs.getString(_keyToken);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await _instance;
    final data = prefs.getString(_keyUser);
    if (data == null) return null;
    try {
      return json.decode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await _instance;
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyCachedCredential);
  }

  // App User & RBAC Role
  static Future<AppUser?> getCurrentUser() async {
    final userJson = await getUser();
    if (userJson == null) return null;
    return AppUser.fromJson(userJson);
  }

  /// Extracts the active RBAC role from the stored JWT token.
  /// Falls back to the cached user record if token decoding is unavailable.
  static Future<AppUserRole?> getRoleFromJwt() async {
    final token = await getToken();
    if (token != null) {
      final jwtRole = JwtDecoder.getRole(token);
      if (jwtRole != null) return jwtRole;
    }
    final user = await getCurrentUser();
    return user?.role;
  }

  static Future<AppUserRole> getCurrentRole() async {
    final jwtRole = await getRoleFromJwt();
    if (jwtRole != null) return jwtRole;
    final user = await getCurrentUser();
    if (user != null) return user.role;
    final mode = await getAppMode();
    if (mode == 'inspector') return AppUserRole.teacher;
    return AppUserRole.student;
  }

  // Guardian Linked Children Store
  static Future<void> deleteGuardianChild(String childId) async {
    final current = await getGuardianChildren();
    final updated = current.where((c) => c.id != childId).toList();
    await saveGuardianChildren(updated);
  }

  static Future<List<GuardianChild>> getGuardianChildren() async {
    final prefs = await _instance;
    final raw = prefs.getString(_keyGuardianChildren);
    if (raw != null) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        return list
            .map((e) => GuardianChild.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Default Seed for Children
    final defaultChildren = [
      GuardianChild(
        id: 'su.g5@edu.local',
        fullName: 'Ma Su Myat Noe (မစုမြတ်နိုး)',
        email: 'su.g5@edu.local',
        rollNo: '5A-01',
        gradeLevel: 'Grade 5-A',
        className: 'Grade 5-A (Primary)',
        schoolName: 'အခြေခံပညာကျောင်း',
        schoolCode: '',
        age: 10,
        nationalStudentId: 'MM-EDU-2026-88420',
        attendanceRatePct: 97.7,
        sessionsPresent: 43,
        sessionsAbsent: 1,
        termGradePoint: 'A+',
        examScores: {
          'myanmar': 88.0,
          'english': 82.0,
          'mathematics': 95.0,
          'general_science': 90.0,
        },
        calculatedBmi: 16.4,
        bmiCategory: 'Standard Healthy',
        dewormingCompleted: true,
        visionCheck: 'Normal 20/20',
        dominantEmotionalState: 'Joyful & Curious',
      ),
      GuardianChild(
        id: 'aung.kg@edu.local',
        fullName: 'Maung Aung Kaung Myat (မောင်အောင်ကောင်းမြတ်)',
        email: 'aung.kg@edu.local',
        rollNo: 'KG-01',
        gradeLevel: 'Kindergarten (KG)',
        className: 'KG-A (Pre-Primary)',
        schoolName: 'အခြေခံပညာကျောင်း',
        schoolCode: '',
        age: 5,
        nationalStudentId: 'MM-EDU-2026-88429',
        attendanceRatePct: 98.2,
        sessionsPresent: 44,
        sessionsAbsent: 0,
        termGradePoint: 'A',
        examScores: {'rhymes_drawing': 96.0, 'basic_numbers': 92.0},
        calculatedBmi: 15.5,
        bmiCategory: 'Standard Healthy',
        dewormingCompleted: true,
        visionCheck: 'Normal 20/20',
        dominantEmotionalState: 'Playful & Creative',
      ),
    ];

    await saveGuardianChildren(defaultChildren);
    return defaultChildren;
  }

  static Future<void> saveGuardianChildren(List<GuardianChild> children) async {
    final prefs = await _instance;
    final encoded = json.encode(
      children
          .map(
            (c) => {
              'id': c.id,
              'full_name': c.fullName,
              'email': c.email,
              'roll_no': c.rollNo,
              'grade_level': c.gradeLevel,
              'class_name': c.className,
              'school_name': c.schoolName,
              'school_code': c.schoolCode,
              'age': c.age,
              'national_student_id': c.nationalStudentId,
              'attendance_rate_pct': c.attendanceRatePct,
              'sessions_present': c.sessionsPresent,
              'sessions_absent': c.sessionsAbsent,
              'term_grade_point': c.termGradePoint,
              'exam_scores': c.examScores,
              'calculated_bmi': c.calculatedBmi,
              'bmi_category': c.bmiCategory,
              'deworming_completed': c.dewormingCompleted,
              'vision_check': c.visionCheck,
              'dominant_emotional_state': c.dominantEmotionalState,
              'did': c.did,
              'blockchain_address': c.blockchainAddress,
              'credential_hash': c.credentialHash,
              'anchor_status': c.anchorStatus,
              'raw_credential': c.rawCredential,
            },
          )
          .toList(),
    );
    await prefs.setString(_keyGuardianChildren, encoded);
  }

  static Future<int> getSelectedChildIndex() async {
    final prefs = await _instance;
    return prefs.getInt(_keySelectedChild) ?? 0;
  }

  static Future<void> setSelectedChildIndex(int index) async {
    final prefs = await _instance;
    await prefs.setInt(_keySelectedChild, index);
  }

  // Cached Verifiable Credential
  static Future<void> saveCachedCredential(
    Map<String, dynamic> credentialJson,
  ) async {
    final prefs = await _instance;
    await prefs.setString(_keyCachedCredential, json.encode(credentialJson));
  }

  static Future<Map<String, dynamic>?> getCachedCredential() async {
    final prefs = await _instance;
    final data = prefs.getString(_keyCachedCredential);
    if (data == null) return null;
    try {
      return json.decode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Inspector Gate Scan History
  static Future<void> addScanRecord(VerificationResult record) async {
    final prefs = await _instance;
    final existing = await getScanHistory();
    existing.insert(0, record);
    // Keep last 100 scans
    if (existing.length > 100) {
      existing.removeLast();
    }
    final encoded = json.encode(existing.map((e) => e.toJson()).toList());
    await prefs.setString(_keyScanHistory, encoded);
  }

  static Future<List<VerificationResult>> getScanHistory() async {
    final prefs = await _instance;
    final data = prefs.getString(_keyScanHistory);
    if (data == null) return [];
    try {
      final list = json.decode(data) as List<dynamic>;
      return list
          .map(
            (item) => VerificationResult(
              isValid: item['is_valid'] == true,
              signatureValid: item['signature_valid'] == true,
              isRevoked: item['is_revoked'] == true,
              isOffline: item['is_offline'] == true,
              did: item['did']?.toString() ?? '',
              studentName: item['student_name']?.toString() ?? '',
              studentRoll: item['student_roll']?.toString() ?? '',
              schoolName: item['school_name']?.toString() ?? '',
              schoolCode: item['school_code']?.toString() ?? '',
              township: item['township']?.toString() ?? '',
              region: item['region']?.toString() ?? '',
              academicYear: item['academic_year']?.toString() ?? '',
              credentialHash: item['credential_hash']?.toString() ?? '',
              merkleRoot: item['merkle_root']?.toString(),
              polygonTxHash: item['polygon_tx_hash']?.toString(),
              verificationTime:
                  DateTime.tryParse(
                    item['verification_time']?.toString() ?? '',
                  ) ??
                  DateTime.now(),
              message: item['message']?.toString() ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearScanHistory() async {
    final prefs = await _instance;
    await prefs.remove(_keyScanHistory);
  }

  // =========================================================
  // Classroom Entrance Offline Attendance & Whole-Child Store
  // =========================================================
  static const String _keyWholeChildRecords = 'whole_child_records_g5a';
  static const String _keyTodaySwipeTimestamps = 'today_swipe_timestamps';
  static const String _keyLastSyncTime = 'last_sync_timestamp';

  /// Check if a student swiped recently (e.g. within 15 minutes debounce window)
  static Future<bool> isDuplicateSwipe(
    String studentIdentifier, {
    int debounceMinutes = 15,
  }) async {
    final prefs = await _instance;
    final data = prefs.getString(_keyTodaySwipeTimestamps);
    if (data == null) return false;

    try {
      final map = json.decode(data) as Map<String, dynamic>;
      final lastSwipeStr = map[studentIdentifier]?.toString();
      if (lastSwipeStr == null) return false;

      final lastSwipe = DateTime.tryParse(lastSwipeStr);
      if (lastSwipe == null) return false;

      final diff = DateTime.now().difference(lastSwipe).inMinutes;
      return diff < debounceMinutes;
    } catch (_) {
      return false;
    }
  }

  /// Record an entrance swipe event with timestamp for debounce
  static Future<void> recordSwipeEvent(String studentIdentifier) async {
    final prefs = await _instance;
    final data = prefs.getString(_keyTodaySwipeTimestamps);
    Map<String, dynamic> map = {};
    if (data != null) {
      try {
        map = json.decode(data) as Map<String, dynamic>;
      } catch (_) {}
    }
    map[studentIdentifier] = DateTime.now().toIso8601String();
    await prefs.setString(_keyTodaySwipeTimestamps, json.encode(map));
  }

  /// Load Whole-Child records for class (Grade 5-A)
  static Future<List<WholeChildRecord>> getWholeChildRecords() async {
    final prefs = await _instance;
    final data = prefs.getString(_keyWholeChildRecords);
    if (data != null) {
      try {
        final list = json.decode(data) as List<dynamic>;
        return list
            .map(
              (e) => WholeChildRecord.fromLocalJson(e as Map<String, dynamic>),
            )
            .toList();
      } catch (_) {}
    }

    // Default Seed for Grade 5-A Class
    final defaultRecords = [
      WholeChildRecord(
        studentId: 'su.g5@edu.local',
        rollNo: '5A-01',
        nationalStudentId: 'MM-EDU-2026-88420',
        fullName: 'Ma Su Myat Noe (မစုမြတ်နိုး)',
        academicYear: '2026-2027',
        period: '2026-10',
        totalSessions: 44,
        sessionsPresent: 43,
        sessionsAbsent: 1,
        attendanceRatePct: 97.72,
        examScores: {
          'myanmar': 88.0,
          'english': 82.0,
          'mathematics': 95.0,
          'general_science': 90.0,
          'social_studies': 86.0,
        },
        termGradePoint: 'A+',
        competencies: [
          'Fractions & Decimals',
          'Reading Prose',
          'Conversational English',
        ],
        heightCm: 138.0,
        weightKg: 31.2,
        calculatedBmi: 16.4,
        bmiCategory: 'Standard Healthy',
        preferredSports: ['Badminton', 'Traditional Dance'],
        visionCheck: 'Normal 20/20',
        hearingCheck: 'Normal',
        dewormingCompleted: true,
        knownAllergies: [],
        dominantEmotionalState: 'Joyful & Curious',
        engagementIndex: 4.9,
        teacherNotes:
            'Class monitor, punctual and helpful with peer reading circle',
        leadershipRole: 'Class Monitor (Primary)',
        clubName: 'School Reading Circle',
        citizenshipBadges: ['Punctuality Star', 'Peer Supporter Badge'],
        syncStatus: 'pending',
        updatedAt: DateTime.now(),
      ),
      WholeChildRecord(
        studentId: 'kyaw.g5@intaing.edu.local',
        rollNo: '5A-02',
        nationalStudentId: 'MM-EDU-2026-88421',
        fullName: 'Maung Kyaw Kyaw (မောင်ကျော်ကျော်)',
        academicYear: '2026-2027',
        period: '2026-10',
        totalSessions: 44,
        sessionsPresent: 42,
        sessionsAbsent: 2,
        attendanceRatePct: 95.45,
        examScores: {
          'myanmar': 84.0,
          'english': 76.0,
          'mathematics': 92.5,
          'general_science': 88.0,
          'social_studies': 82.0,
        },
        termGradePoint: 'A',
        competencies: ['Fractions & Decimals', 'Reading Prose'],
        heightCm: 136.5,
        weightKg: 29.8,
        calculatedBmi: 16.0,
        bmiCategory: 'Standard Healthy',
        preferredSports: ['Football', 'Chinlon (ခြင်းလုံး)'],
        visionCheck: 'Normal 20/20',
        hearingCheck: 'Normal',
        dewormingCompleted: true,
        knownAllergies: ['peanut'],
        dominantEmotionalState: 'Enthusiastic',
        engagementIndex: 4.8,
        teacherNotes:
            'Active class participation, leads Row 2 morning desk setup',
        leadershipRole: 'Table Group Leader (Row 2)',
        clubName: 'Junior Red Cross (ကြက်ခြေနီ)',
        citizenshipBadges: ['Helpful Classmate', 'Green Campus Gardener'],
        syncStatus: 'pending',
        updatedAt: DateTime.now(),
      ),
    ];

    await saveWholeChildRecords(defaultRecords);
    return defaultRecords;
  }

  /// Save Whole-Child records to local offline storage
  static Future<void> saveWholeChildRecords(
    List<WholeChildRecord> records,
  ) async {
    final prefs = await _instance;
    final encoded = json.encode(records.map((e) => e.toLocalJson()).toList());
    await prefs.setString(_keyWholeChildRecords, encoded);
  }

  /// Register an automated entrance swipe for a student
  static Future<WholeChildRecord?> registerEntranceSwipe(
    String identifierOrName,
  ) async {
    final records = await getWholeChildRecords();
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      if (r.studentId.toLowerCase() == identifierOrName.toLowerCase() ||
          r.fullName.toLowerCase().contains(identifierOrName.toLowerCase()) ||
          identifierOrName.toLowerCase().contains(r.rollNo.toLowerCase())) {
        // Register debounce
        await recordSwipeEvent(r.studentId);

        // Increment attendance
        final updatedPresent = r.sessionsPresent + 1;
        final newRate = ((updatedPresent / r.totalSessions) * 100).clamp(
          0.0,
          100.0,
        );

        final updated = WholeChildRecord(
          studentId: r.studentId,
          rollNo: r.rollNo,
          nationalStudentId: r.nationalStudentId,
          fullName: r.fullName,
          academicYear: r.academicYear,
          period: r.period,
          totalSessions: r.totalSessions,
          sessionsPresent: updatedPresent,
          sessionsAbsent: r.sessionsAbsent,
          attendanceRatePct: double.parse(newRate.toStringAsFixed(2)),
          examScores: r.examScores,
          termGradePoint: r.termGradePoint,
          competencies: r.competencies,
          heightCm: r.heightCm,
          weightKg: r.weightKg,
          calculatedBmi: r.calculatedBmi,
          bmiCategory: r.bmiCategory,
          preferredSports: r.preferredSports,
          visionCheck: r.visionCheck,
          hearingCheck: r.hearingCheck,
          dewormingCompleted: r.dewormingCompleted,
          knownAllergies: r.knownAllergies,
          dominantEmotionalState: r.dominantEmotionalState,
          engagementIndex: r.engagementIndex,
          teacherNotes: r.teacherNotes,
          leadershipRole: r.leadershipRole,
          clubName: r.clubName,
          citizenshipBadges: r.citizenshipBadges,
          syncStatus: 'pending',
          updatedAt: DateTime.now(),
        );

        records[i] = updated;
        await saveWholeChildRecords(records);
        return updated;
      }
    }
    return null;
  }

  /// Last sync timestamp
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await _instance;
    final str = prefs.getString(_keyLastSyncTime);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  static Future<void> setLastSyncTime(DateTime time) async {
    final prefs = await _instance;
    await prefs.setString(_keyLastSyncTime, time.toIso8601String());
  }
}
