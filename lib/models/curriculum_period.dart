import 'package:flutter/material.dart';

/// Represents a scheduled curriculum period in the school week.
class CurriculumPeriod {
  final String id;
  final String subjectCode;
  final String subjectName;
  final String subjectNameMy;
  final String teacherName;
  final String room;
  final int dayOfWeek; // 1 = Monday, 2 = Tuesday, ..., 7 = Sunday
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final String chapterTitle;
  final String chapterDescription;
  final String? homework;
  final String shiftSection; // 'full_day', 'morning', 'afternoon'
  final String? studentId;
  final String? gradeLevel;

  const CurriculumPeriod({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.subjectNameMy,
    required this.teacherName,
    required this.room,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.chapterTitle,
    required this.chapterDescription,
    this.homework,
    this.shiftSection = 'full_day',
    this.studentId,
    this.gradeLevel,
  });

  double get startHourDecimal => startTime.hour + (startTime.minute / 60.0);
  double get endHourDecimal => endTime.hour + (endTime.minute / 60.0);
  double get durationHours => endHourDecimal - startHourDecimal;

  String get timeRangeString {
    final startH = startTime.hour.toString().padLeft(2, '0');
    final startM = startTime.minute.toString().padLeft(2, '0');
    final endH = endTime.hour.toString().padLeft(2, '0');
    final endM = endTime.minute.toString().padLeft(2, '0');
    return '$startH:$startM - $endH:$endM';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'subject_name_my': subjectNameMy,
      'teacher_name': teacherName,
      'room': room,
      'day_of_week': dayOfWeek,
      'start_hour': startTime.hour,
      'start_minute': startTime.minute,
      'end_hour': endTime.hour,
      'end_minute': endTime.minute,
      'color_value': color.toARGB32(),
      'chapter_title': chapterTitle,
      'chapter_description': chapterDescription,
      'homework': homework,
      'shift_section': shiftSection,
      'student_id': studentId,
      'grade_level': gradeLevel,
    };
  }

  factory CurriculumPeriod.fromJson(Map<String, dynamic> json) {
    return CurriculumPeriod(
      id: json['id']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      subjectNameMy: json['subject_name_my']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? '',
      room: json['room']?.toString() ?? '',
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 1,
      startTime: TimeOfDay(
        hour: (json['start_hour'] as num?)?.toInt() ?? 8,
        minute: (json['start_minute'] as num?)?.toInt() ?? 0,
      ),
      endTime: TimeOfDay(
        hour: (json['end_hour'] as num?)?.toInt() ?? 8,
        minute: (json['end_minute'] as num?)?.toInt() ?? 50,
      ),
      color: Color((json['color_value'] as num?)?.toInt() ?? 0xFF3B82F6),
      chapterTitle: json['chapter_title']?.toString() ?? '',
      chapterDescription: json['chapter_description']?.toString() ?? '',
      homework: json['homework']?.toString(),
      shiftSection: json['shift_section']?.toString() ?? 'full_day',
      studentId: json['student_id']?.toString(),
      gradeLevel: json['grade_level']?.toString(),
    );
  }

  CurriculumPeriod copyWith({
    String? id,
    String? subjectCode,
    String? subjectName,
    String? subjectNameMy,
    String? teacherName,
    String? room,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    Color? color,
    String? chapterTitle,
    String? chapterDescription,
    String? homework,
    String? shiftSection,
    String? studentId,
    String? gradeLevel,
  }) {
    return CurriculumPeriod(
      id: id ?? this.id,
      subjectCode: subjectCode ?? this.subjectCode,
      subjectName: subjectName ?? this.subjectName,
      subjectNameMy: subjectNameMy ?? this.subjectNameMy,
      teacherName: teacherName ?? this.teacherName,
      room: room ?? this.room,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterDescription: chapterDescription ?? this.chapterDescription,
      homework: homework ?? this.homework,
      shiftSection: shiftSection ?? this.shiftSection,
      studentId: studentId ?? this.studentId,
      gradeLevel: gradeLevel ?? this.gradeLevel,
    );
  }

  /// Parses from backend TimetablePeriodDTO or ClassTimetableDTO period structure
  factory CurriculumPeriod.fromBackendJson(Map<String, dynamic> json) {
    int startH = 8, startM = 0;
    final startStr = json['start_time']?.toString() ?? '08:00';
    final startParts = startStr.split(':');
    if (startParts.length >= 2) {
      startH = int.tryParse(startParts[0]) ?? 8;
      startM = int.tryParse(startParts[1]) ?? 0;
    }

    int endH = 9, endM = 0;
    final endStr = json['end_time']?.toString() ?? '09:00';
    final endParts = endStr.split(':');
    if (endParts.length >= 2) {
      endH = int.tryParse(endParts[0]) ?? 9;
      endM = int.tryParse(endParts[1]) ?? 0;
    }

    Color color = const Color(0xFF3B82F6);
    final colorHex = json['color_hex']?.toString();
    if (colorHex != null && colorHex.startsWith('#')) {
      final clean = colorHex.replaceFirst('#', '');
      if (clean.length == 6) {
        color = Color(int.parse('FF$clean', radix: 16));
      }
    } else if (json['color_value'] != null) {
      color = Color((json['color_value'] as num).toInt());
    }

    return CurriculumPeriod(
      id: json['id']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      subjectNameMy: json['subject_name_my']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? '',
      room: (json['room_number'] ?? json['room'])?.toString() ?? 'Room 302',
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 1,
      startTime: TimeOfDay(hour: startH, minute: startM),
      endTime: TimeOfDay(hour: endH, minute: endM),
      color: color,
      chapterTitle: (json['topic'] ?? json['chapter_title'])?.toString() ?? 'Core MOE Lesson',
      chapterDescription: (json['description'] ?? json['topic'])?.toString() ?? '',
      shiftSection: (json['shift_type'] ?? json['shift_section'])?.toString() ?? 'full_day',
      studentId: json['student_id']?.toString(),
      gradeLevel: json['grade_level']?.toString(),
    );
  }

  /// Converts period into SQLite row map
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'student_id': studentId ?? '',
      'grade_level': gradeLevel ?? '',
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'subject_name_my': subjectNameMy,
      'teacher_name': teacherName,
      'room': room,
      'day_of_week': dayOfWeek,
      'start_hour': startTime.hour,
      'start_minute': startTime.minute,
      'end_hour': endTime.hour,
      'end_minute': endTime.minute,
      'color_value': color.toARGB32(),
      'chapter_title': chapterTitle,
      'chapter_description': chapterDescription,
      'homework': homework ?? '',
      'shift_section': shiftSection,
    };
  }

  /// Restores period from SQLite row map
  factory CurriculumPeriod.fromSqliteMap(Map<String, dynamic> map) {
    return CurriculumPeriod(
      id: map['id']?.toString() ?? '',
      studentId: (map['student_id']?.toString().isEmpty ?? true) ? null : map['student_id']?.toString(),
      gradeLevel: (map['grade_level']?.toString().isEmpty ?? true) ? null : map['grade_level']?.toString(),
      subjectCode: map['subject_code']?.toString() ?? '',
      subjectName: map['subject_name']?.toString() ?? '',
      subjectNameMy: map['subject_name_my']?.toString() ?? '',
      teacherName: map['teacher_name']?.toString() ?? '',
      room: map['room']?.toString() ?? '',
      dayOfWeek: (map['day_of_week'] as num?)?.toInt() ?? 1,
      startTime: TimeOfDay(
        hour: (map['start_hour'] as num?)?.toInt() ?? 8,
        minute: (map['start_minute'] as num?)?.toInt() ?? 0,
      ),
      endTime: TimeOfDay(
        hour: (map['end_hour'] as num?)?.toInt() ?? 9,
        minute: (map['end_minute'] as num?)?.toInt() ?? 0,
      ),
      color: Color((map['color_value'] as num?)?.toInt() ?? 0xFF3B82F6),
      chapterTitle: map['chapter_title']?.toString() ?? '',
      chapterDescription: map['chapter_description']?.toString() ?? '',
      homework: (map['homework']?.toString().isEmpty ?? true) ? null : map['homework']?.toString(),
      shiftSection: map['shift_section']?.toString() ?? 'full_day',
    );
  }

  /// Resolves appropriate sample curriculum based on student's grade
  static List<CurriculumPeriod> getCurriculumForGrade(
    String? grade, {
    String shift = 'full_day',
    String? studentId,
  }) {
    final lower = (grade ?? '').toLowerCase();
    if (lower.contains('kg') || lower.contains('kindergarten')) {
      return getSampleKGCurriculum(shift: shift, studentId: studentId);
    } else if (lower.contains('5') || lower.contains('primary') || lower.contains('g5')) {
      return getSampleGrade5Curriculum(shift: shift, studentId: studentId);
    } else {
      return getSampleGrade8Curriculum(shift: shift, studentId: studentId);
    }
  }

  /// Weekly curriculum for Kindergarten (KG): Early Childhood Care and Development (ECCD) official schedule
  static List<CurriculumPeriod> getSampleKGCurriculum({String shift = 'full_day', String? studentId}) {
    final List<CurriculumPeriod> periods = [];

    final kgSchedule = <int, List<Map<String, String>>>{
      1: [ // တနင်္လာ (Monday)
        {'my': 'ပြောဆို', 'en': 'Oral Expression & Speaking', 'code': 'KG-SPK', 'topic': 'အသံထွက်နှင့် အပြောအဆို လေ့ကျင့်ခြင်း'},
        {'my': 'ကိုယ်စိတ်', 'en': 'Physical & Mental Well-being', 'code': 'KG-PSE', 'topic': 'ခန္ဓာကိုယ်လှုပ်ရှားမှုနှင့် စိတ်ပိုင်းဆိုင်ရာ ဖွံ့ဖြိုးမှု'},
        {'my': 'သီဆို', 'en': 'Singing & Nursery Rhymes', 'code': 'KG-SNG', 'topic': 'ကလေးကဗျာနှင့် သံပြိုင်ရွတ်ဆိုခြင်း'},
        {'my': 'ဂီတ', 'en': 'Music & Rhythm', 'code': 'KG-MUS', 'topic': 'စည်းဝါးနှင့် တူရိယာသံစဉ် လေ့လာခြင်း'},
        {'my': 'စာရိတ္တ', 'en': 'Moral & Character Building', 'code': 'KG-MOR', 'topic': 'ယဉ်ကျေးလိမ္မာနှင့် လူမှုဆက်ဆံရေး'},
        {'my': 'စိတ်ကြိုက်ဘာသာရပ်များ သင်ကြားခြင်း', 'en': 'Free Choice Activities & Electives', 'code': 'KG-ACT', 'topic': 'စိတ်ကြိုက် ကစားနည်းနှင့် တီထွင်ဖန်တီးမှု လှုပ်ရှားခြင်း'},
      ],
      2: [ // အင်္ဂါ (Tuesday)
        {'my': 'ပြောဆို', 'en': 'Oral Expression & Speaking', 'code': 'KG-SPK', 'topic': 'ပုံပြင်ပြောခြင်းနှင့် စကားပြောစွမ်းရည်'},
        {'my': 'ကိုယ်စိတ်', 'en': 'Physical & Mental Well-being', 'code': 'KG-PSE', 'topic': 'လက်ချောင်းကြွက်သားနှင့် ဟန်ချက်ညီ လှုပ်ရှားမှု'},
        {'my': 'သင်္ချာ', 'en': 'Early Mathematics & Numbers', 'code': 'KG-MTH', 'topic': 'ကိန်းဂဏန်းနှင့် ပုံသဏ္ဌာန်များ ရေတွက်ခြင်း'},
        {'my': 'ကိုယ်စိတ်', 'en': 'Physical & Mental Well-being', 'code': 'KG-PSE', 'topic': 'ကျန်းမာရေးအလေ့အကျင့်နှင့် ကိုယ်လက်လှုပ်ရှား'},
        {'my': 'စာရိတ္တ', 'en': 'Moral & Character Building', 'code': 'KG-MOR', 'topic': 'မိဘဆရာ ရိုသေလေးစားမှုနှင့် ပူးပေါင်းဆောင်ရွက်ခြင်း'},
        {'my': 'စိတ်ကြိုက်ဘာသာရပ်များ သင်ကြားခြင်း', 'en': 'Free Choice Activities & Electives', 'code': 'KG-ACT', 'topic': 'စိတ်ကြိုက် ကစားနည်းနှင့် တီထွင်ဖန်တီးမှု လှုပ်ရှားခြင်း'},
      ],
      3: [ // ဗုဒ္ဓဟူး (Wednesday)
        {'my': 'ပြောဆို', 'en': 'Oral Expression & Speaking', 'code': 'KG-SPK', 'topic': 'နေ့စဉ်သုံး စကားပြောနှင့် အမေးအဖြေ'},
        {'my': 'သီဆို', 'en': 'Singing & Nursery Rhymes', 'code': 'KG-SNG', 'topic': 'ရိုးရာတေးသံသာနှင့် ကဗျာများ'},
        {'my': 'သင်္ချာ', 'en': 'Early Mathematics & Numbers', 'code': 'KG-MTH', 'topic': 'အရွယ်အစားနှင့် အရေအတွက် နှိုင်းယှဉ်ခြင်း'},
        {'my': 'ကိုယ်စိတ်', 'en': 'Physical & Mental Well-being', 'code': 'KG-PSE', 'topic': 'အာရုံခံစားမှုနှင့် စိတ်လှုပ်ရှားမှု ထိန်းကျောင်းခြင်း'},
        {'my': 'ဘဝ', 'en': 'Life Skills & World Around Us', 'code': 'KG-LIF', 'topic': 'နေ့စဉ်လူနေမှုဘဝနှင့် သန့်ရှင်းရေး'},
        {'my': 'စိတ်ကြိုက်ဘာသာရပ်များ သင်ကြားခြင်း', 'en': 'Free Choice Activities & Electives', 'code': 'KG-ACT', 'topic': 'စိတ်ကြိုက် ကစားနည်းနှင့် တီထွင်ဖန်တီးမှု လှုပ်ရှားခြင်း'},
      ],
      4: [ // ကြာသပတေး (Thursday)
        {'my': 'ပြောဆို', 'en': 'Oral Expression & Speaking', 'code': 'KG-SPK', 'topic': 'အသံထွက်မှန်ကန်ရေးနှင့် ဗျည်းသရ လေ့ကျင့်ခြင်း'},
        {'my': 'အင်္ဂလိပ်', 'en': 'Early English Language', 'code': 'KG-ENG', 'topic': 'ABC Alphabet & Phonics Songs'},
        {'my': 'ပတ်ဝန်းကျင်', 'en': 'Environment & Nature Studies', 'code': 'KG-ENV', 'topic': 'သဘာဝပတ်ဝန်းကျင်၊ သစ်ပင်နှင့် တိရစ္ဆာန်ငယ်များ'},
        {'my': 'ပတ်ဝန်းကျင်', 'en': 'Environment & Nature Studies', 'code': 'KG-ENV', 'topic': 'ရာသီဥတုနှင့် ပတ်ဝန်းကျင်သန့်ရှင်းရေး'},
        {'my': 'ဘဝ', 'en': 'Life Skills & World Around Us', 'code': 'KG-LIF', 'topic': 'အန္တရာယ်ကင်းရှင်းရေးနှင့် ပူးပေါင်းကစားခြင်း'},
        {'my': 'စိတ်ကြိုက်ဘာသာရပ်များ သင်ကြားခြင်း', 'en': 'Free Choice Activities & Electives', 'code': 'KG-ACT', 'topic': 'စိတ်ကြိုက် ကစားနည်းနှင့် တီထွင်ဖန်တီးမှု လှုပ်ရှားခြင်း'},
      ],
      5: [ // သောကြာ (Friday)
        {'my': 'ပြောဆို', 'en': 'Oral Expression & Speaking', 'code': 'KG-SPK', 'topic': 'အပတ်စဉ် အတွေ့အကြုံ မျှဝေပြောဆိုခြင်း'},
        {'my': 'အင်္ဂလိပ်', 'en': 'Early English Language', 'code': 'KG-ENG', 'topic': 'Greeting words, Colors and Rhymes'},
        {'my': 'ကိုယ်စိတ်', 'en': 'Physical & Mental Well-being', 'code': 'KG-PSE', 'topic': 'အားကစားနှင့် ကိုယ်လက်ကြံ့ခိုင်မှု ကစားနည်းများ'},
        {'my': 'အနုပညာ', 'en': 'Creative Arts & Crafts', 'code': 'KG-ART', 'topic': 'ဆေးရောင်ခြယ်ခြင်း၊ စက္ကူခေါက်ခြင်းနှင့် လက်မှုဖန်တီးမှု'},
        {'my': 'ဂီတ', 'en': 'Music & Rhythm', 'code': 'KG-MUS', 'topic': 'အက၊ အလှနှင့် တေးဂီတ လှုပ်ရှားမှု'},
        {'my': 'စိတ်ကြိုက်ဘာသာရပ်များ သင်ကြားခြင်း', 'en': 'Free Choice Activities & Electives', 'code': 'KG-ACT', 'topic': 'စိတ်ကြိုက် ကစားနည်းနှင့် တီထွင်ဖန်တီးမှု လှုပ်ရှားခြင်း'},
      ],
    };

    final timeSlots = [
      {'startH': 8, 'startM': 30, 'endH': 9, 'endM': 15},
      {'startH': 9, 'startM': 15, 'endH': 10, 'endM': 0},
      {'startH': 10, 'startM': 30, 'endH': 11, 'endM': 15},
      {'startH': 11, 'startM': 15, 'endH': 12, 'endM': 0},
      {'startH': 13, 'startM': 0, 'endH': 13, 'endM': 45},
      {'startH': 14, 'startM': 0, 'endH': 14, 'endM': 45},
    ];

    for (int day = 1; day <= 5; day++) {
      final lessons = kgSchedule[day]!;
      for (int i = 0; i < lessons.length; i++) {
        final slot = timeSlots[i];
        final lesson = lessons[i];
        periods.add(
          CurriculumPeriod(
            id: 'kg-d$day-p${i + 1}',
            subjectCode: lesson['code']!,
            subjectName: lesson['en']!,
            subjectNameMy: lesson['my']!,
            teacherName: 'Daw Thida Win (ဒေါ်သီတာဝင်း)',
            room: 'KG Sunflower Room',
            dayOfWeek: day,
            startTime: TimeOfDay(hour: slot['startH']!, minute: slot['startM']!),
            endTime: TimeOfDay(hour: slot['endH']!, minute: slot['endM']!),
            color: const Color(0xFF64748B),
            chapterTitle: lesson['topic']!,
            chapterDescription: 'KG အခြေခံ သင်ရိုးညွှန်းတမ်း လေ့ကျင့်ခန်းများ။',
            homework: 'အိမ်စာမရှိပါ (အတန်းတွင်း လှုပ်ရှားမှု)',
            shiftSection: shift,
            studentId: studentId,
            gradeLevel: 'Kindergarten (KG)',
          ),
        );
      }
    }

    return periods;
  }

  /// Weekly curriculum for Grade 5: primary foundation subjects (Myanmar, English, Math, Science, Social Studies)
  static List<CurriculumPeriod> getSampleGrade5Curriculum({String shift = 'full_day', String? studentId}) {
    final List<CurriculumPeriod> periods = [];
    final days = [1, 2, 3, 4, 5]; // Mon - Fri

    for (final day in days) {
      periods.addAll([
        CurriculumPeriod(
          id: 'g5-d$day-p1',
          subjectCode: 'MYAN-5',
          subjectName: 'Myanmar Language',
          subjectNameMy: 'မြန်မာစာ',
          teacherName: 'Daw Khin Myo (ဒေါ်ခင်မျိုး)',
          room: 'Room 102',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 8, minute: 0),
          endTime: const TimeOfDay(hour: 8, minute: 50),
          color: const Color(0xFFF59E0B), // Amber
          chapterTitle: 'မြန်မာစကားပြေနှင့် ဝါကျဖွဲ့စည်းပုံ သဒ္ဒါ',
          chapterDescription: 'စာဖတ်စွမ်းရည် တိုးတက်ရေး၊ ဝေါဟာရသစ်များ မှတ်သားခြင်းနှင့် စာစီစာကုံး အခြေခံ။',
          homework: 'စာမျက်နှာ ၂၄ အမေးအဖြေ ရေးသားရန်',
          shiftSection: shift,
          studentId: studentId,
          gradeLevel: 'Grade 5-A',
        ),
        CurriculumPeriod(
          id: 'g5-d$day-p2',
          subjectCode: 'ENG-5',
          subjectName: 'English Language',
          subjectNameMy: 'အင်္ဂလိပ်စာ',
          teacherName: 'Daw Aye Aye (ဒေါ်အေးအေး)',
          room: 'Room 102',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 9, minute: 50),
          color: const Color(0xFF8B5CF6), // Purple
          chapterTitle: 'Unit 3: Friends and Family in Myanmar',
          chapterDescription: 'Present simple questions, reading short paragraphs, and spelling practice.',
          homework: 'Workbook page 18 Exercise B',
          shiftSection: shift,
          studentId: studentId,
          gradeLevel: 'Grade 5-A',
        ),
        CurriculumPeriod(
          id: 'g5-d$day-p3',
          subjectCode: 'MATH-5',
          subjectName: 'Mathematics',
          subjectNameMy: 'သင်္ချာ',
          teacherName: 'U Min Din (ဦးမင်းဒင်)',
          room: 'Room 102',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 10, minute: 0),
          endTime: const TimeOfDay(hour: 10, minute: 50),
          color: const Color(0xFF3B82F6), // Blue
          chapterTitle: 'အခန်း ၄: အပိုင်းကိန်းနှင့် ဒသမကိန်း တွက်ချက်နည်း',
          chapterDescription: 'ပိုင်းခြေတူ ပိုင်းခြေမတူ အပိုင်းကိန်းများ ပေါင်းနှုတ်မြှောက်စား ပြဿနာများ ဖြေရှင်းခြင်း။',
          homework: 'သင်္ချာလေ့ကျင့်ခန်း ၄.၁ ပုစ္ဆာ ၁ မှ ၅',
          shiftSection: shift,
          studentId: studentId,
          gradeLevel: 'Grade 5-A',
        ),
        CurriculumPeriod(
          id: 'g5-d$day-p4',
          subjectCode: 'SCI-5',
          subjectName: 'General Science',
          subjectNameMy: 'အထွေထွေသိပ္ပံ',
          teacherName: 'Daw Khin Myo (ဒေါ်ခင်မျိုး)',
          room: 'Science Corner',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 11, minute: 0),
          endTime: const TimeOfDay(hour: 11, minute: 50),
          color: const Color(0xFF10B981), // Emerald
          chapterTitle: 'အပင်များနှင့် တိရစ္ဆာန်များ၏ ရှင်သန်မှု သဘာဝ',
          chapterDescription: 'အလင်းမှီစုဖွဲ့ခြင်း၊ အမြစ်နှင့် ရွက်ကြောစနစ်များ လက်တွေ့လေ့လာခြင်း။',
          shiftSection: shift,
          studentId: studentId,
          gradeLevel: 'Grade 5-A',
        ),
        CurriculumPeriod(
          id: 'g5-d$day-p5',
          subjectCode: 'SOC-5',
          subjectName: 'Social Studies & Moral Education',
          subjectNameMy: 'လူမှုရေးနှင့် ဘဝတွက်တာ ကျွမ်းကျင်မှု',
          teacherName: 'U Min Din (ဦးမင်းဒင်)',
          room: 'Room 102',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 13, minute: 0),
          endTime: const TimeOfDay(hour: 13, minute: 50),
          color: const Color(0xFF06B6D4), // Cyan
          chapterTitle: 'မြန်မာ့သမိုင်းနှင့် နိုင်ငံသားတာဝန်များ',
          chapterDescription: 'ပုဂံခေတ်သမိုင်း အကျဉ်းနှင့် ကျောင်းတွင်း အတူတကွ ပူးပေါင်းဆောင်ရွက်မှု။',
          shiftSection: shift,
          studentId: studentId,
          gradeLevel: 'Grade 5-A',
        ),
      ]);
    }

    return periods;
  }

  /// Weekly curriculum for Grade 8 aligned to realistic 8:00 AM - 4:00 PM school schedule
  /// Each time slot (e.g. 09:00 - 09:50) contains strictly ONE single subject per day.
  static List<CurriculumPeriod> getSampleGrade8Curriculum({String shift = 'full_day', String? studentId}) {
    if (shift == 'morning') {
      return _getMorningShiftCurriculum();
    } else if (shift == 'afternoon') {
      return _getAfternoonShiftCurriculum();
    }
    return _getFullDayCurriculum();
  }

  /// Full-Day Standard Shift: 8:00 AM to 4:00 PM (8 periods: single subject per hour)
  static List<CurriculumPeriod> _getFullDayCurriculum() {
    return [
      // ==================== MONDAY (Day 1) ====================
      const CurriculumPeriod(
        id: 'mon-p1',
        subjectCode: 'MYAN-8',
        subjectName: 'Myanmar Language',
        subjectNameMy: 'မြန်မာစာ',
        teacherName: 'U Thein Win',
        room: 'Room 204',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 8, minute: 0),
        endTime: TimeOfDay(hour: 8, minute: 50),
        color: Color(0xFFF59E0B), // Amber
        chapterTitle: 'ကဗျာနှင့် စကားပြေ ရသခံစားမှု',
        chapterDescription: 'သခင်ကိုယ်တော်မှိုင်း ရာဇဝင်ကဗျာ လေ့လာချက်နှင့် စာစီစာကုံး သဒ္ဒါစည်းမျဉ်းများ။',
        homework: 'စာမျက်နှာ ၄၅ မေးခွန်း (က) မှ (င) အထိ ရေးသားရန်',
      ),
      const CurriculumPeriod(
        id: 'mon-p2',
        subjectCode: 'MATH-8',
        subjectName: 'Mathematics',
        subjectNameMy: 'သင်္ချာ',
        teacherName: 'Daw May Thu',
        room: 'Room 204',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 50),
        color: Color(0xFF3B82F6), // Blue
        chapterTitle: 'Chapter 4: Linear Equations & Graphs',
        chapterDescription: 'Solving simultaneous linear equations with two variables and graphing on cartesian plane.',
        homework: 'Exercise 4.2: Problems 1 to 8 due Wednesday',
      ),
      const CurriculumPeriod(
        id: 'mon-p3',
        subjectCode: 'ENG-8',
        subjectName: 'English',
        subjectNameMy: 'အင်္ဂလိပ်စာ',
        teacherName: 'Daw Hla Hla',
        room: 'Language Lab',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 50),
        color: Color(0xFF8B5CF6), // Purple
        chapterTitle: 'Unit 5: Environmental Conservation',
        chapterDescription: 'Reading comprehension, past participle usage, and environmental vocabulary.',
        homework: 'Complete Unit 5 Workbook activity page 32',
      ),
      const CurriculumPeriod(
        id: 'mon-p4',
        subjectCode: 'SCI-8',
        subjectName: 'General Science',
        subjectNameMy: 'အထွေထွေသိပ္ပံ',
        teacherName: 'U Aung Kyaw',
        room: 'Science Lab B',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 11, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 50),
        color: Color(0xFF10B981), // Emerald
        chapterTitle: 'Physics: Forces, Pressure & Hydraulics',
        chapterDescription: 'Atmospheric pressure experiments and calculating mechanical advantage.',
        homework: 'Lab worksheet on Pascal Principle',
      ),
      const CurriculumPeriod(
        id: 'mon-lunch',
        subjectCode: 'BREAK',
        subjectName: 'Lunch & Midday Break',
        subjectNameMy: 'နေ့လယ်စာနှင့် အနားယူချိန်',
        teacherName: 'Duty Teachers',
        room: 'School Canteen / Campus Ground',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 12, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 0),
        color: Color(0xFF64748B), // Slate Grey
        chapterTitle: 'Midday Meal & Recreation',
        chapterDescription: 'Health meal, hydration, and student outdoor recreation time.',
      ),
      const CurriculumPeriod(
        id: 'mon-p5',
        subjectCode: 'SOC-8',
        subjectName: 'Social Studies',
        subjectNameMy: 'လူမှုရေး (သမိုင်း/ပထဝီ)',
        teacherName: 'Daw Ni Ni',
        room: 'Room 204',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 13, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 50),
        color: Color(0xFFEC4899), // Pink
        chapterTitle: 'Bagan Dynasty Architecture & Trade Routes',
        chapterDescription: 'Economic foundations and architectural innovations of early Myanmar dynasties.',
      ),
      const CurriculumPeriod(
        id: 'mon-p6',
        subjectCode: 'COMP-8',
        subjectName: 'ICT & AI Skills',
        subjectNameMy: 'ကွန်ပျူတာနှင့် နည်းပညာ',
        teacherName: 'Daw Thida',
        room: 'Computer Lab A',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 14, minute: 50),
        color: Color(0xFF06B6D4), // Cyan
        chapterTitle: 'Basic Python & AI Prompting Basics',
        chapterDescription: 'Variables, loops, and interacting with school AI tutoring assistants.',
      ),
      const CurriculumPeriod(
        id: 'mon-p7',
        subjectCode: 'PE-8',
        subjectName: 'Physical Education',
        subjectNameMy: 'ကာယပညာ',
        teacherName: 'Coach Min Khant',
        room: 'Main Gymnasium',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 15, minute: 0),
        endTime: TimeOfDay(hour: 15, minute: 50),
        color: Color(0xFFF97316), // Orange
        chapterTitle: 'Track & Field: Relay & Sprinting',
        chapterDescription: 'Baton exchange technique and cardiovascular endurance drills.',
      ),

      // ==================== TUESDAY (Day 2) ====================
      const CurriculumPeriod(
        id: 'tue-p1',
        subjectCode: 'ENG-8',
        subjectName: 'English',
        subjectNameMy: 'အင်္ဂလိပ်စာ',
        teacherName: 'Daw Hla Hla',
        room: 'Language Lab',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 8, minute: 0),
        endTime: TimeOfDay(hour: 8, minute: 50),
        color: Color(0xFF8B5CF6),
        chapterTitle: 'Speaking & Active Listening Skills',
        chapterDescription: 'Group presentation on community challenges and conversational roleplay.',
      ),
      const CurriculumPeriod(
        id: 'tue-p2',
        subjectCode: 'MATH-8',
        subjectName: 'Mathematics',
        subjectNameMy: 'သင်္ချာ',
        teacherName: 'Daw May Thu',
        room: 'Room 204',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 50),
        color: Color(0xFF3B82F6),
        chapterTitle: 'Geometry: Triangles & Congruence',
        chapterDescription: 'Proving triangle congruence via SAS, ASA, and SSS theorems.',
      ),
      const CurriculumPeriod(
        id: 'tue-p3',
        subjectCode: 'SCI-8',
        subjectName: 'General Science',
        subjectNameMy: 'အထွေထွေသိပ္ပံ',
        teacherName: 'U Aung Kyaw',
        room: 'Science Lab B',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 50),
        color: Color(0xFF10B981),
        chapterTitle: 'Biology: Human Circulatory System',
        chapterDescription: 'Structure of the heart, blood vessels, and maintaining cardiovascular health.',
      ),
      const CurriculumPeriod(
        id: 'tue-p4',
        subjectCode: 'MYAN-8',
        subjectName: 'Myanmar Language',
        subjectNameMy: 'မြန်မာစာ',
        teacherName: 'U Thein Win',
        room: 'Room 204',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 11, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 50),
        color: Color(0xFFF59E0B),
        chapterTitle: 'ဝေါဟာရနှင့် သဒ္ဒါ လေ့ကျင့်ခန်း',
        chapterDescription: 'စကားဆက်များနှင့် သမားရိုးကျ မြန်မာစာလုံးပေါင်း သတ်ပုံကျမ်း အသုံးပြုခြင်း။',
      ),
      const CurriculumPeriod(
        id: 'tue-lunch',
        subjectCode: 'BREAK',
        subjectName: 'Lunch & Midday Break',
        subjectNameMy: 'နေ့လယ်စာနှင့် အနားယူချိန်',
        teacherName: 'Duty Teachers',
        room: 'School Canteen',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 12, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 0),
        color: Color(0xFF64748B),
        chapterTitle: 'Midday Meal & Health Check',
        chapterDescription: 'Campus lunch and peer reading circles.',
      ),
      const CurriculumPeriod(
        id: 'tue-p5',
        subjectCode: 'COMP-8',
        subjectName: 'ICT & AI Skills',
        subjectNameMy: 'ကွန်ပျူတာနှင့် နည်းပညာ',
        teacherName: 'Daw Thida',
        room: 'Computer Lab A',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 13, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 50),
        color: Color(0xFF06B6D4),
        chapterTitle: 'Digital Identity & Ed25519 Keys',
        chapterDescription: 'How student digital credentials and decentralized keys protect personal privacy.',
      ),
      const CurriculumPeriod(
        id: 'tue-p6',
        subjectCode: 'SOC-8',
        subjectName: 'Social Studies',
        subjectNameMy: 'လူမှုရေး (သမိုင်း/ပထဝီ)',
        teacherName: 'Daw Ni Ni',
        room: 'Room 204',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 14, minute: 50),
        color: Color(0xFFEC4899),
        chapterTitle: 'Geography: River Basins of Southeast Asia',
        chapterDescription: 'Ayeyarwady, Chindwin, and Thanlwin river ecosystems and agriculture.',
      ),
      const CurriculumPeriod(
        id: 'tue-p7',
        subjectCode: 'ART-8',
        subjectName: 'Life Skills & Art',
        subjectNameMy: 'ဘဝတွက်တာ ကျွမ်းကျင်စရာနှင့် ပန်းချီ',
        teacherName: 'Daw Khin Mar',
        room: 'Art Studio',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 15, minute: 0),
        endTime: TimeOfDay(hour: 15, minute: 50),
        color: Color(0xFF6366F1),
        chapterTitle: 'Traditional Myanmar Motifs (ကနုတ်)',
        chapterDescription: 'Floral scrollwork and geometric patterns in Southeast Asian decorative art.',
      ),

      // ==================== WEDNESDAY (Day 3) ====================
      const CurriculumPeriod(
        id: 'wed-p1',
        subjectCode: 'SCI-8',
        subjectName: 'General Science',
        subjectNameMy: 'အထွေထွေသိပ္ပံ',
        teacherName: 'U Aung Kyaw',
        room: 'Science Lab B',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 8, minute: 0),
        endTime: TimeOfDay(hour: 8, minute: 50),
        color: Color(0xFF10B981),
        chapterTitle: 'Chemistry: Periodic Table & Chemical Bonds',
        chapterDescription: 'Atomic structure, ionic vs covalent bonding with molecular models.',
      ),
      const CurriculumPeriod(
        id: 'wed-p2',
        subjectCode: 'MATH-8',
        subjectName: 'Mathematics',
        subjectNameMy: 'သင်္ချာ',
        teacherName: 'Daw May Thu',
        room: 'Room 204',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 50),
        color: Color(0xFF3B82F6),
        chapterTitle: 'Algebra: Quadratic Expressions Factoring',
        chapterDescription: 'Factoring trinomials and cross-multiplication methods.',
      ),
      const CurriculumPeriod(
        id: 'wed-p3',
        subjectCode: 'MYAN-8',
        subjectName: 'Myanmar Language',
        subjectNameMy: 'မြန်မာစာ',
        teacherName: 'U Thein Win',
        room: 'Room 204',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 50),
        color: Color(0xFFF59E0B),
        chapterTitle: 'စကားရည်လုပွဲနှင့် စာစီစာကုံး သရုပ်ပြချက်',
        chapterDescription: 'ကျောင်းသားစကားရည်လုပွဲ ကျင်းပခြင်းနှင့် အပြန်အလှန် ဆွေးနွေးခြင်း။',
      ),
      const CurriculumPeriod(
        id: 'wed-p4',
        subjectCode: 'ENG-8',
        subjectName: 'English',
        subjectNameMy: 'အင်္ဂလိပ်စာ',
        teacherName: 'Daw Hla Hla',
        room: 'Language Lab',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 11, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 50),
        color: Color(0xFF8B5CF6),
        chapterTitle: 'Essay Writing: Cause and Effect',
        chapterDescription: 'Drafting structured 4-paragraph essays with logical transition words.',
      ),
      const CurriculumPeriod(
        id: 'wed-lunch',
        subjectCode: 'BREAK',
        subjectName: 'Lunch & Midday Break',
        subjectNameMy: 'နေ့လယ်စာနှင့် အနားယူချိန်',
        teacherName: 'Duty Teachers',
        room: 'School Canteen',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 12, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 0),
        color: Color(0xFF64748B),
        chapterTitle: 'Midday Meal & Recreation',
        chapterDescription: 'Lunch break and student activity session.',
      ),
      const CurriculumPeriod(
        id: 'wed-p5',
        subjectCode: 'SOC-8',
        subjectName: 'Social Studies',
        subjectNameMy: 'လူမှုရေး (သမိုင်း/ပထဝီ)',
        teacherName: 'Daw Ni Ni',
        room: 'Room 204',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 13, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 50),
        color: Color(0xFFEC4899),
        chapterTitle: 'Historical Monuments & Cultural Preservation',
        chapterDescription: 'Preserving national heritage sites and architectural legacy.',
      ),
      const CurriculumPeriod(
        id: 'wed-p6',
        subjectCode: 'COMP-8',
        subjectName: 'ICT & AI Skills',
        subjectNameMy: 'ကွန်ပျူတာနှင့် နည်းပညာ',
        teacherName: 'Daw Thida',
        room: 'Computer Lab A',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 14, minute: 50),
        color: Color(0xFF06B6D4),
        chapterTitle: 'Spreadsheet Formulas & Data Analysis',
        chapterDescription: 'Creating grade calculation formulas and chart visualizations.',
      ),
      const CurriculumPeriod(
        id: 'wed-p7',
        subjectCode: 'PE-8',
        subjectName: 'Physical Education / Sports',
        subjectNameMy: 'ကာယပညာ (အားကစား)',
        teacherName: 'Coach Min Khant',
        room: 'Sports Ground',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 15, minute: 0),
        endTime: TimeOfDay(hour: 15, minute: 50),
        color: Color(0xFFF97316),
        chapterTitle: 'Football & Traditional Chinlon (ခြင်းလုံး)',
        chapterDescription: 'Team coordination, footwork drills, and friendly house tournament.',
      ),

      // ==================== THURSDAY (Day 4) ====================
      const CurriculumPeriod(
        id: 'thu-p1',
        subjectCode: 'MATH-8',
        subjectName: 'Mathematics',
        subjectNameMy: 'သင်္ချာ',
        teacherName: 'Daw May Thu',
        room: 'Room 204',
        dayOfWeek: 4,
        startTime: TimeOfDay(hour: 8, minute: 0),
        endTime: TimeOfDay(hour: 8, minute: 50),
        color: Color(0xFF3B82F6),
        chapterTitle: 'Statistics: Mean, Median, Mode & Bar Charts',
        chapterDescription: 'Analyzing classroom survey data and creating frequency tables.',
      ),
      const CurriculumPeriod(
        id: 'thu-p2',
        subjectCode: 'ENG-8',
        subjectName: 'English',
        subjectNameMy: 'အင်္ဂလိပ်စာ',
        teacherName: 'Daw Hla Hla',
        room: 'Language Lab',
        dayOfWeek: 4,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 50),
        color: Color(0xFF8B5CF6),
        chapterTitle: 'Reading Literature: Short Stories',
        chapterDescription: 'Character development and theme analysis in classic folk tales.',
      ),
      const CurriculumPeriod(
        id: 'thu-p3',
        subjectCode: 'SCI-8',
        subjectName: 'General Science',
        subjectNameMy: 'အထွေထွေသိပ္ပံ',
        teacherName: 'U Aung Kyaw',
        room: 'Science Lab B',
        dayOfWeek: 4,
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 50),
        color: Color(0xFF10B981),
        chapterTitle: 'Environmental Studies: Renewable Energy',
        chapterDescription: 'Solar, wind, and micro-hydro generation principles in rural Myanmar.',
      ),
      const CurriculumPeriod(
        id: 'thu-p4',
        subjectCode: 'SOC-8',
        subjectName: 'Social Studies',
        subjectNameMy: 'လူမှုရေး (သမိုင်း/ပထဝီ)',
        teacherName: 'Daw Ni Ni',
        room: 'Room 204',
        dayOfWeek: 4,
        startTime: TimeOfDay(hour: 11, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 50),
        color: Color(0xFFEC4899),
        chapterTitle: 'Climate & Monsoon Patterns in Myanmar',
        chapterDescription: 'Seasonal agriculture, rain patterns, and environmental adaptations.',
      ),
      const CurriculumPeriod(
        id: 'thu-lunch',
        subjectCode: 'BREAK',
        subjectName: 'Lunch & Midday Break',
        subjectNameMy: 'နေ့လယ်စာနှင့် အနားယူချိန်',
        teacherName: 'Duty Teachers',
        room: 'School Canteen',
        dayOfWeek: 4,
        startTime: TimeOfDay(hour: 12, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 0),
        color: Color(0xFF64748B),
        chapterTitle: 'Midday Meal & Recreation',
        chapterDescription: 'Campus lunch and student leisure.',
      ),
      const CurriculumPeriod(
        id: 'thu-p5',
        subjectCode: 'MYAN-8',
        subjectName: 'Myanmar Language',
        subjectNameMy: 'မြန်မာစာ',
        teacherName: 'U Thein Win',
        room: 'Room 204',
        dayOfWeek: 4,
        startTime: TimeOfDay(hour: 13, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 50),
        color: Color(0xFFF59E0B),
        chapterTitle: 'စာစီစာကုံး သဒ္ဒါဖွဲ့ထုံးများ',
        chapterDescription: 'ဖွဲ့စည်းပုံကောင်းမွန်သော စာစီစာကုံး ရေးသားခြင်း နည်းပညာ။',
      ),
      const CurriculumPeriod(
        id: 'thu-p6',
        subjectCode: 'COMP-8',
        subjectName: 'ICT & AI Skills',
        subjectNameMy: 'ကွန်ပျူတာနှင့် နည်းပညာ',
        teacherName: 'Daw Thida',
        room: 'Computer Lab A',
        dayOfWeek: 4,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 14, minute: 50),
        color: Color(0xFF06B6D4),
        chapterTitle: 'Cyber Safety & Safe Browsing Practices',
        chapterDescription: 'Protecting passwords, avoiding phishing, and digital citizenship ethics.',
      ),
      const CurriculumPeriod(
        id: 'thu-p7',
        subjectCode: 'CLUB-8',
        subjectName: 'Youth Leadership & Red Cross',
        subjectNameMy: 'လူငယ်ခေါင်းဆောင်မှုနှင့် ကြက်ခြေနီ',
        teacherName: 'Daw Thida',
        room: 'Assembly Hall',
        dayOfWeek: 4,
        startTime: TimeOfDay(hour: 15, minute: 0),
        endTime: TimeOfDay(hour: 15, minute: 50),
        color: Color(0xFF8B5CF6),
        chapterTitle: 'First Aid Certification & Community Service',
        chapterDescription: 'CPR fundamentals, emergency bandages, and clean school campus drive.',
      ),

      // ==================== FRIDAY (Day 5) ====================
      const CurriculumPeriod(
        id: 'fri-p1',
        subjectCode: 'MATH-8',
        subjectName: 'Mathematics',
        subjectNameMy: 'သင်္ချာ',
        teacherName: 'Daw May Thu',
        room: 'Room 204',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 8, minute: 0),
        endTime: TimeOfDay(hour: 8, minute: 50),
        color: Color(0xFF3B82F6),
        chapterTitle: 'Weekly Math Problem Solving & Review',
        chapterDescription: 'Review of linear equations, factoring, and preparing for term assessment.',
      ),
      const CurriculumPeriod(
        id: 'fri-p2',
        subjectCode: 'SCI-8',
        subjectName: 'General Science',
        subjectNameMy: 'အထွေထွေသိပ္ပံ',
        teacherName: 'U Aung Kyaw',
        room: 'Science Lab B',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 50),
        color: Color(0xFF10B981),
        chapterTitle: 'Laboratory Experiments & Inquiry',
        chapterDescription: 'Hands-on scientific inquiry and recording lab observations accurately.',
      ),
      const CurriculumPeriod(
        id: 'fri-p3',
        subjectCode: 'MYAN-8',
        subjectName: 'Myanmar Language',
        subjectNameMy: 'မြန်မာစာ',
        teacherName: 'U Thein Win',
        room: 'Room 204',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 50),
        color: Color(0xFFF59E0B),
        chapterTitle: 'မြန်မာ့ယဉ်ကျေးမှုနှင့် စာပေသမိုင်း',
        chapterDescription: 'မြန်မာစာပေ သမိုင်းကြောင်းနှင့် ခေတ်အလိုက် စာဆိုတော်များ အတ္ထုပ္ပတ္တိ။',
      ),
      const CurriculumPeriod(
        id: 'fri-p4',
        subjectCode: 'ENG-8',
        subjectName: 'English',
        subjectNameMy: 'အင်္ဂလိပ်စာ',
        teacherName: 'Daw Hla Hla',
        room: 'Language Lab',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 11, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 50),
        color: Color(0xFF8B5CF6),
        chapterTitle: 'Grammar Quiz & Weekly Review',
        chapterDescription: 'Assessing tenses, prepositions, and reading speed.',
      ),
      const CurriculumPeriod(
        id: 'fri-lunch',
        subjectCode: 'BREAK',
        subjectName: 'Lunch & Midday Break',
        subjectNameMy: 'နေ့လယ်စာနှင့် အနားယူချိန်',
        teacherName: 'Duty Teachers',
        room: 'School Canteen',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 12, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 0),
        color: Color(0xFF64748B),
        chapterTitle: 'Midday Meal & Recreation',
        chapterDescription: 'Lunch break and campus recreation.',
      ),
      const CurriculumPeriod(
        id: 'fri-p5',
        subjectCode: 'PE-8',
        subjectName: 'Physical Education / Sports',
        subjectNameMy: 'ကာယပညာ (အားကစား)',
        teacherName: 'Coach Min Khant',
        room: 'Main Gymnasium',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 13, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 50),
        color: Color(0xFFF97316),
        chapterTitle: 'Inter-House Volleyball & Athletics',
        chapterDescription: 'Volleyball serving, spiking practice, and friendly matches.',
      ),
      const CurriculumPeriod(
        id: 'fri-p6',
        subjectCode: 'SOC-8',
        subjectName: 'Social Studies',
        subjectNameMy: 'လူမှုရေး (သမိုင်း/ပထဝီ)',
        teacherName: 'Daw Ni Ni',
        room: 'Room 204',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 14, minute: 50),
        color: Color(0xFFEC4899),
        chapterTitle: 'Global Geography & World Trade',
        chapterDescription: 'Trade partnerships between ASEAN member nations.',
      ),
      const CurriculumPeriod(
        id: 'fri-p7',
        subjectCode: 'ART-8',
        subjectName: 'Life Skills & Art',
        subjectNameMy: 'ဘဝတွက်တာ ကျွမ်းကျင်စရာနှင့် ပန်းချီ',
        teacherName: 'Daw Khin Mar',
        room: 'Art Studio',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 15, minute: 0),
        endTime: TimeOfDay(hour: 15, minute: 50),
        color: Color(0xFF6366F1),
        chapterTitle: 'Art Exhibition & Creative Showcase',
        chapterDescription: 'Displaying student paintings and collaborative craft work.',
      ),

      // ==================== SUNDAY (Day 7) ====================
      const CurriculumPeriod(
        id: 'sun-p1',
        subjectCode: 'STUDY-8',
        subjectName: 'Mathematics Revision',
        subjectNameMy: 'သင်္ချာ သီးသန့်လေ့လာမှု',
        teacherName: 'Self-Study / Library',
        room: 'Digital Library',
        dayOfWeek: 7,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 50),
        color: Color(0xFF3B82F6),
        chapterTitle: 'Algebra & Geometry Self-Paced Exercises',
        chapterDescription: 'Reviewing practice problem sets and past examination papers.',
      ),
      const CurriculumPeriod(
        id: 'sun-p2',
        subjectCode: 'READ-8',
        subjectName: 'English Reading Circle',
        subjectNameMy: 'အင်္ဂလိပ်စာ ဖတ်ဝိုင်း',
        teacherName: 'Peer Study Group',
        room: 'Library Room A',
        dayOfWeek: 7,
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 50),
        color: Color(0xFF8B5CF6),
        chapterTitle: 'Novel Reading: Southeast Asian Folktales',
        chapterDescription: 'Reading comprehension and vocabulary flashcards.',
      ),
    ];
  }

  /// Morning Section Split (08:00 AM - 12:30 PM)
  static List<CurriculumPeriod> _getMorningShiftCurriculum() {
    return [
      for (int day = 1; day <= 5; day++) ...[
        CurriculumPeriod(
          id: 'm-d$day-p1',
          subjectCode: 'MATH-8',
          subjectName: 'Mathematics',
          subjectNameMy: 'သင်္ချာ',
          teacherName: 'Daw May Thu',
          room: 'Room 204',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 8, minute: 0),
          endTime: const TimeOfDay(hour: 8, minute: 50),
          color: const Color(0xFF3B82F6),
          chapterTitle: 'Linear Equations & Algebra',
          chapterDescription: 'Morning shift intensive mathematics curriculum.',
          shiftSection: 'morning',
        ),
        CurriculumPeriod(
          id: 'm-d$day-p2',
          subjectCode: 'MYAN-8',
          subjectName: 'Myanmar Language',
          subjectNameMy: 'မြန်မာစာ',
          teacherName: 'U Thein Win',
          room: 'Room 204',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 8, minute: 55),
          endTime: const TimeOfDay(hour: 9, minute: 45),
          color: const Color(0xFFF59E0B),
          chapterTitle: 'ကဗျာနှင့် စကားပြေ ရသခံစားမှု',
          chapterDescription: 'သဒ္ဒါနှင့် စာစီစာကုံး လေ့ကျင့်ချက်။',
          shiftSection: 'morning',
        ),
        CurriculumPeriod(
          id: 'm-d$day-p3',
          subjectCode: 'ENG-8',
          subjectName: 'English',
          subjectNameMy: 'အင်္ဂလိပ်စာ',
          teacherName: 'Daw Hla Hla',
          room: 'Language Lab',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 9, minute: 55),
          endTime: const TimeOfDay(hour: 10, minute: 45),
          color: const Color(0xFF8B5CF6),
          chapterTitle: 'Grammar & Reading Comprehension',
          chapterDescription: 'Active vocabulary and conversational English.',
          shiftSection: 'morning',
        ),
        CurriculumPeriod(
          id: 'm-d$day-p4',
          subjectCode: 'SCI-8',
          subjectName: 'General Science',
          subjectNameMy: 'အထွေထွေသိပ္ပံ',
          teacherName: 'U Aung Kyaw',
          room: 'Science Lab B',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 10, minute: 50),
          endTime: const TimeOfDay(hour: 11, minute: 40),
          color: const Color(0xFF10B981),
          chapterTitle: 'Forces, Biology & Chemistry',
          chapterDescription: 'Experimental science syllabus.',
          shiftSection: 'morning',
        ),
        CurriculumPeriod(
          id: 'm-d$day-p5',
          subjectCode: 'SOC-8',
          subjectName: 'Social Studies & ICT',
          subjectNameMy: 'လူမှုရေးနှင့် ကွန်ပျူတာ',
          teacherName: 'Daw Ni Ni / Daw Thida',
          room: 'Computer Lab A',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 11, minute: 45),
          endTime: const TimeOfDay(hour: 12, minute: 30),
          color: const Color(0xFF06B6D4),
          chapterTitle: 'Geography & Digital Skills',
          chapterDescription: 'Southeast Asian geography and computer literacy.',
          shiftSection: 'morning',
        ),
      ],
    ];
  }

  /// Afternoon Section Split (12:30 PM - 04:30 PM)
  static List<CurriculumPeriod> _getAfternoonShiftCurriculum() {
    return [
      for (int day = 1; day <= 5; day++) ...[
        CurriculumPeriod(
          id: 'a-d$day-p1',
          subjectCode: 'MYAN-8',
          subjectName: 'Myanmar Language',
          subjectNameMy: 'မြန်မာစာ',
          teacherName: 'U Thein Win',
          room: 'Room 204',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 12, minute: 30),
          endTime: const TimeOfDay(hour: 13, minute: 15),
          color: const Color(0xFFF59E0B),
          chapterTitle: 'သဒ္ဒါနှင့် စာပေအနုပညာ',
          chapterDescription: 'Afternoon shift curriculum.',
          shiftSection: 'afternoon',
        ),
        CurriculumPeriod(
          id: 'a-d$day-p2',
          subjectCode: 'MATH-8',
          subjectName: 'Mathematics',
          subjectNameMy: 'သင်္ချာ',
          teacherName: 'Daw May Thu',
          room: 'Room 204',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 13, minute: 20),
          endTime: const TimeOfDay(hour: 14, minute: 5),
          color: const Color(0xFF3B82F6),
          chapterTitle: 'Geometry & Equations',
          chapterDescription: 'Mathematics problem solving.',
          shiftSection: 'afternoon',
        ),
        CurriculumPeriod(
          id: 'a-d$day-p3',
          subjectCode: 'ENG-8',
          subjectName: 'English',
          subjectNameMy: 'အင်္ဂလိပ်စာ',
          teacherName: 'Daw Hla Hla',
          room: 'Language Lab',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 14, minute: 15),
          endTime: const TimeOfDay(hour: 15, minute: 0),
          color: const Color(0xFF8B5CF6),
          chapterTitle: 'Comprehension & Vocabulary',
          chapterDescription: 'Language skills development.',
          shiftSection: 'afternoon',
        ),
        CurriculumPeriod(
          id: 'a-d$day-p4',
          subjectCode: 'SCI-8',
          subjectName: 'General Science',
          subjectNameMy: 'အထွေထွေသိပ္ပံ',
          teacherName: 'U Aung Kyaw',
          room: 'Science Lab B',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 15, minute: 5),
          endTime: const TimeOfDay(hour: 15, minute: 50),
          color: const Color(0xFF10B981),
          chapterTitle: 'Physics & Chemistry Experiments',
          chapterDescription: 'Scientific inquiry.',
          shiftSection: 'afternoon',
        ),
        CurriculumPeriod(
          id: 'a-d$day-p5',
          subjectCode: 'PE-8',
          subjectName: 'Physical Ed & Social Studies',
          subjectNameMy: 'ကာယနှင့် လူမှုရေး',
          teacherName: 'Coach Min Khant',
          room: 'Main Gymnasium',
          dayOfWeek: day,
          startTime: const TimeOfDay(hour: 15, minute: 55),
          endTime: const TimeOfDay(hour: 16, minute: 30),
          color: const Color(0xFFF97316),
          chapterTitle: 'Physical Fitness & Athletics',
          chapterDescription: 'Team coordination and athletic training.',
          shiftSection: 'afternoon',
        ),
      ],
    ];
  }
}
