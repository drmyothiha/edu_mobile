import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/login_screen.dart';

class StudentUnder13Screen extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onSwitchToGuardian;

  const StudentUnder13Screen({
    super.key,
    required this.user,
    this.onSwitchToGuardian,
  });

  @override
  Widget build(BuildContext context) {
    final age = user.age ?? 10;
    final guardianName = user.guardianName ?? 'Daw Khin Mar (ဒေါ်ခင်မာ)';
    final schoolName = user.schoolName ?? 'Basic Education School';
    final gradeLevel = user.gradeLevel ?? 'Grade 5-A';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        title: const Text('Child Safety Policy'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await StorageService.clearSession();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shield Badge
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.shade400, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade200.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    size: 48,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 20),

                // Main Title
                const Text(
                  'Account Managed by Guardian',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'မိဘ / အုပ်ထိန်းသူမှ စီမံခန့်ခွဲသော အကောင့်ဖြစ်ပါသည်',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 20),

                // Explanation Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Child Digital Safety Standard (COPPA)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Students under 13 years of age ($age years old) do not operate independent mobile accounts. '
                        'To safeguard student privacy and wellbeing, all academic progress, attendance records, and '
                        'W3C Digital ID passes are delegated to and viewed through your registered Guardian account.',
                        style: TextStyle(fontSize: 12, height: 1.45, color: Colors.grey.shade800),
                      ),
                      const Divider(height: 20),
                      Text(
                        'အသက် ၁၃ နှစ်အောက် ကလေးသူငယ်များ၏ အချက်အလက်လုံခြုံရေးအတွက် ကျောင်းသားကတ်ပြား (Digital ID)၊ '
                        'ကျောင်းခေါ်ချိန်နှင့် ဘက်စုံဖွံ့ဖြိုးမှုအစီရင်ခံစာများကို မိဘ/အုပ်ထိန်းသူ၏ ဖုန်းမှသာ လုံခြုံစွာ ကြည့်ရှုနိုင်ပါသည်။',
                        style: TextStyle(fontSize: 11, height: 1.45, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Student & Guardian Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.person, 'Student Name', user.fullName.isNotEmpty ? user.fullName : 'Ma Su Myat Noe'),
                      const Divider(height: 14),
                      _buildInfoRow(Icons.school, 'Class & Grade', gradeLevel),
                      const Divider(height: 14),
                      _buildInfoRow(Icons.cake, 'Age / Status', '$age years old (Under 13 Policy)'),
                      const Divider(height: 14),
                      _buildInfoRow(Icons.location_city, 'School', schoolName),
                      const Divider(height: 14),
                      _buildInfoRow(Icons.family_restroom, 'Registered Guardian', guardianName),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Primary CTA: Switch to Guardian Login
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (onSwitchToGuardian != null) {
                        onSwitchToGuardian!();
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen(preselectedRole: AppUserRole.guardian)),
                        );
                      }
                    },
                    icon: const Icon(Icons.family_restroom),
                    label: const Text('Switch to Guardian Account (မိဘအကောင့်သို့)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary CTA: Sign Out
                TextButton.icon(
                  onPressed: () async {
                    await StorageService.clearSession();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out / Use Another Account'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMain),
          ),
        ),
      ],
    );
  }
}
