import 'package:flutter/material.dart';
import '../../models/guardian_child.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/student_wallet_screen.dart';

class GuardianDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final VoidCallback? onSwitchRole;

  const GuardianDashboardScreen({
    super.key,
    this.onNavigateTab,
    this.onSwitchRole,
  });

  @override
  State<GuardianDashboardScreen> createState() => _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  List<GuardianChild> _children = [];
  int _selectedChildIndex = 0;
  bool _isLoading = true;
  AppUser? _guardianUser;

  @override
  void initState() {
    super.initState();
    _loadGuardianData();
  }

  Future<void> _loadGuardianData() async {
    setState(() => _isLoading = true);
    final user = await StorageService.getCurrentUser();
    final children = await StorageService.getGuardianChildren();
    final savedIndex = await StorageService.getSelectedChildIndex();

    if (mounted) {
      setState(() {
        _guardianUser = user;
        _children = children;
        _selectedChildIndex = (savedIndex < children.length) ? savedIndex : 0;
        _isLoading = false;
      });
    }
  }

  void _selectChild(int index) {
    setState(() {
      _selectedChildIndex = index;
    });
    StorageService.setSelectedChildIndex(index);
  }

  void _openChildDigitalId(GuardianChild child) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text('${child.fullName}\'s Pass'),
            centerTitle: true,
          ),
          body: StudentWalletScreen(
            onSwitchMode: () => Navigator.of(context).pop(),
            isGuardianView: true,
            childName: child.fullName,
            gradeLevel: child.gradeLevel,
            overrideCredential: child.toVcJson(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final child = _children.isNotEmpty ? _children[_selectedChildIndex] : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guardian Portal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              _guardianUser?.fullName.isNotEmpty == true
                  ? 'အုပ်ထိန်းသူ: ${_guardianUser!.fullName}'
                  : 'မိဘ / အုပ်ထိန်းသူ ကဏ္ဍ',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          if (widget.onSwitchRole != null)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Role',
              onPressed: widget.onSwitchRole,
            ),
        ],
      ),
      body: child == null
          ? const Center(child: Text('No enrolled children found.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Child Switcher Tabs
                  if (_children.length > 1) ...[
                    const Text(
                      'Select Dependent Child (အုပ်ထိန်းသော ကလေးရွေးချယ်ပါ)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_children.length, (index) {
                          final c = _children[index];
                          final isSelected = index == _selectedChildIndex;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 16,
                                    color: isSelected ? Colors.white : AppTheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${c.fullName} (${c.gradeLevel})',
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textMain,
                              ),
                              onSelected: (_) => _selectChild(index),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Child Header Card
                  _buildChildHeaderCard(child),
                  const SizedBox(height: 16),

                  // Quick Action: View Digital ID Pass
                  _buildQuickActionBanner(child),
                  const SizedBox(height: 16),

                  // Whole-Child Development Metrics (5 Pillars)
                  _buildWholeChildMetricsSection(child),
                  const SizedBox(height: 16),

                  // Health & Growth Card
                  _buildHealthGrowthCard(child),
                  const SizedBox(height: 16),

                  // Teacher Direct Communication CTA
                  _buildTeacherChatCTA(child),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildChildHeaderCard(GuardianChild child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  child.fullName.isNotEmpty ? child.fullName[0] : 'S',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${child.gradeLevel} • Roll: ${child.rollNo}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    Text(
                      child.schoolName,
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield, size: 14, color: Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      child.isUnder13 ? 'Age ${child.age} • Guardian Supervised' : 'Age ${child.age}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Text(
                'Term: ${child.termGradePoint} Grade',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBanner(GuardianChild child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_2_rounded, size: 30, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Child\'s Digital ID Card',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Show W3C QR code at school gate pickup / verification',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _openChildDigitalId(child),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Pass', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildWholeChildMetricsSection(GuardianChild child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Whole-Child Academic & Attendance',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '${child.attendanceRatePct}% Attendance',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (child.attendanceRatePct / 100.0).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade100,
              color: Colors.green.shade600,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Present: ${child.sessionsPresent} sessions', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text('Absent: ${child.sessionsAbsent} sessions', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          if (child.examScores.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('Exam Performance (စာမေးပွဲ ရမှတ်များ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: child.examScores.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                      const SizedBox(width: 6),
                      Text('${e.value.toStringAsFixed(0)} pts', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthGrowthCard(GuardianChild child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Physical Growth & Wellbeing (ကျန်းမာရေးနှင့် ဖွံ့ဖြိုးမှု)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHealthBadge(
                  Icons.monitor_weight_outlined,
                  'BMI: ${child.calculatedBmi}',
                  child.bmiCategory,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHealthBadge(
                  Icons.medical_services_outlined,
                  'Deworming',
                  child.dewormingCompleted ? 'Completed ✅' : 'Pending',
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHealthBadge(
                  Icons.visibility_outlined,
                  'Vision Check',
                  child.visionCheck,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHealthBadge(
                  Icons.mood,
                  'Dominant State',
                  child.dominantEmotionalState,
                  Colors.amber.shade900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherChatCTA(GuardianChild child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.chat, color: Colors.blue.shade800, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Class Teacher',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.blue.shade900),
                ),
                Text(
                  'Direct questions or attendance alerts for ${child.className}',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (widget.onNavigateTab != null) {
                // Navigate to the Chat/Communications tab (index 2 for Guardian)
                widget.onNavigateTab!(2);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Open Chat', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
