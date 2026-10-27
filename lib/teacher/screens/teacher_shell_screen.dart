import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/update_dialog.dart';
import 'gate_verifier_screen.dart';
import 'classroom_sync_screen.dart';
import 'scan_history_screen.dart';
import 'teacher_conversations_screen.dart';

/// Dedicated Teacher Shell Screen & UI container.
/// Hosts Teacher-specific workflows:
/// 1. NFC / QR Entrance Kiosk Verifier
/// 2. Whole-Child Grade 5-A Offline Sync & 5-Pillars
/// 3. Direct Parent & Department Notices & Chat
class TeacherShellScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback? onSwitchRole;

  const TeacherShellScreen({
    super.key,
    this.initialTab = 0,
    this.onSwitchRole,
  });

  @override
  State<TeacherShellScreen> createState() => _TeacherShellScreenState();
}

class _TeacherShellScreenState extends State<TeacherShellScreen> {
  late int _currentIndex;
  AppUser? _teacherUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _loadTeacherProfile();
  }

  Future<void> _loadTeacherProfile() async {
    final user = await StorageService.getCurrentUser();
    if (mounted) {
      setState(() {
        _teacherUser = user;
        _isLoading = false;
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openScanHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanHistoryScreen()),
    );
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

    final teacherName = _teacherUser?.fullName.isNotEmpty == true
        ? _teacherUser!.fullName
        : 'ဆရာ/ဆရာမ';
    final schoolName = _teacherUser?.schoolName ?? 'အခြေခံပညာကျောင်း';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.teal.shade800,
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
                    backgroundColor: Colors.teal.shade100,
                    radius: 18,
                    child: const Icon(Icons.school, color: Colors.teal, size: 20),
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
                                teacherName,
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
                                color: Colors.teal.shade600,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TEACHER',
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
                          schoolName,
                          style: TextStyle(
                            color: Colors.teal.shade100,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.system_update_alt, color: Colors.white, size: 21),
                    tooltip: 'Check for Updates (အပ်ဒိတ် စစ်ဆေးမည်)',
                    onPressed: () => UpdateDialog.show(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white, size: 22),
                    tooltip: 'Verification History',
                    onPressed: _openScanHistory,
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
          GateVerifierScreen(onSwitchMode: widget.onSwitchRole ?? () {}),
          ClassroomSyncScreen(onSwitchMode: widget.onSwitchRole),
          const TeacherConversationsScreen(),
        ],
      ),
      bottomNavigationBar: _buildTeacherBottomNav(),
    );
  }

  Widget _buildTeacherBottomNav() {
    final items = [
      _TeacherNavItem(
        icon: Icons.qr_code_scanner_outlined,
        activeIcon: Icons.qr_code_scanner,
        label: 'Kiosk',
        subtitle: 'Auto Scan',
      ),
      _TeacherNavItem(
        icon: Icons.hub_outlined,
        activeIcon: Icons.hub,
        label: 'Whole-Child',
        subtitle: 'Grade 5-A',
      ),
      _TeacherNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Messages',
        subtitle: 'Notices',
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
              final color = isSelected ? Colors.teal.shade800 : AppTheme.textMuted;

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
                        color: isSelected ? Colors.teal.withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.teal.withValues(alpha: 0.25) : Colors.transparent,
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
                                    color: isSelected ? Colors.teal.shade600 : Colors.grey.shade500,
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

class _TeacherNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String subtitle;

  _TeacherNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.subtitle,
  });
}
