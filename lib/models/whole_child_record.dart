/// Represents a student's record adhering to the Whole-Child Development Framework (9.1 - 9.5)
class WholeChildRecord {
  final String studentId;
  final String rollNo;
  final String nationalStudentId;
  final String fullName;
  final String academicYear;
  final String period; // e.g. "2026-10"

  // 9.1 Academic Profile
  final int totalSessions;
  final int sessionsPresent;
  final int sessionsAbsent;
  final double attendanceRatePct;
  final Map<String, double> examScores;
  final String termGradePoint;
  final List<String> competencies;

  // 9.2 Physical Growth Profile
  final double heightCm;
  final double weightKg;
  final double calculatedBmi;
  final String bmiCategory;
  final List<String> preferredSports;

  // 9.3 Health Visibility Profile (Off-chain sensitive)
  final String visionCheck;
  final String hearingCheck;
  final bool dewormingCompleted;
  final List<String> knownAllergies;

  // 9.4 Wellbeing Profile
  final String dominantEmotionalState;
  final double engagementIndex; // 1.0 - 5.0
  final String teacherNotes;

  // 9.5 Social Participation & Citizenship Profile (Positive Non-Punitive)
  final String leadershipRole;
  final String clubName;
  final List<String> citizenshipBadges;

  // Sync state
  final String syncStatus; // 'pending' | 'synced'
  final DateTime updatedAt;

  WholeChildRecord({
    required this.studentId,
    required this.rollNo,
    required this.nationalStudentId,
    required this.fullName,
    required this.academicYear,
    required this.period,
    required this.totalSessions,
    required this.sessionsPresent,
    required this.sessionsAbsent,
    required this.attendanceRatePct,
    required this.examScores,
    required this.termGradePoint,
    required this.competencies,
    required this.heightCm,
    required this.weightKg,
    required this.calculatedBmi,
    required this.bmiCategory,
    required this.preferredSports,
    required this.visionCheck,
    required this.hearingCheck,
    required this.dewormingCompleted,
    required this.knownAllergies,
    required this.dominantEmotionalState,
    required this.engagementIndex,
    required this.teacherNotes,
    required this.leadershipRole,
    required this.clubName,
    required this.citizenshipBadges,
    this.syncStatus = 'pending',
    required this.updatedAt,
  });

  Map<String, dynamic> toSyncJson() {
    return {
      'student_id': studentId,
      'roll_no': rollNo,
      'national_student_id': nationalStudentId,
      'full_name': fullName,
      'academic_profile': {
        'attendance': {
          'total_possible_sessions': totalSessions,
          'sessions_present': sessionsPresent,
          'sessions_absent': sessionsAbsent,
          'attendance_rate_pct': attendanceRatePct,
          'swipe_device_integrity': 'verified_offline_kiosk',
        },
        'assignment_completion': {
          'assigned_count': 8,
          'submitted_count': 8,
          'completion_rate_pct': 100.0,
        },
        'assessments': {
          'monthly_exam': examScores,
          'term_grade_point': termGradePoint,
        },
        'competency_mastery': competencies
            .map((c) => {'domain': c, 'status': 'mastered'})
            .toList(),
      },
      'physical_growth_profile': {
        'measurements': {
          'height_cm': heightCm,
          'weight_kg': weightKg,
          'calculated_bmi': calculatedBmi,
          'growth_percentile_category': bmiCategory,
        },
        'physical_fitness_activity': {
          'pe_class_participation': 'consistent',
          'preferred_sports': preferredSports,
        },
      },
      'health_visibility_profile': {
        'confidentiality_level': 'school_internal_restricted',
        'routine_screenings': {
          'vision_check': visionCheck,
          'hearing_check': hearingCheck,
        },
        'recurring_conditions_and_alerts': {
          'has_chronic_condition': false,
          'known_allergies': knownAllergies,
        },
        'national_campaign_markers': {
          'annual_deworming_completed': dewormingCompleted,
          'deworming_date': '2026-07-20',
        },
      },
      'wellbeing_profile': {
        'monthly_checkin_summary': {
          'dominant_emotional_state': dominantEmotionalState,
          'classroom_engagement_index': engagementIndex,
        },
        'teacher_observations': {
          'notes': teacherNotes,
        },
      },
      'social_citizenship_profile': {
        'leadership_and_roles': [
          {'role': leadershipRole, 'tenure': 'Term 1'}
        ],
        'clubs_and_extracurriculars': [
          {'club_name': clubName, 'standing': 'active_member'}
        ],
        'teamwork_and_peer_conduct': {
          'collaboration_rating': 5,
          'citizenship_badges_awarded': citizenshipBadges,
        },
      },
    };
  }

  factory WholeChildRecord.fromLocalJson(Map<String, dynamic> json) {
    return WholeChildRecord(
      studentId: json['student_id']?.toString() ?? '',
      rollNo: json['roll_no']?.toString() ?? '',
      nationalStudentId: json['national_student_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      academicYear: json['academic_year']?.toString() ?? '2026-2027',
      period: json['period']?.toString() ?? '2026-10',
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 44,
      sessionsPresent: (json['sessions_present'] as num?)?.toInt() ?? 42,
      sessionsAbsent: (json['sessions_absent'] as num?)?.toInt() ?? 2,
      attendanceRatePct: (json['attendance_rate_pct'] as num?)?.toDouble() ?? 95.45,
      examScores: (json['exam_scores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      termGradePoint: json['term_grade_point']?.toString() ?? 'A',
      competencies: (json['competencies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 136.5,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 30.0,
      calculatedBmi: (json['calculated_bmi'] as num?)?.toDouble() ?? 16.0,
      bmiCategory: json['bmi_category']?.toString() ?? 'Standard Healthy',
      preferredSports: (json['preferred_sports'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Football', 'Chinlon'],
      visionCheck: json['vision_check']?.toString() ?? 'Normal 20/20',
      hearingCheck: json['hearing_check']?.toString() ?? 'Normal',
      dewormingCompleted: json['deworming_completed'] == true,
      knownAllergies: (json['known_allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dominantEmotionalState:
          json['dominant_emotional_state']?.toString() ?? 'Content',
      engagementIndex:
          (json['engagement_index'] as num?)?.toDouble() ?? 4.8,
      teacherNotes: json['teacher_notes']?.toString() ?? '',
      leadershipRole: json['leadership_role']?.toString() ?? 'Table Leader',
      clubName: json['club_name']?.toString() ?? 'Junior Red Cross',
      citizenshipBadges: (json['citizenship_badges'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Helpful Classmate'],
      syncStatus: json['sync_status']?.toString() ?? 'pending',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'student_id': studentId,
      'roll_no': rollNo,
      'national_student_id': nationalStudentId,
      'full_name': fullName,
      'academic_year': academicYear,
      'period': period,
      'total_sessions': totalSessions,
      'sessions_present': sessionsPresent,
      'sessions_absent': sessionsAbsent,
      'attendance_rate_pct': attendanceRatePct,
      'exam_scores': examScores,
      'term_grade_point': termGradePoint,
      'competencies': competencies,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'calculated_bmi': calculatedBmi,
      'bmi_category': bmiCategory,
      'preferred_sports': preferredSports,
      'vision_check': visionCheck,
      'hearing_check': hearingCheck,
      'deworming_completed': dewormingCompleted,
      'known_allergies': knownAllergies,
      'dominant_emotional_state': dominantEmotionalState,
      'engagement_index': engagementIndex,
      'teacher_notes': teacherNotes,
      'leadership_role': leadershipRole,
      'club_name': clubName,
      'citizenship_badges': citizenshipBadges,
      'sync_status': syncStatus,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
