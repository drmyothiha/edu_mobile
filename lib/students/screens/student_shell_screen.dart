import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../screens/notifications_screen.dart';
import 'student_curriculum_calendar_screen.dart';
import 'student_wallet_screen.dart';
import 'student_under13_screen.dart';
import 'student_settings_screen.dart';

/// Dedicated Student Shell Screen & UI container.
/// Optimized for maximum space by removing the top bar.
/// Hosts Student workflows:
/// 1st Tab: Curriculum timetable in week-view calendar interface (Week row at top)
/// 2nd Tab: Digital Student ID Card (W3C VC Wallet for age >= 13)
/// 3rd Tab: School announcements & real-time notices
/// 4th Tab: Settings page (Standards profile, settings, logout, about, etc.)
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _loadStudentProfile();
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
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4C8DFF))),
      );
    }

    // Safety Gate: Enforce under 13 policy
    if (_studentUser != null && _studentUser!.isUnder13) {
      return StudentUnder13Screen(
        user: _studentUser!,
        onSwitchToGuardian: widget.onSwitchRole,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      // Top bar removed to save maximum vertical space for student curriculum & tools
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 1st Tab: Curriculum Week View Calendar App (starts directly with Week row at top)
          StudentCurriculumCalendarScreen(onSwitchMode: widget.onSwitchRole),
          // 2nd Tab: Digital Student ID Card (W3C VC Wallet)
          StudentWalletScreen(onSwitchMode: widget.onSwitchRole ?? () {}),
          // 3rd Tab: School Notices & Announcements
          NotificationsScreen(onSwitchMode: widget.onSwitchRole),
          // 4th Tab: Settings Page (Standards profile, settings, logout, about, etc.)
          StudentSettingsScreen(onSwitchRole: widget.onSwitchRole),
        ],
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
        color: const Color(0xFF0F1015), // Dark bottom bar matching calendar
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
              final color = isSelected ? const Color(0xFF4C8DFF) : const Color(0xFF6B7280);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => _onTabTapped(idx),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4C8DFF).withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF4C8DFF).withValues(alpha: 0.35) : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isSelected ? item.activeIcon : item.icon, color: color, size: 20),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFF555966),
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
