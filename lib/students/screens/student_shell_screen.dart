import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/nfc_auth_service.dart';
import '../../screens/notifications_screen.dart';
import 'student_curriculum_calendar_screen.dart';
import 'student_wallet_screen.dart';
import 'student_settings_screen.dart';

/// Dedicated Student Shell Screen & UI container.
/// Features:
/// 1. Contactless NFC Hot-Swap Listener: Allows siblings to swap cards anytime without logging out.
/// 2. User-Context Aware Curriculum: Each sibling sees their own grade-specific timetable.
/// 3. Read-only Under-13 Access: Enables younger students to view timetable & notices via smartcard.
class StudentShellScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback? onSwitchRole;

  const StudentShellScreen({
    super.key,
    this.initialTab = 0,
    this.onSwitchRole,
  });

  @override
  State<StudentShellScreen> createState() => _StudentShellScreenState();
}

class _StudentShellScreenState extends State<StudentShellScreen> {
  late int _currentIndex;
  AppUser? _studentUser;
  bool _isLoading = true;
  bool _isNfcActive = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _loadStudentProfile();
    _startHotSwapNfcListener();
  }

  @override
  void dispose() {
    _stopHotSwapNfcListener();
    super.dispose();
  }

  Future<void> _loadStudentProfile() async {
    final user = await StorageService.getCurrentUser();
    if (mounted) {
      setState(() {
        _studentUser = user;
        _isLoading = false;
      });
    }
  }

  /// Begins listening for sibling NFC card tap in the background while inside the portal
  Future<void> _startHotSwapNfcListener() async {
    final status = await NfcAuthService.checkNfcStatus();
    if (status != NfcStatus.available) {
      if (mounted) setState(() => _isNfcActive = false);
      return;
    }

    if (mounted) setState(() => _isNfcActive = true);

    await NfcAuthService.startStudentCardSession(
      onCardTapped: (cardId, rawPayload) async {
        if (!mounted) return;
        final result = await NfcAuthService.authenticateWithCard(
          rawPayload: rawPayload,
          hardwareId: cardId,
        );
        if (!mounted) return;
        _handleCardSwapped(result);
      },
      onError: (_) {
        if (mounted) setState(() => _isNfcActive = false);
      },
    );
  }

  Future<void> _stopHotSwapNfcListener() async {
    _isNfcActive = false;
    await NfcAuthService.stopSession();
  }

  void _handleCardSwapped(NfcAuthResult result) {
    if (result.success && result.user != null) {
      final newUser = result.user!;
      if (newUser.id == _studentUser?.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card confirmed for ${newUser.fullName}'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _studentUser = newUser;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Colors.cyanAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Switched account to ${newUser.fullName} (${newUser.gradeLevel ?? "Student"})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F2027),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // Re-engage NFC listener for next tap
    _startHotSwapNfcListener();
  }

  void _showSiblingSwitchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1015),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.contactless_rounded,
                      color: Colors.cyanAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sibling Card Hot-Swap (ကတ်ပြားလဲလှယ်ခြင်း)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Touch any student card to phone back to switch profile instantly',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF1E2028)),
              const SizedBox(height: 8),
              const Text(
                'Instant Test Cards (စမ်းသပ်ရန် ကတ်ပြားများ):',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.amber.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      icon: const Icon(Icons.badge, color: Colors.amber, size: 16),
                      label: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Maung Aung',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'KG (Kindergarten)',
                            style: TextStyle(color: Colors.amber, fontSize: 9),
                          ),
                        ],
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final res = await NfcAuthService.simulateDemoCardLogin(
                          studentName: 'Maung Aung Kaung Myat',
                          rollNumber: 'ROLL-KG-001',
                          gradeLevel: 'Kindergarten (KG)',
                        );
                        _handleCardSwapped(res);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.purple.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      icon: const Icon(
                        Icons.school,
                        color: Colors.purpleAccent,
                        size: 16,
                      ),
                      label: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ma Su Myat Noe',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Grade 5-A',
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final res = await NfcAuthService.simulateDemoCardLogin(
                          studentName: 'Ma Su Myat Noe (မစုမြတ်နိုး)',
                          rollNumber: 'ROLL-G5-001',
                          gradeLevel: 'Grade 5-A',
                        );
                        _handleCardSwapped(res);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4C8DFF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Sibling Active Context Bar
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF11141E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2538)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _isNfcActive
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.cyan.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.contactless_rounded,
                      size: 14,
                      color: _isNfcActive
                          ? Colors.greenAccent
                          : Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _studentUser?.fullName ?? 'Student',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_studentUser?.gradeLevel ?? "Student"} • Tap card to swap',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _showSiblingSwitchSheet,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            size: 14,
                            color: Colors.cyanAccent,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Swap',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Content keyed by student ID so each student gets their own independent state
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  // 1st Tab: Curriculum Week View Calendar App
                  StudentCurriculumCalendarScreen(
                    key: ValueKey('calendar_${_studentUser?.id}'),
                    onSwitchMode: widget.onSwitchRole,
                  ),
                  // 2nd Tab: Digital Student ID Card (W3C VC Wallet)
                  StudentWalletScreen(
                    key: ValueKey('wallet_${_studentUser?.id}'),
                    onSwitchMode: widget.onSwitchRole ?? () {},
                  ),
                  // 3rd Tab: School Notices & Announcements
                  NotificationsScreen(
                    key: ValueKey('notif_${_studentUser?.id}'),
                    onSwitchMode: widget.onSwitchRole,
                  ),
                  // 4th Tab: Settings Page
                  StudentSettingsScreen(
                    key: ValueKey('settings_${_studentUser?.id}'),
                    onSwitchRole: widget.onSwitchRole,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildStudentBottomNav(),
    );
  }

  Widget _buildStudentBottomNav() {
    final items = [
      _StudentNavItem(
        icon: Icons.calendar_view_week_outlined,
        activeIcon: Icons.calendar_view_week,
        label: 'အချိန်ဇယား',
        subtitle: 'အပတ်စဉ်',
      ),
      _StudentNavItem(
        icon: Icons.wallet_outlined,
        activeIcon: Icons.wallet,
        label: 'ကတ်ပြား',
        subtitle: 'ဒီဂျစ်တယ်',
      ),
      _StudentNavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: 'သတင်းလွှာ',
        subtitle: 'အသိပေးချက်',
      ),
      _StudentNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'ဆက်တင်',
        subtitle: 'ပရိုဖိုင်',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1015),
        border: const Border(top: BorderSide(color: Color(0xFF1E2028))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: List.generate(items.length, (idx) {
              final item = items[idx];
              final isSelected = _currentIndex == idx;
              final color = isSelected
                  ? const Color(0xFF4C8DFF)
                  : const Color(0xFF6B7280);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => _onTabTapped(idx),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4C8DFF).withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4C8DFF).withValues(alpha: 0.35)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: color,
                            size: 20,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF555966),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _StudentNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String subtitle;

  _StudentNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.subtitle,
  });
}
