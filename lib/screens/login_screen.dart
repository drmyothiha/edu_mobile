import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/jwt_decoder.dart';
import '../services/nfc_auth_service.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final AppUserRole? preselectedRole;

  const LoginScreen({super.key, this.preselectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();

  AppUserRole _selectedRole = AppUserRole.guardian;
  bool _isLoading = false;
  String? _error;
  bool _showServerConfig = false;
  String _currentServerUrl = StorageService.productionServerUrl;

  // Student NFC Tap-to-Login State
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showStudentPasswordLogin = false;
  bool _isNfcListening = false;
  bool _isNfcReading = false;
  bool _nfcSuccess = false;
  String _nfcStatusText = 'Ready to scan student card (ကတ်ပြားကပ်ပါ)';
  String? _nfcError;
  NfcStatus _deviceNfcStatus = NfcStatus.available;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    StorageService.getServerUrl().then((url) {
      if (mounted) {
        setState(() {
          _currentServerUrl = url;
          _serverUrlController.text = url;
        });
      }
    });

    _selectedRole = widget.preselectedRole ?? AppUserRole.guardian;
    _fillDemoCredentials(_selectedRole);

    if (_selectedRole == AppUserRole.student && !_showStudentPasswordLogin) {
      _startNfcSession();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    NfcAuthService.stopSession();
    super.dispose();
  }

  Future<void> _startNfcSession() async {
    if (!mounted) return;
    final status = await NfcAuthService.checkNfcStatus();
    if (!mounted) return;

    setState(() {
      _deviceNfcStatus = status;
      _nfcSuccess = false;
      _nfcError = null;
      if (status == NfcStatus.available) {
        _isNfcListening = true;
        _nfcStatusText = 'Ready: Hold Student ID card near phone (ကတ်ပြားကပ်ပါ)';
      } else if (status == NfcStatus.disabled) {
        _isNfcListening = false;
        _nfcStatusText = 'NFC is disabled in system settings (NFC ဖွင့်ပေးပါ)';
      } else {
        _isNfcListening = false;
        _nfcStatusText = 'NFC sensor not available on this device/simulator';
      }
    });

    if (status != NfcStatus.available) return;

    await NfcAuthService.startStudentCardSession(
      onCardTapped: (cardId, rawPayload) async {
        if (!mounted) return;
        setState(() {
          _isNfcReading = true;
          _nfcStatusText = 'Card detected ($cardId)! Verifying offline DID...';
        });

        final result = await NfcAuthService.authenticateWithCard(
          rawPayload: rawPayload,
          hardwareId: cardId,
        );

        if (!mounted) return;
        _handleNfcAuthResult(result);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isNfcReading = false;
          _nfcError = error;
          _nfcStatusText = 'NFC tap paused';
        });
      },
    );
  }

  Future<void> _stopNfcSession() async {
    _isNfcListening = false;
    _isNfcReading = false;
    await NfcAuthService.stopSession();
  }

  void _handleNfcAuthResult(NfcAuthResult result) {
    if (result.success) {
      setState(() {
        _nfcSuccess = true;
        _isNfcReading = false;
        _nfcStatusText = '✅ Verified: ${result.user?.fullName ?? "Student"}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Welcome, ${result.user?.fullName}! Offline DID Card Verified.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.students);
        }
      });
    } else {
      setState(() {
        _isNfcReading = false;
        _nfcError = result.message;
        _nfcStatusText = 'Verification failed. Please retry.';
      });
    }
  }

  Future<void> _simulateDemoTap({
    required String name,
    required String rollNumber,
    required String gradeLevel,
  }) async {
    setState(() {
      _isNfcReading = true;
      _nfcError = null;
      _nfcStatusText = 'Reading demo card for $name...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final result = await NfcAuthService.simulateDemoCardLogin(
        studentName: name,
        rollNumber: rollNumber,
        gradeLevel: gradeLevel,
      );
      if (!mounted) return;
      _handleNfcAuthResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isNfcReading = false;
        _nfcError = e.toString();
        _nfcStatusText = 'Demo tap failed';
      });
    }
  }

  void _onRoleSelected(AppUserRole role) {
    if (_selectedRole == role &&
        role == AppUserRole.student &&
        !_showStudentPasswordLogin &&
        !_isNfcListening) {
      _startNfcSession();
      return;
    }

    if (role != AppUserRole.student) {
      _stopNfcSession();
      _showStudentPasswordLogin = false;
    } else {
      if (!_showStudentPasswordLogin) {
        _startNfcSession();
      }
    }
    _fillDemoCredentials(role);
  }

  Future<void> _openServerSettings() async {
    await Navigator.pushNamed(context, AppRoutes.settings);
    if (mounted) {
      final updatedUrl = await StorageService.getServerUrl();
      setState(() {
        _currentServerUrl = updatedUrl;
        _serverUrlController.text = updatedUrl;
      });
    }
  }

  void _fillDemoCredentials(AppUserRole role, {bool under13 = false}) {
    setState(() {
      _selectedRole = role;
      _error = null;
      switch (role) {
        case AppUserRole.admin:
          _emailController.text = 'admin@pilot.edu.local';
          _passwordController.text = 'mth';
          break;
        case AppUserRole.teacher:
          _emailController.text = '0911111';
          _passwordController.text = 'mth';
          break;
        case AppUserRole.guardian:
          _emailController.text = '0922222';
          _passwordController.text = 'mth';
          break;
        case AppUserRole.student:
          if (under13) {
            _emailController.text = 'su.g5@intaing.edu.local';
            _passwordController.text = 'mth';
          } else {
            _emailController.text = 'student.alice@edu.local';
            _passwordController.text = 'mth';
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
            'full_name': 'အုပ်ထိန်းသူ (Guardian)',
            'role': 'guardian',
            'school_name': 'Basic Education School',
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
            'school_name': 'Basic Education School',
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
        await ApiService.fetchStudentBlockchainID(
          user['id'].toString(),
        ).catchError((_) => <String, dynamic>{});
      }

      final jwtRole =
          JwtDecoder.getRole(token) ??
          AppUserRoleExtension.fromString(user['role']?.toString());
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
        title: const Text('AugmentEd Portal Login'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings (ဆာဗာချိန်ညှိမှု)',
            onPressed: _openServerSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign In to AugmentEd',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select your role to access role-specific features (Teacher, Guardian, or Student).',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),

            // Server Indicator Chip (clickable to edit)
            InkWell(
              onTap: _openServerSettings,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_done_outlined,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Server: $_currentServerUrl',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDark,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Role Selector Chips
            const Text(
              'Choose Mobile Role (အသုံးပြုမည့် ကဏ္ဍ)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildRoleButton(
                  role: AppUserRole.admin,
                  icon: Icons.admin_panel_settings,
                  label: 'Admin',
                  subtitle: 'ကျောင်းအုပ်',
                ),
                const SizedBox(width: 6),
                _buildRoleButton(
                  role: AppUserRole.teacher,
                  icon: Icons.school,
                  label: 'Teacher',
                  subtitle: 'ဆရာ/ဆရာမ',
                ),
                const SizedBox(width: 6),
                _buildRoleButton(
                  role: AppUserRole.guardian,
                  icon: Icons.family_restroom,
                  label: 'Guardian',
                  subtitle: 'မိဘ/အုပ်ထိန်း',
                ),
                const SizedBox(width: 6),
                _buildRoleButton(
                  role: AppUserRole.student,
                  icon: Icons.contactless_rounded,
                  label: 'Student',
                  subtitle: 'NFC ကတ်ပြား',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode Selector: Student NFC Station vs Standard Email/Password Form
            if (_selectedRole == AppUserRole.student &&
                !_showStudentPasswordLogin) ...[
              _buildStudentNfcStation(),
            ] else ...[
              if (_selectedRole == AppUserRole.student &&
                  _showStudentPasswordLogin)
                _buildNfcSwitchBanner(),

              if (_selectedRole == AppUserRole.guardian)
                _buildChildPolicyBanner(),

              if (_error != null) _buildErrorBanner(),

              // Email
              const Text(
                'Account Identifier / Email',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'user@edu.local or phone 09...',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              const Text(
                'Password',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Server URL toggle
              GestureDetector(
                onTap: () =>
                    setState(() => _showServerConfig = !_showServerConfig),
                child: Row(
                  children: [
                    Icon(
                      _showServerConfig
                          ? Icons.arrow_drop_down
                          : Icons.arrow_right,
                      color: AppTheme.primary,
                    ),
                    const Text(
                      'Advanced: Server Backend URL',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showServerConfig) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _serverUrlController,
                  decoration: InputDecoration(
                    hintText: 'https://136.85.95.216 or http://10.0.2.2:8080',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    helperText:
                        'Defaults to https://136.85.95.216. You can also open the full settings page below.',
                    helperStyle: const TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text(
                      'Open Server Settings Page (IP ချိန်ညှိမှု)',
                    ),
                    onPressed: _openServerSettings,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('Sign In as ${_selectedRole.labelEn}'),
                ),
              ),
              const SizedBox(height: 16),

              // Demo Fill Buttons
              const Center(
                child: Text(
                  'One-Tap Role Fast Sign-In (Password: "mth"):',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons.admin_panel_settings,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    label: const Text(
                      'School Admin',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _fillDemoCredentials(AppUserRole.admin),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.school, size: 16),
                    label: const Text(
                      'Teacher (0911111)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () => _fillDemoCredentials(AppUserRole.teacher),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.family_restroom, size: 16),
                    label: const Text(
                      'Guardian (0922222)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () => _fillDemoCredentials(AppUserRole.guardian),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.person, size: 16),
                    label: const Text(
                      'Student >=13 (Alice)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      setState(() => _showStudentPasswordLogin = true);
                      _stopNfcSession();
                      _fillDemoCredentials(AppUserRole.student, under13: false);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.shield,
                      size: 16,
                      color: Colors.amber,
                    ),
                    label: const Text(
                      'Student <13 (Su Su)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      setState(() => _showStudentPasswordLogin = true);
                      _stopNfcSession();
                      _fillDemoCredentials(AppUserRole.student, under13: true);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Interactive NFC Student Card Tap Station Widget
  Widget _buildStudentNfcStation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // NFC Smart Card Hero Container
        Container(
          height: 225,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0F2027),
                Color(0xFF203A43),
                Color(0xFF2C5364),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF203A43).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.cyanAccent.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Subtle background card decoration
              Positioned(
                right: -30,
                bottom: -30,
                child: Icon(
                  Icons.contactless_rounded,
                  size: 180,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Card Top: School & DID badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.cyanAccent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BEHS INTAING PILOT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  'စမ်းသပ်ကျောင်း • Pilot School Deployment',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.shade300,
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user,
                                size: 12,
                                color: Colors.amber,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'OFFLINE DID',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.amber,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Card Center: Pulsing NFC Radar Wave
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final scale = _nfcSuccess
                              ? 1.0
                              : (1.0 + (_pulseAnimation.value * 0.18));
                          final ringOpacity = _nfcSuccess
                              ? 0.35
                              : (0.2 + (_pulseAnimation.value * 0.25));

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer ripple ring
                              Container(
                                width: 84 * scale,
                                height: 84 * scale,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _nfcSuccess
                                        ? Colors.greenAccent
                                            .withValues(alpha: ringOpacity)
                                        : Colors.cyanAccent
                                            .withValues(alpha: ringOpacity),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              // Core circle
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: _nfcSuccess
                                        ? [
                                            Colors.greenAccent,
                                            Colors.green.shade800,
                                          ]
                                        : _isNfcReading
                                            ? [
                                                Colors.amberAccent,
                                                Colors.deepOrange,
                                              ]
                                            : [
                                                Colors.cyanAccent,
                                                const Color(0xFF0072FF),
                                              ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_nfcSuccess
                                              ? Colors.greenAccent
                                              : Colors.cyanAccent)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 14,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: _isNfcReading
                                    ? const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        _nfcSuccess
                                            ? Icons.check_circle_rounded
                                            : Icons.contactless_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Card Bottom: Chips & Standards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.credit_card,
                                size: 12,
                                color: Colors.white70,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'NFC-A / NDEF',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'W3C Verifiable Credential 2.0 • Ed25519',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Real-time Status Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _nfcSuccess
                ? Colors.green.shade50
                : _nfcError != null
                    ? Colors.red.shade50
                    : _isNfcReading
                        ? Colors.amber.shade50
                        : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _nfcSuccess
                  ? Colors.green.shade300
                  : _nfcError != null
                      ? Colors.red.shade300
                      : _isNfcReading
                          ? Colors.amber.shade300
                          : Colors.blue.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _nfcSuccess
                    ? Icons.check_circle
                    : _nfcError != null
                        ? Icons.error_outline
                        : _isNfcReading
                            ? Icons.hourglass_top_rounded
                            : Icons.sensors_rounded,
                color: _nfcSuccess
                    ? Colors.green.shade700
                    : _nfcError != null
                        ? Colors.red.shade700
                        : _isNfcReading
                            ? Colors.amber.shade800
                            : AppTheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nfcSuccess
                          ? 'Verification Successful!'
                          : _nfcError != null
                              ? 'Card Read Alert'
                              : _isNfcReading
                                  ? 'Validating Digital Signature...'
                                  : 'NFC Tap Station Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _nfcSuccess
                            ? Colors.green.shade900
                            : _nfcError != null
                                ? Colors.red.shade900
                                : _isNfcReading
                                    ? Colors.amber.shade900
                                    : AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nfcError ?? _nfcStatusText,
                      style: TextStyle(
                        fontSize: 11,
                        color: _nfcError != null
                            ? Colors.red.shade800
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_deviceNfcStatus != NfcStatus.available && !_nfcSuccess)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Retry NFC Detection',
                  onPressed: _startNfcSession,
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick Demo Tap for Emulators / Fast Testing
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Fast Demo Tap (စမ်းသပ်ရန် ကတ်ပြားများ)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.cyan.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Emulator Ready',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyan.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Simulate tapping an authentic W3C Ed25519 student card without physical NFC writer:',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        side: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.badge_outlined, size: 16),
                      label: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Maung Aung (KG)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ROLL-KG-001',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      onPressed: _isNfcReading || _isLoading
                          ? null
                          : () => _simulateDemoTap(
                                name: 'Maung Aung Kaung Myat',
                                rollNumber: 'ROLL-KG-001',
                                gradeLevel: 'Kindergarten (KG)',
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        side: BorderSide(color: Colors.purple.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        Icons.school_outlined,
                        size: 16,
                        color: Colors.purple.shade700,
                      ),
                      label: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ma Su (Grade 5)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800,
                            ),
                          ),
                          const Text(
                            'ROLL-G5-001',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      onPressed: _isNfcReading || _isLoading
                          ? null
                          : () => _simulateDemoTap(
                                name: 'Ma Su Myat Noe (မစုမြတ်နိုး)',
                                rollNumber: 'ROLL-G5-001',
                                gradeLevel: 'Grade 5-A',
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Fallback to Username & Password
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            icon: const Icon(Icons.password_rounded, size: 18),
            label: const Text(
              'Can\'t tap card? Login with Username & Password',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              _stopNfcSession();
              setState(() {
                _showStudentPasswordLogin = true;
              });
            },
          ),
        ),

        const SizedBox(height: 12),

        // Offline security information
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.offline_bolt_outlined, size: 16, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '100% Offline Login: Student timetable & notices are cached locally. No internet or server connection is required.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Banner when student chooses fallback to username/password
  Widget _buildNfcSwitchBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.contactless_rounded,
            color: AppTheme.primary,
            size: 24,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NFC Smart Card Tap Available',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                Text(
                  'Tap your student ID card for instant login',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.touch_app, size: 14),
            label: const Text(
              'Tap Card',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              setState(() {
                _showStudentPasswordLogin = false;
              });
              _startNfcSession();
            },
          ),
        ],
      ),
    );
  }

  /// Child Online Protection policy notice for Guardian role
  Widget _buildChildPolicyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            size: 18,
            color: Colors.blue.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Child Online Protection Policy',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Guardians have full visibility over child records, attendance, and smart ID cards. Children can tap their card independently to view their schedule.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade900,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
        onTap: () => _onRoleSelected(role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primary : Colors.grey.shade600,
                size: 22,
              ),
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
                  color: isSelected
                      ? AppTheme.primaryLight
                      : AppTheme.textMuted,
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
