import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/classroom_sync_screen.dart';
import '../../screens/notifications_screen.dart';
import 'student_wallet_screen.dart';
import 'student_under13_screen.dart';

/// Dedicated Student Shell Screen & UI container.
/// Hosts Student-specific workflows:
/// 1. Self-Sovereign Identity (W3C VC) digital student wallet (Age >= 13)
/// 2. Under-13 Protection Policy gate (Age < 13 directed to Guardian)
/// 3. Classroom Attendance & Whole-Child competency reports
/// 4. School announcements and alerts
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

  void _handleSignOut() async {
    await StorageService.clearSession();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Safety Gate: Enforce under 13 policy
    if (_studentUser != null && _studentUser!.isUnder13) {
      return StudentUnder13Screen(
        user: _studentUser!,
        onSwitchToGuardian: widget.onSwitchRole,
      );
    }

    final studentName = _studentUser?.fullName.isNotEmpty == true
        ? _studentUser!.fullName
        : 'Alice Walker (Grade 8)';
    final gradeText = _studentUser?.gradeLevel ?? 'Grade 8';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.indigo.shade800,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    radius: 18,
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                studentName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade600,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'STUDENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$gradeText • Student ID Wallet',
                          style: TextStyle(
                            color: Colors.indigo.shade100,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.switch_account_outlined, color: Colors.white, size: 22),
                    tooltip: 'Switch Role (RBAC)',
                    onPressed: widget.onSwitchRole,
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                    tooltip: 'Sign Out',
                    onPressed: _handleSignOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          StudentWalletScreen(onSwitchMode: widget.onSwitchRole ?? () {}),
          ClassroomSyncScreen(onSwitchMode: widget.onSwitchRole),
          NotificationsScreen(onSwitchMode: widget.onSwitchRole),
        ],
      ),
      bottomNavigationBar: _buildStudentBottomNav(),
    );
  }

  Widget _buildStudentBottomNav() {
    final items = [
      _StudentNavItem(
        icon: Icons.wallet_outlined,
        activeIcon: Icons.wallet,
        label: 'ID Card',
        subtitle: 'W3C VC',
      ),
      _StudentNavItem(
        icon: Icons.hub_outlined,
        activeIcon: Icons.hub,
        label: 'Whole-Child',
        subtitle: 'Attendance',
      ),
      _StudentNavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: 'Notices',
        subtitle: 'Alerts',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: List.generate(items.length, (idx) {
              final item = items[idx];
              final isSelected = _currentIndex == idx;
              final color = isSelected ? Colors.indigo.shade800 : AppTheme.textMuted;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => _onTabTapped(idx),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.indigo.withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.indigo.withValues(alpha: 0.25) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isSelected ? item.activeIcon : item.icon, color: color, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.subtitle,
                                  style: TextStyle(
                                    color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade500,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
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
