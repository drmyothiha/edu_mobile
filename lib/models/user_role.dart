enum AppUserRole {
  teacher,
  guardian,
  student,
  admin,
}

extension AppUserRoleExtension on AppUserRole {
  String get name {
    switch (this) {
      case AppUserRole.teacher:
        return 'teacher';
      case AppUserRole.guardian:
        return 'guardian';
      case AppUserRole.student:
        return 'student';
      case AppUserRole.admin:
        return 'admin';
    }
  }

  String get labelEn {
    switch (this) {
      case AppUserRole.teacher:
        return 'Teacher';
      case AppUserRole.guardian:
        return 'Guardian';
      case AppUserRole.student:
        return 'Student';
      case AppUserRole.admin:
        return 'School Admin';
    }
  }

  String get labelMy {
    switch (this) {
      case AppUserRole.teacher:
        return 'ဆရာ/ဆရာမ';
      case AppUserRole.guardian:
        return 'မိဘ / အုပ်ထိန်းသူ';
      case AppUserRole.student:
        return 'ကျောင်းသား/သူ';
      case AppUserRole.admin:
        return 'ကျောင်းအုပ် / စီမံခန့်ခွဲသူ';
    }
  }

  static AppUserRole fromString(String? role) {
    final clean = (role ?? '').trim().toLowerCase();
    if (clean == 'admin' || clean == 'school_admin' || clean == 'sysadmin') return AppUserRole.admin;
    if (clean == 'teacher') return AppUserRole.teacher;
    if (clean == 'guardian' || clean == 'parent') return AppUserRole.guardian;
    if (clean == 'student') return AppUserRole.student;
    // Default fallback to student
    return AppUserRole.student;
  }
}

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final AppUserRole role;
  final String? schoolId;
  final String? schoolName;
  final String? gradeLevel;
  final DateTime? dateOfBirth;
  final String? guardianName;
  final String? guardianEmail;
  final String? photoUrl;
  final String? avatarUrl;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.schoolId,
    this.schoolName,
    this.gradeLevel,
    this.dateOfBirth,
    this.guardianName,
    this.guardianEmail,
    this.photoUrl,
    this.avatarUrl,
  });

  /// Calculate user's age in completed years if dateOfBirth is known
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  /// Evaluates COPPA / Child Safety threshold:
  /// True if the student is strictly under 13 years of age.
  bool get isUnder13 {
    if (role != AppUserRole.student) return false;
    
    // Explicit age check
    if (age != null) {
      return age! < 13;
    }

    // Grade-level heuristic fallback when date of birth is not populated:
    // KG through Grade 6 are students ages 5 to 12.
    // Grade 7 and above are typically ages 13+.
    if (gradeLevel != null) {
      final g = gradeLevel!.toLowerCase().trim();
      if (g == 'kg' ||
          g.contains('grade 1') ||
          g.contains('grade 2') ||
          g.contains('grade 3') ||
          g.contains('grade 4') ||
          g.contains('grade 5') ||
          g.contains('grade 6') ||
          g.contains('primary')) {
        return true;
      }
      if (g.contains('grade 7') ||
          g.contains('grade 8') ||
          g.contains('grade 9') ||
          g.contains('grade 10') ||
          g.contains('grade 11') ||
          g.contains('grade 12') ||
          g.contains('high school')) {
        return false;
      }
    }

    // Default: Check email patterns for demo accounts
    if (email.contains('g5') || email.contains('kg') || email.contains('primary')) {
      return true;
    }

    return false;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    DateTime? dob;
    if (json['date_of_birth'] != null) {
      dob = DateTime.tryParse(json['date_of_birth'].toString());
    }

    return AppUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: AppUserRoleExtension.fromString(json['role']?.toString()),
      schoolId: json['school_id']?.toString(),
      schoolName: json['school_name']?.toString(),
      gradeLevel: json['grade_level']?.toString(),
      dateOfBirth: dob,
      guardianName: json['guardian_name']?.toString(),
      guardianEmail: json['guardian_email']?.toString(),
      photoUrl: json['photo_url']?.toString() ?? json['photoUrl']?.toString() ?? json['avatar_url']?.toString(),
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString() ?? json['photo_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      if (schoolId != null) 'school_id': schoolId,
      if (schoolName != null) 'school_name': schoolName,
      if (gradeLevel != null) 'grade_level': gradeLevel,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth!.toIso8601String(),
      if (guardianName != null) 'guardian_name': guardianName,
      if (guardianEmail != null) 'guardian_email': guardianEmail,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}
