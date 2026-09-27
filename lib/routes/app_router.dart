import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/storage_service.dart';
import '../services/jwt_decoder.dart';
import '../theme/app_theme.dart';
import '../teacher/routes/teacher_routes.dart';
import '../teacher/screens/teacher_shell_screen.dart';
import '../parents/routes/parent_routes.dart';
import '../parents/screens/parents_shell_screen.dart';
import '../students/routes/student_routes.dart';
import '../students/screens/student_shell_screen.dart';
import '../students/screens/student_under13_screen.dart';
import '../screens/login_screen.dart';
import '../screens/student_wallet_screen.dart';
import '../screens/gate_verifier_screen.dart';
import '../screens/classroom_sync_screen.dart';
import '../screens/notifications_screen.dart';
import 'app_routes.dart';

/// Central application router coordinating namespace-specific role routes.
class AppRouter {
  /// Top-level route generator.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? AppRoutes.initial;

    // 1. Teacher namespace route delegation (/teacher/...)
    if (name.startsWith(TeacherRoutes.prefix)) {
      final route = TeacherRoutes.generateRoute(settings);
      if (route != null) return route;
    }

    // 2. Parents namespace route delegation (/parents/...)
    if (name.startsWith(ParentRoutes.prefix)) {
      final route = ParentRoutes.generateRoute(settings);
      if (route != null) return route;
    }

    // 3. Students namespace route delegation (/students/...)
    if (name.startsWith(StudentRoutes.prefix)) {
      final route = StudentRoutes.generateRoute(settings);
      if (route != null) return route;
    }

    // 4. Standalone Login route
    if (name == AppRoutes.login) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const LoginScreen(),
      );
    }

    // 5. Default root dispatcher: resolves JWT role and dispatches to appropriate role UI
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const RoleDispatcherScreen(),
    );
  }
}

/// Root dispatcher widget that reads JWT claims and routes to the role's UI.
class RoleDispatcherScreen extends StatefulWidget {
  const RoleDispatcherScreen({super.key});

  @override
  State<RoleDispatcherScreen> createState() => _RoleDispatcherScreenState();
}

class _RoleDispatcherScreenState extends State<RoleDispatcherScreen> {
  AppUser? _currentUser;
  AppUserRole? _jwtRole;
  bool _isLoading = true;
  int _unauthTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _resolveAuthRole();
  }

  Future<void> _resolveAuthRole() async {
    final token = await StorageService.getToken();
    final jwtRole = JwtDecoder.getRole(token);
    final user = await StorageService.getCurrentUser();
    final mode = await StorageService.getAppMode();

    if (mounted) {
      setState(() {
        _jwtRole = jwtRole ?? user?.role;
        _currentUser = user;
        _isLoading = false;
        if (user == null && jwtRole == null) {
          _unauthTabIndex = mode == 'inspector' ? 1 : 0;
        }
      });
    }
  }

  void _showRoleSwitchDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Switch Mobile Role (RBAC)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Text(
                  'Select a profile to experience the role-specific mobile interface:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                _buildRoleDialogTile(
                  icon: Icons.school,
                  color: Colors.teal,
                  title: 'Teacher (ဆရာ/ဆရာမ)',
                  subtitle: 'Gate kiosk verifier • Grade 5-A sync • Parent notices',
                  onTap: () => _switchToRole(
                    role: AppUserRole.teacher,
                    fullName: 'Daw Thida (ဒေါ်သီတာ)',
                    email: 'teacher.smith@edu.local',
                  ),
                ),
                const SizedBox(height: 8),
                _buildRoleDialogTile(
                  icon: Icons.family_restroom,
                  color: AppTheme.primary,
                  title: 'Guardian (မိဘ / အုပ်ထိန်းသူ)',
                  subtitle: 'Supervise children under 13 • View ID passes & progress',
                  onTap: () => _switchToRole(
                    role: AppUserRole.guardian,
                    fullName: 'Daw Khin Mar (ဒေါ်ခင်မာ)',
                    email: 'parent.clark@edu.local',
                  ),
                ),
                const SizedBox(height: 8),
                _buildRoleDialogTile(
                  icon: Icons.person,
                  color: Colors.indigo,
                  title: 'Student >=13 (Alice Walker, Age 14)',
                  subtitle: 'Personal W3C VC wallet • Grade 8 attendance',
                  onTap: () => _switchToRole(
                    role: AppUserRole.student,
                    fullName: 'Alice Walker',
                    email: 'student.alice@edu.local',
                    gradeLevel: 'Grade 8',
                    age: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRoleDialogTile(
                  icon: Icons.shield,
                  color: Colors.amber.shade800,
                  title: 'Student <13 (Ma Su Myat Noe, Age 10)',
                  subtitle: 'Under-13 safety policy • Managed via Guardian',
                  onTap: () => _switchToRole(
                    role: AppUserRole.student,
                    fullName: 'Ma Su Myat Noe (မစုမြတ်နိုး)',
                    email: 'su.g5@intaing.edu.local',
                    gradeLevel: 'Grade 5-A',
                    age: 10,
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.apps),
                      label: const Text('All-in-One Multi View'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await StorageService.clearSession();
                        _resolveAuthRole();
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In / Custom'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final res = await Navigator.pushNamed<bool>(context, AppRoutes.login);
                        if (res == true) {
                          _resolveAuthRole();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleDialogTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 18,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _switchToRole({
    required AppUserRole role,
    required String fullName,
    required String email,
    String? gradeLevel,
    int? age,
  }) async {
    Navigator.of(context).pop();
    DateTime? dob;
    if (age != null) {
      dob = DateTime.now().subtract(Duration(days: (age * 365.25).round()));
    }

    final user = <String, dynamic>{
      'id': 'd0000000-0000-0000-0000-000000000001',
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'school_name': 'Basic Education High School Intaing',
    };
    if (gradeLevel != null) {
      user['grade_level'] = gradeLevel;
    }
    if (dob != null) {
      user['date_of_birth'] = dob.toIso8601String();
    }
    if (role == AppUserRole.student && (age ?? 14) < 13) {
      user['guardian_name'] = 'Daw Khin Mar (ဒေါ်ခင်မာ)';
    }

    // Generate valid 3-part mock JWT with encoded role
    final token = JwtDecoder.generateMockToken(
      role: role.name,
      email: email,
      userId: user['id'] as String,
    );

    await StorageService.saveSession(token: token, user: user);
    await _resolveAuthRole();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final effectiveRole = _jwtRole ?? _currentUser?.role;

    // 1. Under-13 Student Guard
    if (effectiveRole == AppUserRole.student && _currentUser != null && _currentUser!.isUnder13) {
      return StudentUnder13Screen(
        user: _currentUser!,
        onSwitchToGuardian: () => _switchToRole(
          role: AppUserRole.guardian,
          fullName: 'Daw Khin Mar (ဒေါ်ခင်မာ)',
          email: 'parent.clark@edu.local',
        ),
      );
    }

    // 2. Route directly to Role-specific UI
    switch (effectiveRole) {
      case AppUserRole.teacher:
        return TeacherShellScreen(onSwitchRole: _showRoleSwitchDialog);
      case AppUserRole.guardian:
        return ParentsShellScreen(onSwitchRole: _showRoleSwitchDialog);
      case AppUserRole.student:
        return StudentShellScreen(onSwitchRole: _showRoleSwitchDialog);
      case null:
        // 3. Unauthenticated / Multi-view overview
        return _buildUnauthenticatedMultiView();
    }
  }

  Widget _buildUnauthenticatedMultiView() {
    final navItems = [
      _MultiNavItem(Icons.wallet_outlined, Icons.wallet, 'ID Card', 'W3C VC'),
      _MultiNavItem(Icons.qr_code_scanner_outlined, Icons.qr_code_scanner, 'Kiosk', 'Auto Scan'),
      _MultiNavItem(Icons.hub_outlined, Icons.hub, 'Whole-Child', 'Grade 5-A'),
      _MultiNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Parent Chat', 'Alerts & Chat'),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _unauthTabIndex,
        children: [
          StudentWalletScreen(onSwitchMode: _showRoleSwitchDialog),
          GateVerifierScreen(onSwitchMode: _showRoleSwitchDialog),
          ClassroomSyncScreen(onSwitchMode: _showRoleSwitchDialog),
          NotificationsScreen(onSwitchMode: _showRoleSwitchDialog),
        ],
      ),
      bottomNavigationBar: Container(
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
              children: List.generate(navItems.length, (idx) {
                final item = navItems[idx];
                final isSelected = _unauthTabIndex == idx;
                final color = isSelected ? AppTheme.primary : AppTheme.textMuted;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => setState(() => _unauthTabIndex = idx),
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
      ),
    );
  }
}

class _MultiNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String subtitle;

  _MultiNavItem(this.icon, this.activeIcon, this.label, this.subtitle);
}
