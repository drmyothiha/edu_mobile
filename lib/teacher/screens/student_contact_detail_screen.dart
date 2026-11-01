import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/whole_child_record.dart';
import '../../models/lifelong_academic_record.dart';
import '../../widgets/lifelong_academic_record_sheet.dart';
import 'teacher_conversations_screen.dart';

/// Detailed Student Profile Screen styled authentically after Google Contacts.
/// Displays student identity, quick action pills, contact information,
/// academic metrics, 5-Pillar Whole-Child development, and teacher notes.
class StudentContactDetailScreen extends StatefulWidget {
  final WholeChildRecord student;

  const StudentContactDetailScreen({
    super.key,
    required this.student,
  });

  @override
  State<StudentContactDetailScreen> createState() =>
      _StudentContactDetailScreenState();
}

class _StudentContactDetailScreenState
    extends State<StudentContactDetailScreen> {
  bool _isFavorite = false;

  static const List<Color> _avatarColors = [
    Color(0xFF1A73E8), // Google Blue
    Color(0xFF1E8E3E), // Google Green
    Color(0xFFD93025), // Google Red
    Color(0xFFF9AB00), // Google Amber
    Color(0xFF9334E6), // Google Purple
    Color(0xFF007B83), // Google Teal
    Color(0xFFE37400), // Google Orange
    Color(0xFFE52592), // Google Pink
  ];

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return _avatarColors[0];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return _avatarColors[hash % _avatarColors.length];
  }

  String _getAvatarInitial(String name) {
    if (name.isEmpty) return 'S';
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z\u1000-\u109F]'), '').trim();
    if (clean.isEmpty) return 'S';
    return clean[0].toUpperCase();
  }

  String _getGuardianPhone() {
    final digits = widget.student.rollNo.replaceAll(RegExp(r'[^0-9]'), '');
    final suffix = digits.isNotEmpty ? digits.padLeft(2, '0') : '01';
    return '+95 9 791 234 5$suffix';
  }

  void _callGuardian() {
    final phone = _getGuardianPhone();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling Guardian: $phone (အုပ်ထိန်းသူထံ ဖုန်းခေါ်ဆိုနေပါသည်)'),
        backgroundColor: const Color(0xFF1E8E3E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openChatWithGuardian() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TeacherConversationsScreen(),
      ),
    );
  }

  void _openLifelongAcademicRecord() {
    final profile = LifelongAcademicProfile.fromStudentData(
      studentId: widget.student.studentId,
      studentName: widget.student.fullName,
      rollNo: widget.student.rollNo,
      gradeLevel: 'Grade 5-A (Primary)',
      nationalStudentId: widget.student.nationalStudentId,
    );
    showLifelongAcademicRecordModal(context, profile: profile);
  }

  void _showStudentIdBadgeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.badge_outlined, color: Color(0xFF1A73E8)),
            ),
            const SizedBox(width: 12),
            const Text(
              'Student Smart ID',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: _getAvatarColor(widget.student.fullName),
              child: Text(
                _getAvatarInitial(widget.student.fullName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.student.fullName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'National ID: ${widget.student.nationalStudentId}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 100, color: Color(0xFF1A73E8)),
                  const SizedBox(height: 8),
                  Text(
                    'W3C Verifiable Credential 2.0',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'did:edu:mm:student:${widget.student.rollNo.toLowerCase()}',
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final avatarColor = _getAvatarColor(student.fullName);
    final avatarInitial = _getAvatarInitial(student.fullName);
    final guardianPhone = _getGuardianPhone();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFD),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F1F1F)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? const Color(0xFFF9AB00) : const Color(0xFF444746),
            ),
            tooltip: 'Favorite',
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF444746)),
            tooltip: 'Share Contact',
            onPressed: () => _copyToClipboard(
              '${student.fullName} (Roll: ${student.rollNo}) - ID: ${student.nationalStudentId}',
              'Student Details',
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF444746)),
            onSelected: (val) {
              if (val == 'id') _showStudentIdBadgeDialog();
              if (val == 'academic') _openLifelongAcademicRecord();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'academic',
                child: Text('View Lifelong Record (KG → PhD)'),
              ),
              const PopupMenuItem(
                value: 'id',
                child: Text('View Smart ID Card'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Google Contact Hero Profile Section
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: avatarColor,
                  child: Text(
                    avatarInitial,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  student.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F1F1F),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Grade 5-A (Primary) • Roll: ${student.rollNo}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Google Contacts Quick Action Row (Call, Message, Academic, ID)
          _buildQuickActionButtons(),
          const SizedBox(height: 24),

          // Card 1: Contact Info (Google Contacts style)
          _buildContactInfoCard(guardianPhone),
          const SizedBox(height: 16),

          // Card 2: Academic & Attendance Profile (9.1)
          _buildAcademicProfileCard(),
          const SizedBox(height: 16),

          // Card 3: Whole-Child 5-Pillars Holistic Development (9.2 - 9.5)
          _buildWholeChildPillarsCard(),
          const SizedBox(height: 16),

          // Card 4: Teacher Notes & Observations
          _buildTeacherNotesCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Google Contacts 4-button quick action row
  Widget _buildQuickActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionCircle(
          icon: Icons.call_outlined,
          label: 'Call',
          color: const Color(0xFF1E8E3E),
          onTap: _callGuardian,
        ),
        _buildActionCircle(
          icon: Icons.message_outlined,
          label: 'Message',
          color: const Color(0xFF1A73E8),
          onTap: _openChatWithGuardian,
        ),
        _buildActionCircle(
          icon: Icons.school_outlined,
          label: 'KG → PhD',
          color: const Color(0xFF9334E6),
          onTap: _openLifelongAcademicRecord,
        ),
        _buildActionCircle(
          icon: Icons.badge_outlined,
          label: 'ID Badge',
          color: const Color(0xFFE37400),
          onTap: _showStudentIdBadgeDialog,
        ),
      ],
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 1: Contact & Identity Info
  Widget _buildContactInfoCard(String guardianPhone) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Contact info',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F1F1F),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_outlined, color: Color(0xFF1E8E3E)),
            title: Text(
              guardianPhone,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F1F1F),
              ),
            ),
            subtitle: const Text('Guardian Mobile (အုပ်ထိန်းသူဖုန်း)'),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: Color(0xFF1E8E3E), size: 20),
              onPressed: _callGuardian,
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.email_outlined, color: Color(0xFF1A73E8)),
            title: Text(
              widget.student.studentId,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F1F1F),
              ),
            ),
            subtitle: const Text('Student Account (ကျောင်းသားအကောင့်)'),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
              onPressed: () => _copyToClipboard(widget.student.studentId, 'Email'),
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.badge_outlined, color: Color(0xFFE37400)),
            title: Text(
              widget.student.nationalStudentId,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F1F1F),
              ),
            ),
            subtitle: const Text('National Student ID (MoE)'),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
              onPressed: () => _copyToClipboard(widget.student.nationalStudentId, 'National ID'),
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: Color(0xFF9334E6)),
            title: Text(
              'did:edu:mm:student:${widget.student.rollNo.toLowerCase()}',
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Color(0xFF1F1F1F),
              ),
            ),
            subtitle: const Text('W3C Decentralized Identifier (DID)'),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
              onPressed: () => _copyToClipboard(
                'did:edu:mm:student:${widget.student.rollNo.toLowerCase()}',
                'DID',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card 2: Academic Profile (9.1)
  Widget _buildAcademicProfileCard() {
    final s = widget.student;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.school_outlined, color: Color(0xFF1A73E8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    '9.1 Academic & Attendance',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E8E3E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'GPA: ${s.termGradePoint}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E8E3E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Attendance Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance: ${s.attendanceRatePct}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${s.sessionsPresent} Present / ${s.sessionsAbsent} Absent',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (s.attendanceRatePct / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1E8E3E)),
            ),
          ),
          const SizedBox(height: 16),

          // Exam Scores
          const Text(
            'Exam Scores (စာမေးပွဲ ရမှတ်များ)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: s.examScores.entries.map((e) {
              final subjectName = e.key.replaceAll('_', ' ').toUpperCase();
              final score = e.value;
              final isHigh = score >= 85;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isHigh
                      ? const Color(0xFF1E8E3E).withValues(alpha: 0.08)
                      : const Color(0xFF1A73E8).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isHigh
                        ? const Color(0xFF1E8E3E).withValues(alpha: 0.3)
                        : const Color(0xFF1A73E8).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '$subjectName: ${score.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isHigh ? const Color(0xFF1E8E3E) : const Color(0xFF1A73E8),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Competencies
          const Text(
            'Competencies Mastered',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: s.competencies
                .map(
                  (c) => Chip(
                    label: Text(c, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(color: Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),

          // Action button to view lifelong record
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.history_edu, size: 18),
              label: const Text('View Lifelong Academic Record (KG to PhD Level)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFF818CF8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _openLifelongAcademicRecord,
            ),
          ),
        ],
      ),
    );
  }

  /// Card 3: Whole-Child 5-Pillar Holistic Development
  Widget _buildWholeChildPillarsCard() {
    final s = widget.student;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_outline, color: Color(0xFFD93025), size: 20),
              SizedBox(width: 8),
              Text(
                'Whole-Child Holistic Profile (9.2 - 9.5)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F1F1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 9.2 Physical Growth
          _buildPillarRow(
            icon: Icons.fitness_center_outlined,
            title: '9.2 Physical Growth',
            color: const Color(0xFFE37400),
            body: '${s.heightCm} cm • ${s.weightKg} kg • BMI ${s.calculatedBmi} (${s.bmiCategory})\nSports: ${s.preferredSports.join(', ')}',
          ),
          const Divider(height: 20),

          // 9.3 Health Profile
          _buildPillarRow(
            icon: Icons.health_and_safety_outlined,
            title: '9.3 Health Visibility',
            color: const Color(0xFF1E8E3E),
            body: 'Vision: ${s.visionCheck} • Hearing: ${s.hearingCheck}\nDeworming: ${s.dewormingCompleted ? "Completed" : "Pending"}${s.knownAllergies.isNotEmpty ? "\nAllergies: ${s.knownAllergies.join(', ')}" : ""}',
          ),
          const Divider(height: 20),

          // 9.4 Wellbeing
          _buildPillarRow(
            icon: Icons.mood_outlined,
            title: '9.4 Socio-Emotional Wellbeing',
            color: const Color(0xFF1A73E8),
            body: 'Dominant Mood: ${s.dominantEmotionalState}\nEngagement: ${s.engagementIndex} / 5.0 (Active & Enthusiastic)',
          ),
          const Divider(height: 20),

          // 9.5 Social Participation & Citizenship
          _buildPillarRow(
            icon: Icons.groups_outlined,
            title: '9.5 Citizenship & Participation',
            color: const Color(0xFF9334E6),
            body: 'Role: ${s.leadershipRole}\nClub: ${s.clubName}\nBadges: ${s.citizenshipBadges.join(', ')}',
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow({
    required IconData icon,
    required String title,
    required Color color,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Card 4: Teacher Notes
  Widget _buildTeacherNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note_outlined, color: Color(0xFF1E293B), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Teacher Observations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF1E8E3E), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Synced',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E8E3E),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              widget.student.teacherNotes.isNotEmpty
                  ? widget.student.teacherNotes
                  : 'Punctual, displays strong curiosity during group activities and demonstrates good citizenship.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
