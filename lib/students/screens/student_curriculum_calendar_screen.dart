import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/curriculum_period.dart';
import '../../services/timetable_storage_service.dart';
import '../../services/sse_notification_service.dart';

/// Horizontally Swipable Week View Calendar Screen for Student Curriculum.
///
/// Features:
/// 1. Upper week days (MON-SUN) are horizontally swipable to navigate prev/next weeks.
/// 2. Starts from 8:00 AM to 4:00 PM (8 AM to 4 PM) school teaching schedule.
/// 3. Realistic single-subject schedule: each hour slot (e.g. 09:00 - 10:00) contains
///    strictly ONE single subject for the selected day.
/// 4. Supports school teaching shifts (Full Day 8 AM - 4 PM, Morning Section 8 AM - 12:30 PM,
///    Afternoon Section 12:30 PM - 4:30 PM) synced from backend and stored in local SQLite cache.
/// 5. Bottom 4 tabs (Year, Month, Week, Day) are removed; Week view is the sole default.
class StudentCurriculumCalendarScreen extends StatefulWidget {
  final VoidCallback? onSwitchMode;

  const StudentCurriculumCalendarScreen({super.key, this.onSwitchMode});

  @override
  State<StudentCurriculumCalendarScreen> createState() => _StudentCurriculumCalendarScreenState();
}

class _StudentCurriculumCalendarScreenState extends State<StudentCurriculumCalendarScreen> {
  late DateTime _selectedDate;
  late DateTime _displayedWeekMonday;
  late PageController _weekPageController;
  int _currentWeekPageIndex = 1000; // Large number for bidirectional infinite swipe

  List<CurriculumPeriod> _periods = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isWeekGridView = false; // Toggle between Today's single-subject timetable & 7-day grid
  StreamSubscription? _sseSub;
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;

  // School timetable range: 8:00 AM to 4:00 PM
  static const int _startHour = 8;
  static const int _endHour = 16;
  static const double _hourHeight = 68.0;
  static const double _timeColumnWidth = 56.0;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    // Anchor to today's date (or 2026-09-27)
    final now = DateTime.now();
    _selectedDate = DateTime(2026, 9, 27); // Default to current school calendar date
    if (now.year >= 2026) {
      _selectedDate = now;
    }

    _displayedWeekMonday = _getMondayOfWeek(_selectedDate);
    _weekPageController = PageController(initialPage: _currentWeekPageIndex);
    _loadTimetableData();

    // Listen to real-time notification events when teacher publishes updated timetable
    _sseSub = SseNotificationService.onNotification.listen((notif) {
      if (notif.type == 'timetable_published') {
        _performSync(showToast: true);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _sseSub?.cancel();
    _weekPageController.dispose();
    super.dispose();
  }

  DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  int _getWeekOfYear(DateTime date) {
    final firstJan = DateTime(date.year, 1, 1);
    final days = date.difference(firstJan).inDays;
    return ((days + firstJan.weekday) / 7).ceil();
  }

  Future<void> _loadTimetableData() async {
    // 1. Immediately load local SQLite cached data (0ms latency, offline ready)
    final shift = await TimetableStorageService.getSchoolShift();
    final periods = await TimetableStorageService.getPeriods(shift: shift);

    if (mounted) {
      setState(() {
        _periods = periods;
        _isLoading = false;
      });
    }

    // 2. Perform silent online sync in the background
    _performSync(showToast: false);
  }

  Future<void> _performSync({bool showToast = true}) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
    });

    try {
      final res = await TimetableStorageService.syncWithBackend();
      if (mounted) {
        setState(() {
          _periods = res.periods;
          _isSyncing = false;
        });

        if (showToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: res.isOffline ? const Color(0xFF1E2230) : const Color(0xFF0F392B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
              content: Row(
                children: [
                  Icon(
                    res.isOffline ? Icons.storage : Icons.check_circle,
                    color: res.isOffline ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      res.isOffline
                          ? 'အော့ဖ်လိုင်း မုဒ်: SQLite ဒေတာဘေ့စ်မှ အချိန်ဇယားကို ပြသထားပါသည် (${res.periods.length} ချိန်)'
                          : 'အတန်းချိန်ဇယား ဆာဗာမှ အောင်မြင်စွာ sync လုပ်ပြီးပါပြီ! (SQLite Cache: ${res.periods.length} ချိန်)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }


  void _onWeekPageChanged(int index) {
    final diff = index - _currentWeekPageIndex;
    setState(() {
      _currentWeekPageIndex = index;
      _displayedWeekMonday = _displayedWeekMonday.add(Duration(days: diff * 7));
      // Keep selected date aligned within the newly displayed week
      _selectedDate = _displayedWeekMonday.add(Duration(days: (_selectedDate.weekday - 1).clamp(0, 6)));
    });
  }

  void _goToPreviousWeek() {
    _weekPageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  void _goToNextWeek() {
    _weekPageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  void _goToToday() {
    final targetMonday = _getMondayOfWeek(DateTime(2026, 9, 27));
    setState(() {
      _selectedDate = DateTime(2026, 9, 27);
      _displayedWeekMonday = targetMonday;
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDate = day;
    });
  }

  void _showPeriodDetailSheet(CurriculumPeriod period) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetContext, scrollController) {
            return SafeArea(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 12,
                      height: 48,
                      decoration: BoxDecoration(
                        color: period.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                period.subjectName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: period.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  period.subjectCode,
                                  style: TextStyle(
                                    color: period.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            period.subjectNameMy,
                            style: TextStyle(
                              color: period.color.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF262A38)),
                const SizedBox(height: 12),

                // Time, Room, and Teacher
                _buildModalInfoRow(
                  icon: Icons.access_time,
                  title: 'အချိန်နှင့် အတန်းချိန်',
                  subtitle: '${_getDayName(period.dayOfWeek)} • ${period.timeRangeString}',
                ),
                const SizedBox(height: 10),
                _buildModalInfoRow(
                  icon: Icons.person_outline,
                  title: 'သင်ကြားသူ ဆရာ/ဆရာမ',
                  subtitle: period.teacherName,
                ),
                const SizedBox(height: 10),
                _buildModalInfoRow(
                  icon: Icons.room_outlined,
                  title: 'စာသင်ခန်း တည်နေရာ',
                  subtitle: 'အခန်း ${period.room}',
                ),
                const SizedBox(height: 14),

                // Syllabus & Chapter
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2230),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2E344A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book, color: period.color, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'သင်ရိုးမာတိကာ အကြောင်းအရာ',
                            style: TextStyle(
                              color: period.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        period.chapterTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        period.chapterDescription,
                        style: const TextStyle(
                          color: Color(0xFF9EA3B5),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                if (period.homework != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.assignment_outlined, color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'အိမ်စာနှင့် လေ့ကျင့်ခန်း',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                period.homework!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: period.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('သင်ခန်းစာ မှတ်စုများ (PDF)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${period.subjectNameMy.isNotEmpty ? period.subjectNameMy : period.subjectName} အတွက် သင်ခန်းစာမှတ်စုများ ရယူပြီးပါပြီ')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);
}

  Widget _buildModalInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Color(0xFF868C9E), fontSize: 10, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'တနင်္လာနေ့';
      case 2:
        return 'အင်္ဂါနေ့';
      case 3:
        return 'ဗုဒ္ဓဟူးနေ့';
      case 4:
        return 'ကြာသပတေးနေ့';
      case 5:
        return 'သောကြာနေ့';
      case 6:
        return 'စနေနေ့';
      case 7:
        return 'တနင်္ဂနွေနေ့';
      default:
        return '';
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark theme
      body: SafeArea(
        child: Column(
          children: [
            _buildSwipableWeekStrip(),
            const Divider(color: Color(0xFF1E2028), height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4C8DFF)))
                  : RefreshIndicator(
                      color: const Color(0xFF4C8DFF),
                      backgroundColor: const Color(0xFF161822),
                      onRefresh: () => _performSync(showToast: true),
                      child: _isWeekGridView
                          ? _build7DayGridView()
                          : _buildDayTimeline8AMto4PM(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Horizontally swipable week days strip showing previous or next week schedules
  Widget _buildSwipableWeekStrip() {
    return SizedBox(
      height: 84,
      child: PageView.builder(
        controller: _weekPageController,
        onPageChanged: _onWeekPageChanged,
        itemBuilder: (context, pageIndex) {
          final pageOffset = pageIndex - _currentWeekPageIndex;
          final mondayForPage = _displayedWeekMonday.add(Duration(days: pageOffset * 7));
          final weekNum = _getWeekOfYear(mondayForPage);

          return Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                // Week number badge on the far left (e.g. 39) with prev/next week taps
                GestureDetector(
                  onTap: _goToPreviousWeek,
                  onLongPress: _goToToday,
                  onDoubleTap: () => setState(() => _isWeekGridView = !_isWeekGridView),
                  child: Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$weekNum',
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(Icons.chevron_left, color: Color(0xFF475569), size: 14),
                      ],
                    ),
                  ),
                ),
                // 7 Days: MON to SUN
                ...List.generate(7, (i) {
                  final dayDate = mondayForPage.add(Duration(days: i));
                  final isSelected = dayDate.year == _selectedDate.year &&
                      dayDate.month == _selectedDate.month &&
                      dayDate.day == _selectedDate.day;
                  final isSaturday = i == 5;
                  final isToday = dayDate.year == 2026 && dayDate.month == 9 && dayDate.day == 27;
                  final dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDay(dayDate),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayNames[i],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isSaturday ? const Color(0xFF6B8EFF) : const Color(0xFF8E929E)),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4C8DFF) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isToday && !isSelected
                                  ? Border.all(color: const Color(0xFF4C8DFF).withValues(alpha: 0.5))
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${dayDate.day}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isSaturday ? const Color(0xFF6B8EFF) : Colors.white),
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${dayDate.day}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white70 : const Color(0xFF555966),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // Next week chevron
                GestureDetector(
                  onTap: _goToNextWeek,
                  child: Container(
                    width: 20,
                    alignment: Alignment.center,
                    child: const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Primary View: Realistic Daily Schedule from 8:00 AM to 4:00 PM
  /// Showing strictly ONE single subject per hourly time block!
  Widget _buildDayTimeline8AMto4PM() {
    final dayOfWeek = _selectedDate.weekday; // 1 = Mon ... 7 = Sun
    final dayPeriods = _periods.where((p) => p.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) => a.startHourDecimal.compareTo(b.startHourDecimal));

    final totalHours = _endHour - _startHour; // 16 - 8 = 8 hours (8 AM to 4 PM)

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF4C8DFF), size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_getDayName(dayOfWeek)} အချိန်ဇယား',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2230),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${dayPeriods.length} ချိန် သင်ကြားမည်',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current Time Indicator Bar
          _buildLiveTimeIndicatorBar(),
          const SizedBox(height: 12),

          // Time Slots from 8:00 AM to 4:00 PM
          ...List.generate(totalHours, (index) {
            final hour = _startHour + index; // 8, 9, 10, 11, 12, 13, 14, 15
            final nextHour = hour + 1;

            // Find the single scheduled subject matching this hour slot
            final matchingPeriod = dayPeriods.where((p) {
              return p.startTime.hour == hour || (p.startHourDecimal >= hour && p.startHourDecimal < nextHour);
            }).firstOrNull;

            return _buildHourlySlotRow(
              hour: hour,
              nextHour: nextHour,
              period: matchingPeriod,
            );
          }),
        ],
      ),
    );
  }

  /// Live current time indicator bar displaying actual dynamic time
  Widget _buildLiveTimeIndicatorBar() {
    final hourStr = _currentTime.hour.toString().padLeft(2, '0');
    final minStr = _currentTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minStr';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12141D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF202534)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935), // Red badge matching screenshot
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1.5,
              color: const Color(0xFFE53935),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'လက်ရှိအချိန်',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Single-Subject Hourly Row: displays ONE subject between hour and nextHour
  Widget _buildHourlySlotRow({
    required int hour,
    required int nextHour,
    required CurriculumPeriod? period,
  }) {
    final hourLabel = '${hour.toString().padLeft(2, '0')}:00';
    final nextHourLabel = '${nextHour.toString().padLeft(2, '0')}:00';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Time Column
          SizedBox(
            width: _timeColumnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hourLabel,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  nextHourLabel,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          // Right Curriculum Card (Single Subject!)
          Expanded(
            child: period == null
                ? Container(
                    height: _hourHeight - 16,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F121C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E2230)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hour == 12 ? Icons.restaurant_outlined : Icons.self_improvement_outlined,
                          color: const Color(0xFF475569),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          hour == 12 ? 'နေ့လယ်စာနှင့် အနားယူချိန်' : 'ကိုယ်ပိုင် လေ့လာချိန် / စာကြည့်ချိန်',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : InkWell(
                    onTap: () => _showPeriodDetailSheet(period),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: period.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: period.color.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 38,
                            decoration: BoxDecoration(
                              color: period.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        period.subjectNameMy.isNotEmpty ? period.subjectNameMy : period.subjectName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: period.color.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        period.timeRangeString,
                                        style: TextStyle(
                                          color: period.color,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${period.subjectName} (${period.subjectCode}) • ${period.teacherName} • ${period.room.startsWith('Room ') ? 'အခန်း ${period.room.replaceFirst('Room ', '')}' : 'အခန်း ${period.room}'}',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  period.chapterTitle,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: period.color.withValues(alpha: 0.6), size: 16),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 7-Day Grid View (8 AM - 4 PM) with columns for all days
  Widget _build7DayGridView() {
    final totalHours = _endHour - _startHour;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayColumnWidth = ((constraints.maxWidth - _timeColumnWidth) / 7).clamp(46.0, 85.0);
        final totalWidth = _timeColumnWidth + (dayColumnWidth * 7);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth < constraints.maxWidth ? constraints.maxWidth : totalWidth,
            child: SingleChildScrollView(
              child: SizedBox(
                height: totalHours * _hourHeight,
                child: Stack(
                  children: [
                    // Grid lines
                    ...List.generate(totalHours + 1, (i) {
                      return Positioned(
                        left: _timeColumnWidth,
                        right: 0,
                        top: i * _hourHeight,
                        child: Container(height: 1, color: const Color(0xFF161822)),
                      );
                    }),
                    ...List.generate(8, (i) {
                      return Positioned(
                        left: _timeColumnWidth + (i * dayColumnWidth),
                        top: 0,
                        bottom: 0,
                        child: Container(width: 1, color: const Color(0xFF14161F)),
                      );
                    }),

                    // Time labels on the left (08:00 to 16:00)
                    ...List.generate(totalHours, (i) {
                      final h = _startHour + i;
                      return Positioned(
                        top: (i * _hourHeight) + 2,
                        left: 8,
                        child: Text(
                          '${h.toString().padLeft(2, '0')}:00',
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      );
                    }),

                    // Period cards in grid
                    ..._periods.map((period) {
                      final dayIndex = period.dayOfWeek - 1;
                      if (dayIndex < 0 || dayIndex > 6) return const SizedBox.shrink();
                      final start = (period.startHourDecimal - _startHour) * _hourHeight;
                      final h = (period.durationHours * _hourHeight) - 2;

                      if (start < 0 || start >= totalHours * _hourHeight) return const SizedBox.shrink();

                      return Positioned(
                        left: _timeColumnWidth + (dayIndex * dayColumnWidth) + 1,
                        top: start,
                        width: dayColumnWidth - 2,
                        height: h.clamp(20.0, _hourHeight * 2),
                        child: GestureDetector(
                          onTap: () => _showPeriodDetailSheet(period),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            decoration: BoxDecoration(
                              color: period.color.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  period.subjectName,
                                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  period.room,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 7.5),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
