import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/update_dialog.dart';
import '../../screens/student_wallet_screen.dart';
import '../../screens/notifications_screen.dart';
import 'guardian_dashboard_screen.dart';

/// Dedicated Parents / Guardian Shell Screen & UI container.
/// Hosts Parent-specific workflows:
/// 1. Children Multi-Child Overview & 5-Pillar Growth Dashboard
/// 2. Verifiable Credential W3C Digital Pass for Under-13 Children
/// 3. Direct Teacher Chat & School Announcement Broadcasts
class ParentsShellScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback? onSwitchRole;

  const ParentsShellScreen({
    super.key,
    this.initialTab = 0,
    this.onSwitchRole,
  });

  @override
  State<ParentsShellScreen> createState() => _ParentsShellScreenState();
}

class _ParentsShellScreenState extends State<ParentsShellScreen> {
  late int _currentIndex;
  AppUser? _guardianUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _loadGuardianProfile();
  }

  Future<void> _loadGuardianProfile() async {
    final user = await StorageService.getCurrentUser();
    if (mounted) {
      setState(() {
        _guardianUser = user;
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

    final parentName = _guardianUser?.fullName.isNotEmpty == true
        ? _guardianUser!.fullName
        : 'Daw Khin Mar (ဒေါ်ခင်မာ)';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primary,
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
                    child: const Icon(Icons.family_restroom, color: Colors.white, size: 20),
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
                                parentName,
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
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'GUARDIAN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'မိဘ / အုပ်ထိန်းသူ • Guardian Portal',
                          style: TextStyle(
                            color: Colors.white70,
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
          GuardianDashboardScreen(
            onNavigateTab: (idx) => _onTabTapped(idx),
            onSwitchRole: widget.onSwitchRole,
          ),
          StudentWalletScreen(
            onSwitchMode: widget.onSwitchRole ?? () {},
            isGuardianView: true,
            childName: 'Ma Su Myat Noe',
            gradeLevel: 'Grade 5-A',
          ),
          NotificationsScreen(onSwitchMode: widget.onSwitchRole),
        ],
      ),
      bottomNavigationBar: _buildParentsBottomNav(),
    );
  }

  Widget _buildParentsBottomNav() {
    final items = [
      _ParentNavItem(
        icon: Icons.family_restroom_outlined,
        activeIcon: Icons.family_restroom,
        label: 'Children',
        subtitle: 'Dashboard',
      ),
      _ParentNavItem(
        icon: Icons.wallet_outlined,
        activeIcon: Icons.wallet,
        label: 'Child Pass',
        subtitle: 'W3C VC',
      ),
      _ParentNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Teacher Chat',
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
              final color = isSelected ? AppTheme.primary : AppTheme.textMuted;

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
                        color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
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
                                    color: isSelected ? AppTheme.primaryLight : Colors.grey.shade500,
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

class _ParentNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String subtitle;

  _ParentNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.subtitle,
  });
}
