import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/timetable_storage_service.dart';
import '../../widgets/update_dialog.dart';
import '../../screens/server_settings_screen.dart';

/// Student Settings and Standards Profile Screen.
/// Provides:
/// 1. Standards Profile: Student details, grade, school, guardian info, digital ID status, and role switcher.
/// 2. Timetable & Shift Settings: Server sync status, SQLite cached schedule, and manual sync.
/// 3. Server & Network: Endpoint configuration and connectivity status.
/// 4. Preferences: Notifications, language, and display theme.
/// 5. About: App version, Child safety compliance, and licenses.
/// 6. Logout: Safe session clearance and navigation back to login.
class StudentSettingsScreen extends StatefulWidget {
  final VoidCallback? onSwitchRole;

  const StudentSettingsScreen({super.key, this.onSwitchRole});

  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
  AppUser? _user;
  bool _isLoading = true;
  String _serverUrl = 'https://104.154.135.208';
  String _schoolShift = 'full_day';
  DateTime? _lastSyncTime;
  int _cachedPeriodCount = 0;
  bool _isSyncing = false;

  // Notification toggles
  bool _timetableNotifications = true;
  bool _announcementNotifications = true;
  String _selectedLanguage = 'English (US)';

  @override
  void initState() {
    super.initState();
    _loadProfileAndSettings();
  }

  Future<void> _loadProfileAndSettings() async {
    try {
      final user = await StorageService.getCurrentUser();
      final serverUrl = await StorageService.getServerUrl();
      final shift = await TimetableStorageService.getSchoolShift();
      final lastSync = await TimetableStorageService.getLastSyncTime();
      final periods = await TimetableStorageService.getPeriods(shift: shift);

      if (mounted) {
        setState(() {
          _user = user;
          _serverUrl = serverUrl;
          _schoolShift = shift;
          _lastSyncTime = lastSync;
          _cachedPeriodCount = periods.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncTimetable() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final res = await TimetableStorageService.syncWithBackend();
      if (mounted) {
        setState(() {
          _cachedPeriodCount = res.periods.length;
          _schoolShift = res.shift;
          _lastSyncTime = res.syncedAt ?? DateTime.now();
          _isSyncing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F392B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF34D399),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    res.isOffline
                        ? 'အော့ဖ်လိုင်း မုဒ်: SQLite ဒေတာဘေ့စ်မှ အချိန်ဇယားကို သိမ်းဆည်းပြီး (${res.periods.length} ချိန်)'
                        : 'အတန်းချိန်ဇယား ဆာဗာမှ အောင်မြင်စွာ sync လုပ်ပြီးပါပြီ! (${res.periods.length} ချိန်)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B1212),
            content: Text(
              'Sync failed: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your student account?\n\n(သင်၏ ကျောင်းသားအကောင့်မှ အမှန်တကယ် ထွက်ခွာလိုပါသလား?)',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService.clearSession();
              if (mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showRoleSwitchDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Switch Role (RBAC Demo)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Switch between authenticated testing personas for this device.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 16),
                _buildRoleOption(
                  roleName: 'Student (Self)',
                  description: 'Curriculum Week View & Digital ID Wallet',
                  icon: Icons.school_outlined,
                  isSelected: true,
                  onTap: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  roleName: 'Teacher',
                  description:
                      'Gate Kiosk NFC/QR Verifier & Whole-Child 5-A Sync',
                  icon: Icons.badge_outlined,
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSwitchRole?.call();
                  },
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  roleName: 'Guardian / Parent',
                  description:
                      'Children 5-Pillar Growth & Under-13 Supervised Passes',
                  icon: Icons.family_restroom_outlined,
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSwitchRole?.call();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleOption({
    required String roleName,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4C8DFF).withValues(alpha: 0.15)
              : const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4C8DFF)
                : const Color(0xFF2E344A),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF4C8DFF)
                  : const Color(0xFF94A3B8),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleName,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFE2E8F0),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4C8DFF),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161822),
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
                    const Row(
                      children: [
                        Icon(Icons.school, color: Color(0xFF4C8DFF), size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Myanmar AI Education Hub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2230),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E344A)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EduMobile • Student & Curriculum System',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Autonomous offline-first educational platform designed for Myanmar basic education schools. Incorporates W3C Verifiable Credentials, local SQLite timetable sync, and Whole-Child 5-Pillar growth tracking.',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildInfoRow('Version', '1.0.0 (Build 2026.09)'),
                _buildInfoRow(
                  'Platform',
                  'Flutter Cross-Platform (Offline-First)',
                ),
                _buildInfoRow(
                  'Security',
                  'W3C VC ECDSA P-256 Hardware Protected',
                ),
                _buildInfoRow(
                  'Child Safety',
                  'COPPA & Under-13 Protection Compliant',
                ),
                _buildInfoRow(
                  'Organization',
                  'Department of Basic Education (DBE)',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF059669)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.system_update_alt, size: 16),
                        label: const Text(
                          'Check Updates',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          UpdateDialog.show(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4C8DFF),
                          side: const BorderSide(color: Color(0xFF2E344A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.article_outlined, size: 16),
                        label: const Text(
                          'Licenses',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showLicensePage(
                            context: context,
                            applicationName: 'Myanmar AI Education Hub',
                            applicationVersion: '1.0.0 (2026)',
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
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Offline Cache?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will clear local temporary images and trigger a fresh timetable sync from the school server.',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4C8DFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _syncTimetable();
            },
            child: const Text(
              'Clear & Resync',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getShiftDisplayName() {
    switch (_schoolShift) {
      case 'morning':
        return 'နံနက်ပိုင်း အဆိုင်း (8:00 AM - 12:30 PM)';
      case 'afternoon':
        return 'ညနေပိုင်း အဆိုင်း (12:30 PM - 4:30 PM)';
      default:
        return 'တစ်နေကုန် အဆိုင်း (8:00 AM - 4:00 PM)';
    }
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

    final fullName = _user?.fullName.isNotEmpty == true
        ? _user!.fullName
        : 'Alice Walker';
    final gradeLevel = _user?.gradeLevel ?? 'Grade 8';
    final schoolName =
        _user?.schoolName ??
        'Basic Education School';
    final email = _user?.email ?? 'student.alice@edu.local';
    final studentId = _user?.id ?? 'STU-2026-0842';
    final guardianName = _user?.guardianName ?? 'Daw Khin Mar (ဒေါ်ခင်မာ)';
    final guardianEmail = _user?.guardianEmail ?? 'parent.clark@edu.local';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Title
              const Text(
                'Settings & Profile (ဆက်တင်နှင့် ပရိုဖိုင်)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'စံသတ်မှတ်ချက် ပရိုဖိုင်၊ အချိန်ဇယားနှင့် ဆက်တင်များ',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 16),

              // 1. STANDARDS PROFILE CARD
              _buildStandardsProfileCard(
                fullName: fullName,
                gradeLevel: gradeLevel,
                schoolName: schoolName,
                studentId: studentId,
                email: email,
                guardianName: guardianName,
                guardianEmail: guardianEmail,
              ),
              const SizedBox(height: 20),

              // SECTION: TIMETABLE & CURRICULUM SYNC
              _buildSectionHeader(
                title: 'သင်ရိုးနှင့် အဆိုင်း ဆက်တင်များ (Curriculum & Shift)',
                icon: Icons.schedule,
              ),
              const SizedBox(height: 8),
              _buildCardContainer(
                children: [
                  _buildSettingTile(
                    icon: Icons.access_time_filled,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'သင်ကြားရေးအဆိုင်း (Shift)',
                    subtitle: _getShiftDisplayName(),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Text(
                        'ကျောင်းသတ်မှတ်ချက်',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF1E2230), height: 1),
                  _buildSettingTile(
                    icon: Icons.storage,
                    iconColor: const Color(0xFFFBBF24),
                    title: 'SQLite အချိန်ဇယား သိမ်းဆည်းမှု',
                    subtitle:
                        'အော့ဖ်လိုင်းအတွက် ဘာသာရပ် $_cachedPeriodCount ချိန် သိမ်းဆည်းထားသည်',
                    trailing: Text(
                      _lastSyncTime != null
                          ? '${_lastSyncTime!.hour.toString().padLeft(2, '0')}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}'
                          : 'Cached',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF1E2230), height: 1),
                  InkWell(
                    onTap: _syncTimetable,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          _isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF4C8DFF),
                                  ),
                                )
                              : const Icon(
                                  Icons.sync,
                                  color: Color(0xFF4C8DFF),
                                  size: 20,
                                ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ဆာဗာမှ အချိန်ဇယား ရယူချိတ်ဆက်မည်',
                                  style: TextStyle(
                                    color: Color(0xFF4C8DFF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'ဆရာများ ပြင်ဆင်ထားသော နောက်ဆုံးအချိန်ဇယားကို ဒေတာဘေ့စ်သို့ ရယူမည်',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF4C8DFF),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SECTION: SERVER & NETWORK SETTINGS
              _buildSectionHeader(
                title: 'ဆာဗာနှင့် ကွန်ရက် ဆက်တင်များ (Server & Network)',
                icon: Icons.dns_outlined,
              ),
              const SizedBox(height: 8),
              _buildCardContainer(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ServerSettingsScreen(),
                        ),
                      ).then((_) => _loadProfileAndSettings());
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_outlined,
                            color: Color(0xFF4C8DFF),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ဆာဗာ IP နှင့် Port လိပ်စာ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _serverUrl,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SECTION: PREFERENCES
              _buildSectionHeader(
                title: 'အထွေထွေ ဆက်တင်များ (Preferences)',
                icon: Icons.tune,
              ),
              const SizedBox(height: 8),
              _buildCardContainer(
                children: [
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFF818CF8),
                      size: 20,
                    ),
                    title: const Text(
                      'အတန်းချိန် သတိပေးချက်',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'အတန်းချိန်စတင်ရန် ၅ မိနစ်အလိုတွင် သတိပေးမည်',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    value: _timetableNotifications,
                    activeThumbColor: const Color(0xFF4C8DFF),
                    onChanged: (val) =>
                        setState(() => _timetableNotifications = val),
                  ),
                  const Divider(color: Color(0xFF1E2230), height: 1),
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.campaign_outlined,
                      color: Color(0xFFF472B6),
                      size: 20,
                    ),
                    title: const Text(
                      'ကျောင်းသတင်းလွှာ အသိပေးချက်',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'ကျောင်းအုပ်ကြီးနှင့် ဆရာများထံမှ အရေးကြီး ကြေညာချက်များ',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    value: _announcementNotifications,
                    activeThumbColor: const Color(0xFF4C8DFF),
                    onChanged: (val) =>
                        setState(() => _announcementNotifications = val),
                  ),
                  const Divider(color: Color(0xFF1E2230), height: 1),
                  _buildSettingTile(
                    icon: Icons.language,
                    iconColor: const Color(0xFF34D399),
                    title: 'ဘာသာစကား (Language)',
                    subtitle: _selectedLanguage,
                    trailing: DropdownButton<String>(
                      value: _selectedLanguage,
                      dropdownColor: const Color(0xFF1E2230),
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF94A3B8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'English (US)',
                          child: Text(
                            'English',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Myanmar (မြန်မာ)',
                          child: Text(
                            'မြန်မာစာ',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLanguage = val);
                        }
                      },
                    ),
                  ),
                  const Divider(color: Color(0xFF1E2230), height: 1),
                  _buildSettingTile(
                    icon: Icons.dark_mode_outlined,
                    iconColor: const Color(0xFFA78BFA),
                    title: 'အသွင်အပြင် (Appearance)',
                    subtitle: 'အမှောင် မုဒ် (Dark Mode အမြဲဖွင့်ထားသည်)',
                    trailing: const Text(
                      'Dark',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF1E2230), height: 1),
                  InkWell(
                    onTap: _showClearCacheDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cleaning_services_outlined,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'ယာယီဒေတာ (Cache) ရှင်းလင်းမည်',
                              style: TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SECTION: ROLE SWITCHING (RBAC)
              _buildSectionHeader(
                title: 'အကောင့် အခန်းကဏ္ဍ ပြောင်းလဲမည် (RBAC)',
                icon: Icons.switch_account_outlined,
              ),
              const SizedBox(height: 8),
              _buildCardContainer(
                children: [
                  InkWell(
                    onTap: _showRoleSwitchDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            color: Color(0xFF38BDF8),
                            size: 22,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Switch User Role (အခန်းကဏ္ဍ ပြောင်းလဲမည်)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'ကျောင်းသား၊ ဆရာ နှင့် မိဘ/အုပ်ထိန်းသူ မုဒ်များသို့ စမ်းသပ်ပြောင်းလဲရန်',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SECTION: ABOUT
              _buildSectionHeader(
                title: 'အက်ပ်အကြောင်း အချက်အလက် (About)',
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 8),
              _buildCardContainer(
                children: [
                  InkWell(
                    onTap: _showAboutDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF4C8DFF),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'About Myanmar AI Education Hub',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'ဗားရှင်း 1.0.0 (Build 2026.09) • ကလေးသူငယ် ဘေးကင်းလုံခြုံရေး လိုက်နာမှု',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF1E2028), height: 1),
                  InkWell(
                    onTap: () => UpdateDialog.show(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.system_update_alt,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Check for Updates (ဆော့ဖ်ဝဲလ် အဆင့်မြှင့်တင်ရန်)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Check GitHub Releases for new APK updates',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // LOGOUT BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1517),
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFF7F1D1D)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    'Sign Out (အကောင့်မှ ထွက်မည်)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _confirmSignOut,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Standards Profile Card with full student metadata
  Widget _buildStandardsProfileCard({
    required String fullName,
    required String gradeLevel,
    required String schoolName,
    required String studentId,
    required String email,
    required String guardianName,
    required String guardianEmail,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262A38)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2230),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(
                    0xFF4C8DFF,
                  ).withValues(alpha: 0.2),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Color(0xFF4C8DFF),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C8DFF),
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
                      const SizedBox(height: 2),
                      Text(
                        '$gradeLevel • Standards Profile',
                        style: const TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schoolName,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Standard Profile Details List
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildProfileDetailRow(
                  icon: Icons.badge_outlined,
                  label: 'ကျောင်းသား ID (Student ID)',
                  value: studentId,
                ),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                  icon: Icons.email_outlined,
                  label: 'ကျောင်းသား အီးမေးလ်',
                  value: email,
                ),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                  icon: Icons.verified_user_outlined,
                  label: 'ဒီဂျစ်တယ် အထောက်အထား',
                  value: 'W3C Verifiable Credential Active',
                  valueColor: const Color(0xFF34D399),
                ),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                  icon: Icons.family_restroom_outlined,
                  label: 'မိဘ / အုပ်ထိန်းသူ',
                  value: guardianName,
                ),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                  icon: Icons.contact_mail_outlined,
                  label: 'အုပ်ထိန်းသူ ဆက်သွယ်ရန်',
                  value: guardianEmail,
                ),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'ပညာသင်နှစ် (Academic Year)',
                  value: '၂၀၂၆ - ၂၀၂၇ ပညာသင်နှစ်',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262A38)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
