import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/jwt_decoder.dart';
import '../routes/app_routes.dart';
import '../widgets/update_dialog.dart';
import '../theme/app_theme.dart';

/// Clean, standard login screen:
/// - Username / Phone Number field
/// - Password field
/// - Forgot Password link
/// - Login button
/// - Register link
class LoginScreen extends StatefulWidget {
  final AppUserRole? preselectedRole;

  const LoginScreen({super.key, this.preselectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default demo helper if preselected role was provided
    if (widget.preselectedRole == AppUserRole.guardian) {
      _emailController.text = '0922222';
      _passwordController.text = 'mth';
    } else if (widget.preselectedRole == AppUserRole.teacher) {
      _emailController.text = '0911111';
      _passwordController.text = 'mth';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your username or phone number (အသုံးပြုသူအမည် ထည့်ပါ)');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password (စကားဝှက် ထည့်ပါ)');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic> user;
      String token;

      try {
        final data = await ApiService.login(email, password);
        token = data['token'] as String;
        user = data['user'] as Map<String, dynamic>;
      } catch (backendError) {
        // Graceful fallback for offline demo testing
        if (email.contains('admin') || email == '0944444') {
          user = {
            'id': 'd0000000-0000-0000-0000-000000000099',
            'email': email,
            'full_name': 'ကျောင်းအုပ်ကြီး (Principal)',
            'role': 'admin',
            'school_name': 'Basic Education School',
            'school_id': '0ac3f6b3-ce6d-4d15-bb4c-9b868f41aeb4',
          };
        } else if (email.contains('teacher') || email == '0911111') {
          user = {
            'id': 'd0000000-0000-0000-0000-000000000001',
            'email': email,
            'full_name': 'ဆရာ/ဆရာမ (Teacher)',
            'role': 'teacher',
            'school_name': 'Basic Education School',
          };
        } else if (email.contains('parent') ||
            email.contains('guardian') ||
            email == '0922222') {
          user = {
            'id': 'd0000000-0000-0000-0000-000000000002',
            'email': email,
            'full_name': 'Daw Khin Mar (Parent)',
            'role': 'parent',
            'school_name': 'Basic Education School',
          };
        } else {
          user = {
            'id': 'd0000000-0000-0000-0000-000000000003',
            'email': email,
            'full_name': 'Ma Su Myat Noe',
            'role': 'student',
            'grade_level': 'Grade 5-A',
            'guardian_name': 'Daw Khin Mar',
          };
        }
        token = JwtDecoder.generateMockToken(
          userId: user['id'].toString(),
          role: user['role'].toString(),
          email: email,
        );
        await StorageService.saveSession(token: token, user: user);
      }

      await _finishLogin(token, user, email: email);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _finishLogin(
    String token,
    Map<String, dynamic> user, {
    String email = '',
  }) async {
    // If user is a student, fetch or cache credential
    if (user['role'] == 'student' && user['id'] != null) {
      await ApiService.fetchStudentBlockchainID(
        user['id'].toString(),
      ).catchError((_) => <String, dynamic>{});
    }

    // If user is a guardian, fetch linked children immediately to ensure cache is fresh
    final roleStr = user['role']?.toString().toLowerCase() ?? '';
    if (roleStr == 'guardian' ||
        roleStr == 'parent' ||
        email.contains('parent') ||
        email == '0922222' ||
        user['phone'] == '0922222') {
      try {
        await ApiService.getMyChildren();
      } catch (_) {}
    }

    final jwtRole =
        JwtDecoder.getRole(token) ??
        AppUserRoleExtension.fromString(user['role']?.toString());
    final targetRoute = AppRoutes.getRouteForRole(jwtRole);

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, targetRoute, (route) => false);
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.primary),
            SizedBox(width: 8),
            Text(
              'Forgot Password?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'စကားဝှက် ပြန်လည်ရယူခြင်း',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
            SizedBox(height: 10),
            Text(
              '• မိဘ / ကျောင်းသားများ: မိမိတို့၏ ကလေးကျောင်း အုပ်ချုပ်ရေးဌာန သို့မဟုတ် အတန်းပိုင်ဆရာမထံ ဆက်သွယ်၍ စကားဝှက် ပြန်လည်သတ်မှတ်နိုင်ပါသည်။\n\n'
              '• ဆရာ / ဆရာမများ: စာသင်ကျောင်း ICT ဌာန သို့မဟုတ် စနစ်စီမံခန့်ခွဲသူထံ အကြောင်းကြားပါ။\n\n'
              '• For Parents & Learners: Please contact your school administration or class teacher to reset your password.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK (နားလည်ပါပြီ)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRegisterSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isSubmitting = false;
    String? registerError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Parent Account Registration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'မိဘ / အုပ်ထိန်းသူ အကောင့် အသစ်ဖွင့်ရန်',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 20),
                if (registerError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      registerError!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name (အမည်)',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone (ဖုန်းနံပါတ်)',
                    hintText: 'e.g. 09123456789',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password (စကားဝှက်)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            final pass = passCtrl.text;
                            if (name.isEmpty || phone.isEmpty || pass.isEmpty) {
                              setSheetState(() => registerError = 'Please fill in all fields (အချက်အလက်အားလုံး ဖြည့်ပါ)');
                              return;
                            }
                            setSheetState(() {
                              isSubmitting = true;
                              registerError = null;
                            });

                            try {
                              await ApiService.registerParentSubscription(
                                phone: phone,
                                password: pass,
                                fullName: name,
                                planTier: 'basic',
                              );
                              // Auto-login
                              final loginRes = await ApiService.login(phone, pass);
                              final token = loginRes['token'] as String;
                              final user = loginRes['user'] as Map<String, dynamic>;
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _finishLogin(token, user, email: phone);
                            } catch (e) {
                              setSheetState(() {
                                isSubmitting = false;
                                registerError = e.toString().replaceAll('Exception: ', '');
                              });
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Register Account (အကောင့်ဖွင့်မည်)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update_alt, color: AppTheme.textMuted),
            tooltip: 'Check Updates',
            onPressed: () => UpdateDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textMuted),
            tooltip: 'Server Settings',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Header
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'AugmentEd',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 32),

                // Error Banner
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Username / Identifier Field
                const Text(
                  'Username or Phone Number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Enter username, email or phone',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Password Field
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
                    ),
                  ),
                ),

                // Forgot Password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Login Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Text(
                            'Log In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showRegisterSheet,
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
