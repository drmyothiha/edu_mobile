import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../widgets/update_dialog.dart';
import '../../theme/app_theme.dart';
import 'kiosk_pairing_scanner_screen.dart';

class AdminShellScreen extends StatefulWidget {
  final VoidCallback onSwitchRole;

  const AdminShellScreen({super.key, required this.onSwitchRole});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await StorageService.getUser();
    setState(() {
      _user = user;
    });
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KioskPairingScannerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminName = _user?['full_name'] ?? 'ကျောင်းအုပ်ကြီး';
    final schoolName = _user?['school_name'] ?? _user?['school_name_my'] ?? 'အခြေခံပညာကျောင်း';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schoolName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Text(
              'ကျောင်းစီမံခန့်ခွဲမှု • School Admin Portal',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update_alt, color: AppTheme.primary),
            tooltip: 'Check for Updates (ဆော့ဖ်ဝဲလ် အဆင့်မြှင့်တင်မည်)',
            onPressed: () => UpdateDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: AppTheme.primary),
            tooltip: 'Switch Role (ကဏ္ဍပြောင်းရန်)',
            onPressed: widget.onSwitchRole,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textMuted),
            tooltip: 'Logout',
            onPressed: () async {
              await StorageService.clearSession();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Welcome Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF312E81), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'ကျောင်းအုပ်ကြီး${_user?['school_code'] != null ? ' • ${_user!['school_code']}' : ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Kiosk Pairing Card (Primary Action)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.indigo.shade100, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withValues(alpha: 0.06),
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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'ဂိတ်စက် ချိတ်ဆက်ခြင်း (Kiosk Setup)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Entrance PWA Provisioning & Offline Sync',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Text(
                          'Option A',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ကျောင်းဝင်ပေါက် ကွန်ပျူတာ (PWA) ကို ပထမဆုံးအကြိမ် ဖွင့်ချိန်တွင် ပေါ်လာသော QR ကုဒ်ကို ဤမိုဘိုင်းဖုန်းဖြင့် စကင်ဖတ်၍ စက်အား မိမိကျောင်းနှင့် အပြီးအပိုင် ချိတ်ဆက်ပေးပါ။',
                    style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text(
                        'ဂိတ်စက် QR စကင်ဖတ်မည် (Scan to Pair)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _openScanner,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // School Stats Overview
            const Text(
              'ကျောင်းဆိုင်ရာ အချက်အလက်များ (Overview)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('ကျောင်းသား စုစုပေါင်း', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        SizedBox(height: 6),
                        Text('၃၃ ဦး', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        SizedBox(height: 2),
                        Text('KG မှ Grade 12 အထိ', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('ဖွင့်လှစ်ထားသော ဂိတ်', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        SizedBox(height: 6),
                        Text('၁ ခု', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                        SizedBox(height: 2),
                        Text('Gate-01 (အဝင်ပေါက်)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Software Update Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.system_update_alt, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Software Update (စနစ်အဆင့်မြှင့်တင်ခြင်း)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Check and install latest mobile build from CI/CD',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => UpdateDialog.show(context),
                    child: const Text('Check'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
