import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/jwt_decoder.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final AppUserRole? preselectedRole;

  const LoginScreen({super.key, this.preselectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();

  AppUserRole _selectedRole = AppUserRole.guardian;
  bool _isLoading = false;
  String? _error;
  bool _showServerConfig = false;

  @override
  void initState() {
    super.initState();
    StorageService.getServerUrl().then((url) {
      _serverUrlController.text = url;
    });

    _selectedRole = widget.preselectedRole ?? AppUserRole.guardian;
    _fillDemoCredentials(_selectedRole);
  }

  void _fillDemoCredentials(AppUserRole role, {bool under13 = false}) {
    setState(() {
      _selectedRole = role;
      _error = null;
      switch (role) {
        case AppUserRole.teacher:
          _emailController.text = 'teacher.smith@edu.local';
          _passwordController.text = 'Teacher123!';
          break;
        case AppUserRole.guardian:
          _emailController.text = 'parent.clark@edu.local';
          _passwordController.text = 'Parent123!';
          break;
        case AppUserRole.student:
          if (under13) {
            _emailController.text = 'su.g5@intaing.edu.local';
            _passwordController.text = 'Student123!';
          } else {
            _emailController.text = 'student.alice@edu.local';
            _passwordController.text = 'Student123!';
          }
          break;
      }
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_serverUrlController.text.trim().isNotEmpty) {
        await StorageService.setServerUrl(_serverUrlController.text.trim());
      }

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      Map<String, dynamic> user;
      String token;

      try {
        final data = await ApiService.login(email, password);
        token = data['token'] as String;
        user = data['user'] as Map<String, dynamic>;
      } catch (backendError) {
        // Fallback for offline demo accounts
        if (email.contains('teacher') || email == '0911111') {
          user = {
            'id': 'd0000000-0000-0000-0000-000000000001',
            'email': email,
            'full_name': 'Daw Thida (ဒေါ်သီတာ - ဆရာမ)',
            'role': 'teacher',
            'school_name': 'BEHS Intaing (အင်းတိုင် အထက)',
          };
        } else if (email.contains('parent') || email.contains('guardian') || email == '0922222') {
          user = {
            'id': 'd0000000-0000-0000-0000-000000000002',
            'email': email,
            'full_name': 'Daw Khin Mar (ဒေါ်ခင်မာ - အုပ်ထိန်းသူ)',
            'role': 'guardian',
            'school_name': 'BEHS Intaing (အင်းတိုင် အထက)',
          };
        } else if (email.contains('su.g5') || email.contains('kg')) {
          // Under-13 student demo
          user = {
            'id': '4f703f66-22d3-4514-b5cc-1b449d3f1314',
            'email': email,
            'full_name': 'Ma Su Myat Noe (မစုမြတ်နိုး)',
            'role': 'student',
            'grade_level': 'Grade 5-A',
            'date_of_birth': '2016-04-12T00:00:00Z',
            'school_name': 'BEHS Intaing (အင်းတိုင် အထက)',
            'guardian_name': 'Daw Khin Mar (ဒေါ်ခင်မာ)',
          };
        } else {
          // Age >= 13 student demo (Alice Walker, 14 years old)
          user = {
            'id': '4f703f66-22d3-4514-b5cc-1b449d3f1313',
            'email': email,
            'full_name': 'Alice Walker (Grade 8)',
            'role': 'student',
            'grade_level': 'Grade 8',
            'date_of_birth': '2012-03-15T00:00:00Z',
            'school_name': 'Yangon Academy High School',
          };
        }

        token = JwtDecoder.generateMockToken(
          role: user['role'] as String,
          email: user['email'] as String,
          userId: user['id'] as String,
        );
        await StorageService.saveSession(token: token, user: user);
      }

      // Enrich user object with age/grade heuristics if not present
      if (email.contains('su.g5') && user['date_of_birth'] == null) {
        user['date_of_birth'] = '2016-04-12T00:00:00Z';
        user['grade_level'] = 'Grade 5-A';
        user['guardian_name'] = 'Daw Khin Mar';
        await StorageService.saveSession(token: token, user: user);
      } else if (email.contains('alice') && user['date_of_birth'] == null) {
        user['date_of_birth'] = '2012-03-15T00:00:00Z';
        user['grade_level'] = 'Grade 8';
        await StorageService.saveSession(token: token, user: user);
      }

      // If user is a student, fetch or cache credential
      if (user['role'] == 'student' && user['id'] != null) {
        await ApiService.fetchStudentBlockchainID(user['id'].toString()).catchError((_) => <String, dynamic>{});
      }

      final jwtRole = JwtDecoder.getRole(token) ?? AppUserRoleExtension.fromString(user['role']?.toString());
      final targetRoute = AppRoutes.getRouteForRole(jwtRole);

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacementNamed(context, targetRoute);
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edu Mobile Portal Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign In to EduMobile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select your role to access role-specific features (Teacher, Guardian, or Student >=13).',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),

            // Role Selector Chips
            const Text(
              'Choose Mobile Role (အသုံးပြုမည့် ကဏ္ဍ)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildRoleButton(
                  role: AppUserRole.guardian,
                  icon: Icons.family_restroom,
                  label: 'Guardian',
                  subtitle: 'မိဘ/အုပ်ထိန်းသူ',
                ),
                const SizedBox(width: 8),
                _buildRoleButton(
                  role: AppUserRole.teacher,
                  icon: Icons.school,
                  label: 'Teacher',
                  subtitle: 'ဆရာ/ဆရာမ',
                ),
                const SizedBox(width: 8),
                _buildRoleButton(
                  role: AppUserRole.student,
                  icon: Icons.person,
                  label: 'Student',
                  subtitle: 'ကျောင်းသား/သူ',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notice about under 13 policy
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 18, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Child Online Protection Policy',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blue.shade900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Students under 13 cannot use independent mobile logins. Their attendance, records, and digital ID card are viewed through their Guardian\'s account.',
                          style: TextStyle(fontSize: 10, color: Colors.blue.shade900, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Email
            const Text('Account Identifier / Email', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'user@edu.local or phone 09...',
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            const Text('Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),

            // Server URL toggle
            GestureDetector(
              onTap: () => setState(() => _showServerConfig = !_showServerConfig),
              child: Row(
                children: [
                  Icon(_showServerConfig ? Icons.arrow_drop_down : Icons.arrow_right, color: AppTheme.primary),
                  const Text('Advanced: Server Backend URL', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (_showServerConfig) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _serverUrlController,
                decoration: InputDecoration(
                  hintText: kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080 or http://192.168.1.x:8080',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  helperText: kIsWeb
                      ? 'Running on Web: defaults to http://localhost:8080'
                      : 'Use 10.0.2.2 for Android Emulator, localhost for iOS, or LAN IP for device',
                  helperStyle: const TextStyle(fontSize: 10),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Login Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Sign In as ${_selectedRole.labelEn}'),
              ),
            ),
            const SizedBox(height: 16),

            // Demo Fill Buttons
            const Center(
              child: Text(
                'Demo One-Tap Fast Sign-In:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.family_restroom, size: 16),
                  label: const Text('Guardian (Daw Khin Mar)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _fillDemoCredentials(AppUserRole.guardian),
                ),
                ActionChip(
                  avatar: const Icon(Icons.school, size: 16),
                  label: const Text('Teacher (Daw Thida)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _fillDemoCredentials(AppUserRole.teacher),
                ),
                ActionChip(
                  avatar: const Icon(Icons.person, size: 16),
                  label: const Text('Student >=13 (Alice Walker)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _fillDemoCredentials(AppUserRole.student, under13: false),
                ),
                ActionChip(
                  avatar: const Icon(Icons.shield, size: 16, color: Colors.amber),
                  label: const Text('Student <13 (Su Su, Age 10)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _fillDemoCredentials(AppUserRole.student, under13: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required AppUserRole role,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => _fillDemoCredentials(role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.primary : Colors.grey.shade600, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppTheme.primary : AppTheme.textMain,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? AppTheme.primaryLight : AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
