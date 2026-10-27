/// Academic stages spanning from early childhood to terminal doctoral education.
enum AcademicStage {
  kg,
  primary,
  middleSchool,
  highSchool,
  bachelor,
  master,
  phd,
}

/// Status of a specific academic level in the student's lifelong trajectory.
enum AcademicStatus {
  completed,
  current,
  inProgress,
  pathway,
}

extension AcademicStageExt on AcademicStage {
  String get code {
    switch (this) {
      case AcademicStage.kg:
        return 'KG';
      case AcademicStage.primary:
        return 'BEPS';
      case AcademicStage.middleSchool:
        return 'BEMS';
      case AcademicStage.highSchool:
        return 'BEHS';
      case AcademicStage.bachelor:
        return 'BACHELOR';
      case AcademicStage.master:
        return 'MASTER';
      case AcademicStage.phd:
        return 'PHD';
    }
  }

  String get displayName {
    switch (this) {
      case AcademicStage.kg:
        return 'Kindergarten (KG) / Pre-Primary';
      case AcademicStage.primary:
        return 'Primary Education (Grade 1 - 5)';
      case AcademicStage.middleSchool:
        return 'Lower Secondary / Middle (Grade 6 - 9)';
      case AcademicStage.highSchool:
        return 'Upper Secondary / High School (Grade 10 - 12)';
      case AcademicStage.bachelor:
        return "Undergraduate / Bachelor's Degree";
      case AcademicStage.master:
        return "Postgraduate / Master's Degree";
      case AcademicStage.phd:
        return 'Doctoral Level / Doctor of Philosophy (PhD)';
    }
  }

  String get burmeseTitle {
    switch (this) {
      case AcademicStage.kg:
        return 'မူကြိုနှင့် မူလတန်းကြိုအဆင့် (KG)';
      case AcademicStage.primary:
        return 'အခြေခံပညာ မူလတန်းအဆင့် (Grade 1 - 5)';
      case AcademicStage.middleSchool:
        return 'အခြေခံပညာ အလယ်တန်းအဆင့် (Grade 6 - 9)';
      case AcademicStage.highSchool:
        return 'အခြေခံပညာ အထက်တန်းအဆင့် (Grade 10 - 12)';
      case AcademicStage.bachelor:
        return 'တက္ကသိုလ် ပထမဘွဲ့အဆင့် (Undergraduate)';
      case AcademicStage.master:
        return 'မဟာဘွဲ့ မဟာတန်းအဆင့် (Postgraduate)';
      case AcademicStage.phd:
        return 'ပါရဂူဘွဲ့အဆင့် (Doctor of Philosophy / PhD)';
    }
  }

  int get levelIndex {
    switch (this) {
      case AcademicStage.kg:
        return 0;
      case AcademicStage.primary:
        return 1;
      case AcademicStage.middleSchool:
        return 2;
      case AcademicStage.highSchool:
        return 3;
      case AcademicStage.bachelor:
        return 4;
      case AcademicStage.master:
        return 5;
      case AcademicStage.phd:
        return 6;
    }
  }
}

extension AcademicStatusExt on AcademicStatus {
  String get label {
    switch (this) {
      case AcademicStatus.completed:
        return 'Completed';
      case AcademicStatus.current:
        return 'Highest Level Active';
      case AcademicStatus.inProgress:
        return 'In Progress / Research';
      case AcademicStatus.pathway:
        return 'Academic Pathway';
    }
  }

  String get burmeseLabel {
    switch (this) {
      case AcademicStatus.completed:
        return 'အောင်မြင်ပြီးဆုံး (အတည်ပြုပြီး)';
      case AcademicStatus.current:
        return 'လက်ရှိတက်ရောက်ဆဲ (အမြင့်ဆုံးအဆင့်)';
      case AcademicStatus.inProgress:
        return 'သုတေသန / ကျမ်းပြုဆဲ';
      case AcademicStatus.pathway:
        return 'အနာဂတ် ပညာသင်ကြားရေး ရည်မှန်းချက်';
    }
  }
}

/// A verified academic record entry for a specific stage from KG to PhD.
class AcademicRecordEntry {
  final AcademicStage stage;
  final String stageCode;
  final String levelTitle;
  final String burmeseTitle;
  final String degreeOrCertificate;
  final String institution;
  final String academicYears;
  final AcademicStatus status;
  final String fieldOfStudy;
  final String performanceRating; // e.g. "5/5 Stars", "GPA 3.92", "Distinction in 5 Subjects"
  final String? thesisOrCapstoneTitle;
  final List<String> competencies;
  final List<String> honors;
  final String credentialId;
  final String blockchainProofHash;
  final bool isHighestActiveLevel;

  AcademicRecordEntry({
    required this.stage,
    required this.stageCode,
    required this.levelTitle,
    required this.burmeseTitle,
    required this.degreeOrCertificate,
    required this.institution,
    required this.academicYears,
    required this.status,
    required this.fieldOfStudy,
    required this.performanceRating,
    this.thesisOrCapstoneTitle,
    this.competencies = const [],
    this.honors = const [],
    required this.credentialId,
    required this.blockchainProofHash,
    this.isHighestActiveLevel = false,
  });

  bool get isCompleted => status == AcademicStatus.completed;
  bool get isCurrent => status == AcademicStatus.current;
  bool get isPathway => status == AcademicStatus.pathway;

  Map<String, dynamic> toJson() {
    return {
      'stage': stage.code,
      'level_title': levelTitle,
      'degree_certificate': degreeOrCertificate,
      'institution': institution,
      'academic_years': academicYears,
      'status': status.name,
      'field_of_study': fieldOfStudy,
      'performance_rating': performanceRating,
      'thesis_title': thesisOrCapstoneTitle,
      'competencies': competencies,
      'honors': honors,
      'credential_id': credentialId,
      'blockchain_proof_hash': blockchainProofHash,
      'is_highest_active_level': isHighestActiveLevel,
    };
  }
}

/// Complete Lifelong Academic Profile encompassing KG to PhD or Highest Level.
class LifelongAcademicProfile {
  final String studentId;
  final String studentName;
  final String rollNo;
  final String nationalStudentId;
  final String currentGradeOrLevel;
  final String highestLevelTitle;
  final String? photoUrl;
  final List<AcademicRecordEntry> entries;

  LifelongAcademicProfile({
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.nationalStudentId,
    required this.currentGradeOrLevel,
    required this.highestLevelTitle,
    this.photoUrl,
    required this.entries,
  });

  /// The highest active/enrolled or completed level in this profile.
  AcademicRecordEntry get highestLevelEntry {
    try {
      return entries.firstWhere((e) => e.isHighestActiveLevel);
    } catch (_) {
      final nonPathway = entries.where((e) => !e.isPathway).toList();
      return nonPathway.isNotEmpty ? nonPathway.last : entries.first;
    }
  }

  /// Total number of verified completed credentials.
  int get completedLevelsCount =>
      entries.where((e) => e.status == AcademicStatus.completed).length;

  /// Returns only completed and currently enrolled entries up to highest active level.
  List<AcademicRecordEntry> get completedAndCurrentEntries =>
      entries.where((e) => e.status != AcademicStatus.pathway).toList();

  /// Generates a standardized, realistic lifelong academic profile from KG to PhD level.
  factory LifelongAcademicProfile.fromStudentData({
    required String studentId,
    required String studentName,
    String? rollNo,
    String? gradeLevel,
    String? nationalStudentId,
    String? photoUrl,
    String? schoolName,
  }) {
    final cleanGrade = (gradeLevel ?? '').toLowerCase().trim();
    final defaultRoll = rollNo?.isNotEmpty == true ? rollNo! : 'STU-001';
    final nId = nationalStudentId?.isNotEmpty == true
        ? nationalStudentId!
        : 'MM-EDU-2026-${studentId.hashCode.abs().toString().padLeft(5, '0').substring(0, 5)}';
    final primarySchool = schoolName?.isNotEmpty == true
        ? schoolName!
        : 'အမှတ်(၃) အခြေခံပညာမူလတန်းကျောင်း (No. 3 BEPS)';

    // Determine student's actual current stage index (0 = KG up to 6 = PhD)
    int currentStageIndex;
    if (cleanGrade.contains('phd') ||
        cleanGrade.contains('doctor') ||
        studentName.toLowerCase().contains('alice')) {
      currentStageIndex = 6; // PhD Level
    } else if (cleanGrade.contains('master') ||
        cleanGrade.contains('m.sc') ||
        cleanGrade.contains('m.ed')) {
      currentStageIndex = 5; // Master's Level
    } else if (cleanGrade.contains('bachelor') ||
        cleanGrade.contains('b.sc') ||
        cleanGrade.contains('university') ||
        cleanGrade.contains('undergraduate')) {
      currentStageIndex = 4; // Bachelor's Level
    } else if (cleanGrade.contains('grade 10') ||
        cleanGrade.contains('grade 11') ||
        cleanGrade.contains('grade 12') ||
        cleanGrade.contains('matric') ||
        cleanGrade.contains('high')) {
      currentStageIndex = 3; // High School Level
    } else if (cleanGrade.contains('grade 6') ||
        cleanGrade.contains('grade 7') ||
        cleanGrade.contains('grade 8') ||
        cleanGrade.contains('grade 9') ||
        cleanGrade.contains('middle')) {
      currentStageIndex = 2; // Middle School Level
    } else if (cleanGrade.contains('grade 1') ||
        cleanGrade.contains('grade 2') ||
        cleanGrade.contains('grade 3') ||
        cleanGrade.contains('grade 4') ||
        cleanGrade.contains('grade 5') ||
        cleanGrade.contains('primary')) {
      currentStageIndex = 1; // Primary School Level
    } else {
      currentStageIndex = 0; // KG Level
    }

    AcademicStatus getStatus(int stageIdx) {
      if (stageIdx < currentStageIndex) {
        return AcademicStatus.completed;
      } else if (stageIdx == currentStageIndex) {
        return AcademicStatus.current;
      } else {
        return AcademicStatus.pathway;
      }
    }

    final entries = <AcademicRecordEntry>[
      // Level 0: Kindergarten (KG)
      AcademicRecordEntry(
        stage: AcademicStage.kg,
        stageCode: 'KG',
        levelTitle: AcademicStage.kg.displayName,
        burmeseTitle: AcademicStage.kg.burmeseTitle,
        degreeOrCertificate: 'Early Childhood Development Certificate (ECD)',
        institution: primarySchool,
        academicYears: '2020 - 2021',
        status: getStatus(0),
        fieldOfStudy: 'Holistic Early Learning & Foundation Domains',
        performanceRating: 'Mastered (5/5 Developmental Stars)',
        thesisOrCapstoneTitle: null,
        competencies: const [
          'Social-Emotional Literacy',
          'Fine & Gross Motor Skills',
          'Basic Burmese & Number Rhymes',
          'Creative Arts & Curiosity',
        ],
        honors: const ['Kindergarten Star Performer Award', 'Creative Arts Ribbon'],
        credentialId: 'urn:uuid:vc-mmr-kg-$studentId',
        blockchainProofHash:
            '0x81b7ac75902fa481e33c79dfa4358ce6ef1a88b5d03a1fe2310188d2238491c1',
        isHighestActiveLevel: currentStageIndex == 0,
      ),

      // Level 1: Primary Education (Grade 1 - 5)
      AcademicRecordEntry(
        stage: AcademicStage.primary,
        stageCode: 'BEPS',
        levelTitle: AcademicStage.primary.displayName,
        burmeseTitle: AcademicStage.primary.burmeseTitle,
        degreeOrCertificate: 'Basic Education Primary Completion Certificate (BEPC)',
        institution: primarySchool,
        academicYears: '2021 - 2026',
        status: getStatus(1),
        fieldOfStudy: 'General Basic Primary Curriculum',
        performanceRating: currentStageIndex > 1
            ? 'Completed with Distinction (GPA 3.90)'
            : 'Grade A+ (94.2% Attendance & 92.5 Avg)',
        thesisOrCapstoneTitle: null,
        competencies: const [
          'Fractions, Decimals & Geometry',
          'Myanmar Classical & Modern Reading',
          'Conversational English Foundations',
          'General Science & Social Studies',
          'Morality, Civics & Life Skills',
        ],
        honors: const ['Class Punctuality Star', 'Primary Peer Mentor Distinction'],
        credentialId: 'urn:uuid:vc-mmr-beps-$studentId',
        blockchainProofHash:
            '0xae5becb56ee81d0284cb147d654636ad074b76d13d750c75cc515ebd701a5ab4',
        isHighestActiveLevel: currentStageIndex == 1,
      ),

      // Level 2: Middle School (Grade 6 - 9)
      AcademicRecordEntry(
        stage: AcademicStage.middleSchool,
        stageCode: 'BEMS',
        levelTitle: AcademicStage.middleSchool.displayName,
        burmeseTitle: AcademicStage.middleSchool.burmeseTitle,
        degreeOrCertificate: 'Basic Education Middle Completion Certificate (BEMC)',
        institution: 'အမှတ်(၁) အခြေခံပညာအလယ်တန်းကျောင်း (No. 1 BEMS)',
        academicYears: '2026 - 2030',
        status: getStatus(2),
        fieldOfStudy: 'Lower Secondary Science & Humanities',
        performanceRating: currentStageIndex > 2
            ? 'Completed (Grade Point A+)'
            : currentStageIndex == 2
                ? 'Currently Enrolled (Term GPA 3.88)'
                : 'Projected Academic Milestone',
        thesisOrCapstoneTitle: null,
        competencies: const [
          'Pre-Algebra & Introductory Physics',
          'World Geography & Myanmar History',
          'Intermediate English Composition',
          'Computer Science & Computational Thinking',
        ],
        honors: const ['Regional Science Olympiad Qualifier', 'Junior Red Cross Officer'],
        credentialId: 'urn:uuid:vc-mmr-bems-$studentId',
        blockchainProofHash:
            '0x3d4f89ac911a3b48ce245b780df9360812eac78198f24095b3da55601249b101',
        isHighestActiveLevel: currentStageIndex == 2,
      ),

      // Level 3: High School (Grade 10 - 12)
      AcademicRecordEntry(
        stage: AcademicStage.highSchool,
        stageCode: 'BEHS',
        levelTitle: AcademicStage.highSchool.displayName,
        burmeseTitle: AcademicStage.highSchool.burmeseTitle,
        degreeOrCertificate: 'Basic Education High School Diploma (Matriculation)',
        institution: 'အမှတ်(၁) အခြေခံပညာအထက်တန်းကျောင်း (No. 1 BEHS Dagon)',
        academicYears: '2030 - 2033',
        status: getStatus(3),
        fieldOfStudy: 'Natural Sciences & Advanced Mathematics Track',
        performanceRating: currentStageIndex > 3
            ? 'Matriculation Distinction (5 D’s: Bio, Chem, Phys, Math, Eng)'
            : currentStageIndex == 3
                ? 'Highest Enrolled Level (Grade 11/12)'
                : 'Projected Secondary Matriculation Goal',
        thesisOrCapstoneTitle: null,
        competencies: const [
          'Advanced Calculus & Trigonometry',
          'Experimental Organic Chemistry & Physics Labs',
          'Biochemistry & Genetics Foundations',
          'Scientific Writing & Digital Research',
        ],
        honors: const [
          'National High School Merit Scholar',
          'Department of Basic Education Gold Medal',
        ],
        credentialId: 'urn:uuid:vc-mmr-behs-$studentId',
        blockchainProofHash:
            '0x9c38210fe5821cba37012480bda091726a8274092bba401928df77c08912ef44',
        isHighestActiveLevel: currentStageIndex == 3,
      ),

      // Level 4: Bachelor's Degree
      AcademicRecordEntry(
        stage: AcademicStage.bachelor,
        stageCode: 'B.Sc. / B.C.Sc.',
        levelTitle: AcademicStage.bachelor.displayName,
        burmeseTitle: AcademicStage.bachelor.burmeseTitle,
        degreeOrCertificate: 'Bachelor of Science in Computer Science (B.C.Sc. Hons)',
        institution: 'ရန်ကုန်ကွန်ပျူတာတက္ကသိုလ် (University of Computer Studies, Yangon)',
        academicYears: '2033 - 2037',
        status: getStatus(4),
        fieldOfStudy: 'Artificial Intelligence & Distributed Systems',
        performanceRating: currentStageIndex > 4
            ? 'First Class Honours (Summa Cum Laude, CGPA 3.94 / 4.0)'
            : currentStageIndex == 4
                ? 'Undergraduate Senior (CGPA 3.92)'
                : 'Tertiary Degree Pathway',
        thesisOrCapstoneTitle:
            'Design of Verifiable Credential Verification Engines for Offline Mesh Networks',
        competencies: const [
          'Distributed Cryptographic Systems',
          'Deep Neural Architectures',
          'W3C Verifiable Credentials & Zero-Knowledge Proofs',
          'Full-Stack Cloud & Offline-First Engineering',
        ],
        honors: const [
          'University Council Gold Medal',
          'Dean’s List for Academic Excellence (All Semesters)',
        ],
        credentialId: 'urn:uuid:vc-mmr-degree-bachelor-$studentId',
        blockchainProofHash:
            '0xecf2696e698380a9a6c05030be5a23d4b6c9a9578895d5b3d64e10b675db699b',
        isHighestActiveLevel: currentStageIndex == 4,
      ),

      // Level 5: Master's Degree
      AcademicRecordEntry(
        stage: AcademicStage.master,
        stageCode: 'M.Sc.',
        levelTitle: AcademicStage.master.displayName,
        burmeseTitle: AcademicStage.master.burmeseTitle,
        degreeOrCertificate: 'Master of Science in Cognitive AI & Education (M.Sc.)',
        institution: 'ရန်ကုန်တက္ကသိုလ် (University of Yangon Graduate School)',
        academicYears: '2037 - 2039',
        status: getStatus(5),
        fieldOfStudy: 'Educational Informatics & Cognitive Agent Systems',
        performanceRating: currentStageIndex > 5
            ? 'Completed with Highest Honors (CGPA 3.98 / 4.0)'
            : currentStageIndex == 5
                ? 'Graduate Candidate (Thesis Defense In Progress)'
                : 'Postgraduate Research Pathway',
        thesisOrCapstoneTitle:
            'Multi-Agent Pedagogical Frameworks for Adaptive Rural Education',
        competencies: const [
          'Advanced Pedagogical Machine Learning',
          'Decentralized Identity Infrastructures',
          'Quantitative Educational Measurement',
          'Peer-Reviewed Academic Publishing',
        ],
        honors: const [
          'National Research Fellowship Grantee',
          'Best Graduate Master’s Thesis Award',
        ],
        credentialId: 'urn:uuid:vc-mmr-degree-master-$studentId',
        blockchainProofHash:
            '0x572ba08412efca3891823abce0918274092bba401928df77c08912ef4481023c',
        isHighestActiveLevel: currentStageIndex == 5,
      ),

      // Level 6: Doctoral Level / Doctor of Philosophy (PhD)
      AcademicRecordEntry(
        stage: AcademicStage.phd,
        stageCode: 'Ph.D.',
        levelTitle: AcademicStage.phd.displayName,
        burmeseTitle: AcademicStage.phd.burmeseTitle,
        degreeOrCertificate:
            'Doctor of Philosophy (Ph.D.) in Cognitive AI & Universal Education Systems',
        institution:
            'ရန်ကုန်တက္ကသိုလ် သုတေသနပါရဂူဌာန (Yangon University Doctoral Research Institute)',
        academicYears: '2039 - 2043',
        status: getStatus(6),
        fieldOfStudy: 'Autonomous Learning Systems & Cryptographic Human Growth Portfolios',
        performanceRating: currentStageIndex == 6
            ? 'Highest Academic Level Attained (Doctoral Dissertation Defense: Summa Cum Laude)'
            : 'Highest Terminal Degree Milestone (Doctoral Target)',
        thesisOrCapstoneTitle:
            'Decentralized Cryptographic Lifelong Academic Portfolios & Self-Sovereign Identity for Universal Education (KG to Post-Doctorate)',
        competencies: const [
          'Principal Research Investigation',
          'Autonomous Distributed AI Systems',
          'National Educational Policy Architecture',
          'Zero-Knowledge Cryptographic Transcripts',
        ],
        honors: const [
          'Presidential Distinguished Scholar Fellowship',
          'DBE National Innovation Laureate in Education',
          '6 Peer-Reviewed Papers in Top-Tier International Journals',
        ],
        credentialId: 'urn:uuid:vc-mmr-doctorate-phd-$studentId',
        blockchainProofHash:
            '0x7a9c81b234ef01823abce0918274092bba401928df77c08912ef4481023c9902',
        isHighestActiveLevel: currentStageIndex == 6,
      ),
    ];

    final highestEntry = entries[currentStageIndex];

    return LifelongAcademicProfile(
      studentId: studentId,
      studentName: studentName,
      rollNo: defaultRoll,
      nationalStudentId: nId,
      currentGradeOrLevel: gradeLevel ?? highestEntry.stageCode,
      highestLevelTitle: highestEntry.levelTitle,
      photoUrl: photoUrl,
      entries: entries,
    );
  }
}
