import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/update_dialog.dart';
import '../../screens/notifications_screen.dart';
import 'guardian_dashboard_screen.dart';
import 'parent_conversations_screen.dart';

/// Dedicated Parents / Guardian Shell Screen & UI container.
/// Hosts Parent-specific workflows:
/// 1. Children Overview (Name, Age, Grade & Report)
/// 2. Parent-Teacher Conversations (Separate tab, not tied to students)
/// 3. School & Class Notices
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
    _currentIndex = widget.initialTab.clamp(0, 2);
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

    final parentName = _guardianUser?.fullName ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primary,
        elevation: 1,
        title: Text(
          parentName.isNotEmpty ? parentName : 'Guardian Portal',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildSidebar(context, parentName),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          GuardianDashboardScreen(
            onNavigateTab: (idx) => _onTabTapped(idx),
            onSwitchRole: widget.onSwitchRole,
          ),
          const ParentConversationsScreen(),
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
      ),
      _ParentNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Teacher Chat',
      ),
      _ParentNavItem(
        icon: Icons.notifications_none,
        activeIcon: Icons.notifications,
        label: 'Notices',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: color,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
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

  Widget _buildSidebar(BuildContext context, String parentName) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.primary,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: const Icon(
                Icons.family_restroom,
                color: Colors.white,
                size: 36,
              ),
            ),
            accountName: Text(
              parentName.isNotEmpty
                  ? parentName
                  : 'Guardian (မိဘ/အုပ်ထိန်းသူ)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              _guardianUser?.email.isNotEmpty == true
                  ? _guardianUser!.email
                  : 'မိဘ / အုပ်ထိန်းသူ • Guardian Portal',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.system_update_alt,
              color: AppTheme.primary,
            ),
            title: const Text('Check for Updates'),
            subtitle: const Text('အပ်ဒိတ် စစ်ဆေးမည်'),
            onTap: () {
              Navigator.pop(context);
              UpdateDialog.show(context);
            },
          ),
          const Divider(),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Sign Out (အကောင့်ထွက်မည်)',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _handleSignOut();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ParentNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _ParentNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
