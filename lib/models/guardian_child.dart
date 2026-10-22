class GuardianChild {
  final String id;
  final String fullName;
  final String email;
  final String rollNo;
  final String gradeLevel;
  final String className;
  final String schoolName;
  final String schoolCode;
  final int age;
  final String? nationalStudentId;
  final double attendanceRatePct;
  final int sessionsPresent;
  final int sessionsAbsent;
  final String termGradePoint;
  final Map<String, double> examScores;
  final double calculatedBmi;
  final String bmiCategory;
  final bool dewormingCompleted;
  final String visionCheck;
  final String dominantEmotionalState;
  final String? did;
  final String? blockchainAddress;
  final String? credentialHash;
  final String? anchorStatus;
  final Map<String, dynamic>? rawCredential;
  final String? photoUrl;

  GuardianChild({
    required this.id,
    required this.fullName,
    required this.email,
    required this.rollNo,
    required this.gradeLevel,
    required this.className,
    required this.schoolName,
    required this.schoolCode,
    required this.age,
    this.nationalStudentId,
    this.attendanceRatePct = 95.0,
    this.sessionsPresent = 42,
    this.sessionsAbsent = 2,
    this.termGradePoint = 'A',
    this.examScores = const {},
    this.calculatedBmi = 16.2,
    this.bmiCategory = 'Standard Healthy',
    this.dewormingCompleted = true,
    this.visionCheck = 'Normal 20/20',
    this.dominantEmotionalState = 'Active & Engaged',
    this.did,
    this.blockchainAddress,
    this.credentialHash,
    this.anchorStatus,
    this.rawCredential,
    this.photoUrl,
  });

  bool get isUnder13 => age < 13;

  factory GuardianChild.fromJson(Map<String, dynamic> json) {
    return GuardianChild(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      rollNo: json['roll_no']?.toString() ?? json['roll_number']?.toString() ?? json['rollNo']?.toString() ?? '',
      gradeLevel: json['grade_level']?.toString() ?? json['gradeLevel']?.toString() ?? 'Grade 5',
      className: json['class_name']?.toString() ?? json['className']?.toString() ?? '',
      schoolName: json['school_name']?.toString() ?? json['schoolName']?.toString() ?? 'Basic Education High School',
      schoolCode: json['school_code']?.toString() ?? json['schoolCode']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt() ?? 10,
      nationalStudentId: json['national_student_id']?.toString() ?? json['nationalStudentId']?.toString(),
      attendanceRatePct: (json['attendance_rate_pct'] ?? json['attendanceRatePct'] as num?)?.toDouble() ?? 96.0,
      sessionsPresent: (json['sessions_present'] ?? json['sessionsPresent'] as num?)?.toInt() ?? 42,
      sessionsAbsent: (json['sessions_absent'] ?? json['sessionsAbsent'] as num?)?.toInt() ?? 2,
      termGradePoint: json['term_grade_point']?.toString() ?? json['termGradePoint']?.toString() ?? 'A',
      examScores: ((json['exam_scores'] ?? json['examScores']) as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      calculatedBmi: (json['calculated_bmi'] ?? json['calculatedBmi'] as num?)?.toDouble() ?? 16.2,
      bmiCategory: json['bmi_category']?.toString() ?? json['bmiCategory']?.toString() ?? 'Standard Healthy',
      dewormingCompleted: (json['deworming_completed'] ?? json['dewormingCompleted']) == true,
      visionCheck: json['vision_check']?.toString() ?? json['visionCheck']?.toString() ?? 'Normal 20/20',
      dominantEmotionalState: json['dominant_emotional_state']?.toString() ?? json['dominantEmotionalState']?.toString() ?? 'Active & Engaged',
      did: json['did']?.toString(),
      blockchainAddress: json['blockchain_address']?.toString() ?? json['blockchainAddress']?.toString(),
      credentialHash: json['credential_hash']?.toString() ?? json['credentialHash']?.toString(),
      anchorStatus: json['anchor_status']?.toString() ?? json['anchorStatus']?.toString(),
      rawCredential: (json['raw_credential'] ?? json['rawCredential']) as Map<String, dynamic>?,
      photoUrl: json['photo_url']?.toString() ?? json['photoUrl']?.toString() ?? json['avatar']?.toString(),
    );
  }

  Map<String, dynamic> toVcJson() {
    return {
      "student_id": id,
      "student_name": fullName,
      "student_email": email,
      "did": did ?? "did:edu:mm:013:${schoolCode.isNotEmpty ? schoolCode : 'SCH'}-STU-$rollNo",
      "blockchain_address": blockchainAddress ?? "0x217ff15fe5d8cee90f957185c8dd580f57347d20",
      "credential_hash": credentialHash ?? "0xae5becb56ee81d0284cb147d654636ad074b76d13d750c75cc515ebd701a5ab4",
      "merkle_root": "0xae5becb56ee81d0284cb147d654636ad074b76d13d750c75cc515ebd701a5ab4",
      "polygon_tx_hash": "0xecf2696e698380a9a6c05030be5a23d4b6c9a9578895d5b3d64e10b675db699b",
      "anchor_status": anchorStatus ?? "anchored",
      "issuer_school": schoolName,
      "school_code": schoolCode,
      "region": "",
      "township": "",
      "photo_url": photoUrl,
      "raw_credential_json": {
        "@context": [
          "https://www.w3.org/ns/credentials/v2",
          "https://schema.edu.gov.mm/credentials/v2"
        ],
        "id": "urn:uuid:$id",
        "type": ["VerifiableCredential", "StudentIdentityCredential"],
        "issuer": "did:edu:school:$schoolCode",
        "validFrom": "2026-09-24T00:00:00Z",
        "credentialSubject": {
          "academic_year": "2026-2027",
          "id": did ?? "did:edu:mm:013:${schoolCode.isNotEmpty ? schoolCode : 'SCH'}-STU-$rollNo",
          "student_name": fullName,
          "grade_level": gradeLevel,
          "school_name": schoolName,
          "school_code": schoolCode,
          "age": age,
          "under_13_guardian_supervised": isUnder13,
          "photo_url": photoUrl,
        },
      }
    };
  }

  GuardianChild copyWith({
    String? id,
    String? fullName,
    String? email,
    String? rollNo,
    String? gradeLevel,
    String? className,
    String? schoolName,
    String? schoolCode,
    int? age,
    String? nationalStudentId,
    double? attendanceRatePct,
    int? sessionsPresent,
    int? sessionsAbsent,
    String? termGradePoint,
    Map<String, double>? examScores,
    double? calculatedBmi,
    String? bmiCategory,
    bool? dewormingCompleted,
    String? visionCheck,
    String? dominantEmotionalState,
    String? did,
    String? blockchainAddress,
    String? credentialHash,
    String? anchorStatus,
    Map<String, dynamic>? rawCredential,
    String? photoUrl,
  }) {
    return GuardianChild(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      rollNo: rollNo ?? this.rollNo,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      className: className ?? this.className,
      schoolName: schoolName ?? this.schoolName,
      schoolCode: schoolCode ?? this.schoolCode,
      age: age ?? this.age,
      nationalStudentId: nationalStudentId ?? this.nationalStudentId,
      attendanceRatePct: attendanceRatePct ?? this.attendanceRatePct,
      sessionsPresent: sessionsPresent ?? this.sessionsPresent,
      sessionsAbsent: sessionsAbsent ?? this.sessionsAbsent,
      termGradePoint: termGradePoint ?? this.termGradePoint,
      examScores: examScores ?? this.examScores,
      calculatedBmi: calculatedBmi ?? this.calculatedBmi,
      bmiCategory: bmiCategory ?? this.bmiCategory,
      dewormingCompleted: dewormingCompleted ?? this.dewormingCompleted,
      visionCheck: visionCheck ?? this.visionCheck,
      dominantEmotionalState: dominantEmotionalState ?? this.dominantEmotionalState,
      did: did ?? this.did,
      blockchainAddress: blockchainAddress ?? this.blockchainAddress,
      credentialHash: credentialHash ?? this.credentialHash,
      anchorStatus: anchorStatus ?? this.anchorStatus,
      rawCredential: rawCredential ?? this.rawCredential,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'fullName': fullName,
      'email': email,
      'roll_no': rollNo,
      'rollNo': rollNo,
      'grade_level': gradeLevel,
      'gradeLevel': gradeLevel,
      'class_name': className,
      'className': className,
      'school_name': schoolName,
      'schoolName': schoolName,
      'school_code': schoolCode,
      'schoolCode': schoolCode,
      'age': age,
      'national_student_id': nationalStudentId,
      'nationalStudentId': nationalStudentId,
      'attendance_rate_pct': attendanceRatePct,
      'attendanceRatePct': attendanceRatePct,
      'sessions_present': sessionsPresent,
      'sessionsPresent': sessionsPresent,
      'sessions_absent': sessionsAbsent,
      'sessionsAbsent': sessionsAbsent,
      'term_grade_point': termGradePoint,
      'termGradePoint': termGradePoint,
      'exam_scores': examScores,
      'examScores': examScores,
      'calculated_bmi': calculatedBmi,
      'calculatedBmi': calculatedBmi,
      'bmi_category': bmiCategory,
      'bmiCategory': bmiCategory,
      'deworming_completed': dewormingCompleted,
      'dewormingCompleted': dewormingCompleted,
      'vision_check': visionCheck,
      'visionCheck': visionCheck,
      'dominant_emotional_state': dominantEmotionalState,
      'dominantEmotionalState': dominantEmotionalState,
      'did': did,
      'blockchain_address': blockchainAddress,
      'blockchainAddress': blockchainAddress,
      'credential_hash': credentialHash,
      'credentialHash': credentialHash,
      'anchor_status': anchorStatus,
      'anchorStatus': anchorStatus,
      'raw_credential': rawCredential,
      'rawCredential': rawCredential,
      'photo_url': photoUrl,
      'photoUrl': photoUrl,
    };
  }
}
