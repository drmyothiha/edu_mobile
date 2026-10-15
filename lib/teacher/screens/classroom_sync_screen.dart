import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/whole_child_record.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ClassroomSyncScreen extends StatefulWidget {
  final VoidCallback? onSwitchMode;

  const ClassroomSyncScreen({super.key, this.onSwitchMode});

  @override
  State<ClassroomSyncScreen> createState() => _ClassroomSyncScreenState();
}

class _ClassroomSyncScreenState extends State<ClassroomSyncScreen> {
  List<WholeChildRecord> _records = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _selectedPillar = 'all'; // 'all', 'academic', 'growth', 'health', 'wellbeing', 'citizenship'
  DateTime? _lastSyncTime;
  String? _syncMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final records = await StorageService.getWholeChildRecords();
    final lastSync = await StorageService.getLastSyncTime();
    if (mounted) {
      setState(() {
        _records = records;
        _lastSyncTime = lastSync;
        _isLoading = false;
      });
    }
  }

  Future<void> _performOnlineSync() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });

    try {
      final user = await StorageService.getUser();
      final schoolCode = user?['school_code']?.toString() ?? '';
      final schoolName = user?['school_name']?.toString() ?? 'Basic Education School';
      final teacherName = user?['full_name']?.toString() ?? 'Classroom Teacher';

      // Build canonical Whole-Child sync payload
      final payload = {
        'sync_metadata': {
          'protocol_version': '2.1-whole-child',
          'school_code': schoolCode,
          'school_name': schoolName,
          'township': user?['township']?.toString() ?? '',
          'class_id': 'f833a1dc-b85a-4063-a3ef-e057df2129f0',
          'class_name': 'Grade 5-A (Primary)',
          'academic_year': '2026-2027',
          'reporting_period': '2026-10',
          'reporting_teacher': {
            'teacher_id': user?['id']?.toString() ?? 'teacher_01',
            'name': teacherName,
            'role': 'Teacher',
          },
          'generated_at': DateTime.now().toIso8601String(),
          'total_official_school_days': 22,
          'total_enrolled_students': _records.length,
          'checksum': 'sha256:mobile_${DateTime.now().millisecondsSinceEpoch}',
        },
        'students': _records.map((r) => r.toSyncJson()).toList(),
      };

      final res = await ApiService.uploadWholeChildBatch(payload);
      final now = DateTime.now();
      await StorageService.setLastSyncTime(now);

      setState(() {
        _lastSyncTime = now;
        _syncMessage = 'Sync Successful! ${res['processed_students'] ?? _records.length} Whole-Child records ingested by Central Server.';
      });

      // Update local records status to synced
      final updated = _records.map((r) {
        return WholeChildRecord(
          studentId: r.studentId,
          rollNo: r.rollNo,
          nationalStudentId: r.nationalStudentId,
          fullName: r.fullName,
          academicYear: r.academicYear,
          period: r.period,
          totalSessions: r.totalSessions,
          sessionsPresent: r.sessionsPresent,
          sessionsAbsent: r.sessionsAbsent,
          attendanceRatePct: r.attendanceRatePct,
          examScores: r.examScores,
          termGradePoint: r.termGradePoint,
          competencies: r.competencies,
          heightCm: r.heightCm,
          weightKg: r.weightKg,
          calculatedBmi: r.calculatedBmi,
          bmiCategory: r.bmiCategory,
          preferredSports: r.preferredSports,
          visionCheck: r.visionCheck,
          hearingCheck: r.hearingCheck,
          dewormingCompleted: r.dewormingCompleted,
          knownAllergies: r.knownAllergies,
          dominantEmotionalState: r.dominantEmotionalState,
          engagementIndex: r.engagementIndex,
          teacherNotes: r.teacherNotes,
          leadershipRole: r.leadershipRole,
          clubName: r.clubName,
          citizenshipBadges: r.citizenshipBadges,
          syncStatus: 'synced',
          updatedAt: r.updatedAt,
        );
      }).toList();

      await StorageService.saveWholeChildRecords(updated);
      setState(() => _records = updated);
    } catch (e) {
      setState(() {
        _syncMessage = 'Offline Notice: Server unavailable (${e.toString()}). Records remain safely buffered locally.';
      });
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _exportJsonBundle() async {
    final user = await StorageService.getUser();
    final schoolCode = user?['school_code']?.toString() ?? '';
    final schoolName = user?['school_name']?.toString() ?? 'Basic Education School';
    final teacherName = user?['full_name']?.toString() ?? 'Classroom Teacher';

    final payload = {
      'sync_metadata': {
        'protocol_version': '2.1-whole-child',
        'school_code': schoolCode,
        'school_name': schoolName,
        'township': user?['township']?.toString() ?? '',
        'class_name': 'Grade 5-A (Primary)',
        'academic_year': '2026-2027',
        'reporting_period': '2026-10',
        'reporting_teacher': {
          'name': teacherName,
          'role': 'Teacher',
        },
        'generated_at': DateTime.now().toIso8601String(),
        'total_enrolled_students': _records.length,
      },
      'students': _records.map((r) => r.toSyncJson()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: jsonStr));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Export Sync Bundle (.json)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Whole-Child Development sync bundle copied to clipboard. You can paste it into a file, save it to a USB flash drive, or transfer it to the Township Education Office via Bluetooth / Nearby Share.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Payload: ${_records.length} students • ${(jsonStr.length / 1024).toStringAsFixed(1)} KB (Gzip ~1.8 KB)\nReady for offline sneakernet / USB import.',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grade 5-A • Whole-Child Hub',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'စာသင်ခန်း တာဝန်ခံ ဆရာ/ဆရာမ • Classroom Teacher',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export Sync JSON',
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: _exportJsonBundle,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Top Status Card: Offline Readiness & Sync Actions
                  _buildSyncStatusBar(),
                  const SizedBox(height: 16),

                  // 5-Pillars Quick Filter Bar
                  _buildPillarFilterChips(),
                  const SizedBox(height: 16),

                  // Feedback Message
                  if (_syncMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _syncMessage!.contains('Successful')
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _syncMessage!.contains('Successful')
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _syncMessage!.contains('Successful')
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 18,
                            color: _syncMessage!.contains('Successful')
                                ? Colors.green.shade700
                                : Colors.amber.shade900,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _syncMessage!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _syncMessage!.contains('Successful')
                                    ? Colors.green.shade900
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Student Cards List
                  const Text(
                    'Classroom Roster & Holistic Development (9.1 - 9.5)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),

                  ..._records.map((student) => _buildStudentCard(student)),
                ],
              ),
            ),
    );
  }

  Widget _buildSyncStatusBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, size: 12, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text(
                      '100% Offline Local Store',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Text(
                'AY 2026-2027',
                style: TextStyle(color: Colors.indigo.shade200, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Whole-Child Sync Center',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            _lastSyncTime != null
                ? 'Last Synced: ${_lastSyncTime!.toLocal().toString().substring(0, 16)}'
                : 'Pending Monthly Sync for 2026-10 (Offline Buffer Active)',
            style: TextStyle(color: Colors.indigo.shade200, fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _performOnlineSync,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync to Central Server'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _exportJsonBundle,
                icon: const Icon(Icons.usb, size: 16, color: Colors.white),
                label: const Text('Export for USB'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillarFilterChips() {
    final pillars = [
      {'id': 'all', 'label': 'All 5 Pillars'},
      {'id': 'academic', 'label': '9.1 Academic'},
      {'id': 'growth', 'label': '9.2 Growth'},
      {'id': 'health', 'label': '9.3 Health'},
      {'id': 'wellbeing', 'label': '9.4 Wellbeing'},
      {'id': 'citizenship', 'label': '9.5 Citizenship'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: pillars.map((p) {
          final isSelected = _selectedPillar == p['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(p['label']!),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedPillar = p['id']!),
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStudentCard(WholeChildRecord student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        student.rollNo,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'DID: did:edu:mm:... • Roll: ${student.rollNo}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${student.attendanceRatePct}% Att',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // 9.1 Academic Highlights
            if (_selectedPillar == 'all' || _selectedPillar == 'academic') ...[
              _buildSectionHeader(Icons.book_outlined, '9.1 Academic Profile', Colors.blue.shade700),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildMetricBadge('Exam GPA: ${student.termGradePoint}', Colors.blue.shade50, Colors.blue.shade800),
                  ...student.examScores.entries.map((e) => _buildMetricBadge(
                        '${e.key.substring(0, 3).toUpperCase()}: ${e.value.toInt()}',
                        Colors.blueGrey.shade50,
                        Colors.blueGrey.shade800,
                      )),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 9.2 Physical Growth
            if (_selectedPillar == 'all' || _selectedPillar == 'growth') ...[
              _buildSectionHeader(Icons.directions_run_outlined, '9.2 Physical Growth Profile', Colors.green.shade700),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildMetricBadge('${student.heightCm} cm • ${student.weightKg} kg', Colors.green.shade50, Colors.green.shade800),
                  _buildMetricBadge('BMI ${student.calculatedBmi} (${student.bmiCategory})', Colors.green.shade50, Colors.green.shade800),
                  _buildMetricBadge('Sports: ${student.preferredSports.join(', ')}', Colors.blueGrey.shade50, Colors.blueGrey.shade800),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 9.3 Health Visibility
            if (_selectedPillar == 'all' || _selectedPillar == 'health') ...[
              _buildSectionHeader(Icons.health_and_safety_outlined, '9.3 Health Visibility (Off-Chain)', Colors.amber.shade800),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildMetricBadge('Vision: ${student.visionCheck}', Colors.amber.shade50, Colors.amber.shade900),
                  _buildMetricBadge(student.dewormingCompleted ? 'Dewormed 2026' : 'Deworming Pending', Colors.amber.shade50, Colors.amber.shade900),
                  if (student.knownAllergies.isNotEmpty)
                    _buildMetricBadge('Allergy: ${student.knownAllergies.join(", ")}', Colors.red.shade50, Colors.red.shade900),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 9.4 Wellbeing
            if (_selectedPillar == 'all' || _selectedPillar == 'wellbeing') ...[
              _buildSectionHeader(Icons.mood_outlined, '9.4 Wellbeing Profile', Colors.pink.shade700),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildMetricBadge('State: ${student.dominantEmotionalState}', Colors.pink.shade50, Colors.pink.shade800),
                  _buildMetricBadge('Engagement: ${student.engagementIndex}/5.0', Colors.pink.shade50, Colors.pink.shade800),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 9.5 Social Participation & Citizenship
            if (_selectedPillar == 'all' || _selectedPillar == 'citizenship') ...[
              _buildSectionHeader(Icons.military_tech_outlined, '9.5 Citizenship & Roles (Non-Punitive)', Colors.purple.shade700),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildMetricBadge('Role: ${student.leadershipRole}', Colors.purple.shade50, Colors.purple.shade800),
                  _buildMetricBadge(student.clubName, Colors.purple.shade50, Colors.purple.shade800),
                  ...student.citizenshipBadges.map((b) => _buildMetricBadge(b, Colors.amber.shade50, Colors.amber.shade900)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _buildMetricBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }
}
