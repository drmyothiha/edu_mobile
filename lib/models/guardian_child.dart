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
  });

  bool get isUnder13 => age < 13;

  factory GuardianChild.fromJson(Map<String, dynamic> json) {
    return GuardianChild(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      rollNo: json['roll_no']?.toString() ?? '',
      gradeLevel: json['grade_level']?.toString() ?? 'Grade 5',
      className: json['class_name']?.toString() ?? '',
      schoolName: json['school_name']?.toString() ?? 'Basic Education High School',
      schoolCode: json['school_code']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt() ?? 10,
      nationalStudentId: json['national_student_id']?.toString(),
      attendanceRatePct: (json['attendance_rate_pct'] as num?)?.toDouble() ?? 96.0,
      sessionsPresent: (json['sessions_present'] as num?)?.toInt() ?? 42,
      sessionsAbsent: (json['sessions_absent'] as num?)?.toInt() ?? 2,
      termGradePoint: json['term_grade_point']?.toString() ?? 'A',
      examScores: (json['exam_scores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      calculatedBmi: (json['calculated_bmi'] as num?)?.toDouble() ?? 16.2,
      bmiCategory: json['bmi_category']?.toString() ?? 'Standard Healthy',
      dewormingCompleted: json['deworming_completed'] == true,
      visionCheck: json['vision_check']?.toString() ?? 'Normal 20/20',
      dominantEmotionalState: json['dominant_emotional_state']?.toString() ?? 'Active & Engaged',
      did: json['did']?.toString(),
      blockchainAddress: json['blockchain_address']?.toString(),
      credentialHash: json['credential_hash']?.toString(),
      anchorStatus: json['anchor_status']?.toString(),
      rawCredential: json['raw_credential'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toVcJson() {
    return {
      "student_id": id,
      "student_name": fullName,
      "student_email": email,
      "did": did ?? "did:edu:mm:013:MMR013035-STU-$rollNo",
      "blockchain_address": blockchainAddress ?? "0x217ff15fe5d8cee90f957185c8dd580f57347d20",
      "credential_hash": credentialHash ?? "0xae5becb56ee81d0284cb147d654636ad074b76d13d750c75cc515ebd701a5ab4",
      "merkle_root": "0xae5becb56ee81d0284cb147d654636ad074b76d13d750c75cc515ebd701a5ab4",
      "polygon_tx_hash": "0xecf2696e698380a9a6c05030be5a23d4b6c9a9578895d5b3d64e10b675db699b",
      "anchor_status": anchorStatus ?? "anchored",
      "issuer_school": schoolName,
      "school_code": schoolCode,
      "region": "Yangon Region",
      "township": "Hlegu",
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
          "id": did ?? "did:edu:mm:013:MMR013035-STU-$rollNo",
          "student_name": fullName,
          "grade_level": gradeLevel,
          "school_name": schoolName,
          "school_code": schoolCode,
          "age": age,
          "under_13_guardian_supervised": isUnder13,
        },
      }
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'rollNo': rollNo,
      'gradeLevel': gradeLevel,
      'className': className,
      'schoolName': schoolName,
      'schoolCode': schoolCode,
      'age': age,
      'nationalStudentId': nationalStudentId,
      'attendanceRatePct': attendanceRatePct,
      'sessionsPresent': sessionsPresent,
      'sessionsAbsent': sessionsAbsent,
      'termGradePoint': termGradePoint,
      'examScores': examScores,
      'calculatedBmi': calculatedBmi,
      'bmiCategory': bmiCategory,
      'dewormingCompleted': dewormingCompleted,
      'visionCheck': visionCheck,
      'dominantEmotionalState': dominantEmotionalState,
      'did': did,
      'blockchainAddress': blockchainAddress,
      'credentialHash': credentialHash,
      'anchorStatus': anchorStatus,
      'rawCredential': rawCredential,
    };
  }
}
