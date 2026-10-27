import 'package:flutter/material.dart';
import '../models/lifelong_academic_record.dart';

/// Interactive modal sheet displaying a student's lifelong academic record from KG to PhD level (or highest level).
void showLifelongAcademicRecordModal(
  BuildContext context, {
  required LifelongAcademicProfile profile,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => LifelongAcademicRecordSheet(profile: profile),
  );
}

class LifelongAcademicRecordSheet extends StatefulWidget {
  final LifelongAcademicProfile profile;

  const LifelongAcademicRecordSheet({super.key, required this.profile});

  @override
  State<LifelongAcademicRecordSheet> createState() =>
      _LifelongAcademicRecordSheetState();
}

class _LifelongAcademicRecordSheetState
    extends State<LifelongAcademicRecordSheet> {
  // 'all', 'active_only', or specific stage code e.g. 'KG', 'PHD'
  String _selectedFilter = 'all';
  final Set<String> _expandedCredentials = {};

  Color _getStageColor(AcademicStage stage) {
    switch (stage) {
      case AcademicStage.kg:
        return const Color(0xFFF59E0B); // Amber
      case AcademicStage.primary:
        return const Color(0xFF10B981); // Emerald
      case AcademicStage.middleSchool:
        return const Color(0xFF0EA5E9); // Sky blue
      case AcademicStage.highSchool:
        return const Color(0xFF6366F1); // Indigo
      case AcademicStage.bachelor:
        return const Color(0xFF2563EB); // Royal Blue
      case AcademicStage.master:
        return const Color(0xFF9333EA); // Purple
      case AcademicStage.phd:
        return const Color(0xFFE11D48); // Rose / Crimson
    }
  }

  IconData _getStageIcon(AcademicStage stage) {
    switch (stage) {
      case AcademicStage.kg:
        return Icons.toys_outlined;
      case AcademicStage.primary:
        return Icons.child_care_outlined;
      case AcademicStage.middleSchool:
        return Icons.menu_book_outlined;
      case AcademicStage.highSchool:
        return Icons.school_outlined;
      case AcademicStage.bachelor:
        return Icons.account_balance_outlined;
      case AcademicStage.master:
        return Icons.workspace_premium_outlined;
      case AcademicStage.phd:
        return Icons.psychology_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final highestEntry = widget.profile.highestLevelEntry;
    final highestColor = _getStageColor(highestEntry.stage);

    final filteredEntries = widget.profile.entries.where((e) {
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'active_only') {
        return e.status != AcademicStatus.pathway;
      }
      return e.stageCode.toUpperCase() == _selectedFilter.toUpperCase();
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.60,
      maxChildSize: 0.96,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117), // Premium dark background
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal grab handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: highestColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.history_edu, color: highestColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lifelong Academic Record',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'KG to PhD Level Educational Trajectory (တစ်သက်တာ ပညာသင်မှတ်တမ်း)',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF21262D), height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Student Identity & Highest Level Banner
                    _buildStudentIdentityBanner(highestEntry, highestColor),
                    const SizedBox(height: 16),

                    // 2. Interactive KG-to-PhD Trajectory Timeline
                    _buildTrajectoryTimelineBar(),
                    const SizedBox(height: 16),

                    // 3. Filter Controls
                    _buildFilterControls(),
                    const SizedBox(height: 14),

                    // 4. Academic Record Cards List
                    if (filteredEntries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Text(
                          'No records matching selected filter.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    else
                      ...filteredEntries.map(
                        (entry) => _buildAcademicEntryCard(entry),
                      ),

                    const SizedBox(height: 12),

                    // 5. Verification & Official Export Footer
                    _buildExportAndAttestationFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentIdentityBanner(
    AcademicRecordEntry highestEntry,
    Color highestColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF161B22),
            highestColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highestColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: highestColor.withValues(alpha: 0.25),
                child: Text(
                  widget.profile.studentName.isNotEmpty
                      ? widget.profile.studentName[0].toUpperCase()
                      : 'S',
                  style: TextStyle(
                    color: highestColor,
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
                            widget.profile.studentName,
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
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.profile.rollNo,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'National ID: ${widget.profile.nationalStudentId}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF30363D), height: 1),
          const SizedBox(height: 12),

          // Highest Level Highlight Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highestColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(_getStageIcon(highestEntry.stage), color: highestColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: highestColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HIGHEST LEVEL ATTAINED / ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            highestEntry.academicYears,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        highestEntry.levelTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        highestEntry.degreeOrCertificate,
                        style: TextStyle(
                          color: highestColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrajectoryTimelineBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Icon(Icons.timeline, color: Color(0xFF38BDF8), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'KG ➔ Primary ➔ Middle ➔ High ➔ Bachelor ➔ Master ➔ PhD',
                    style: TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.profile.entries.map((entry) {
                final isSelected =
                    _selectedFilter.toUpperCase() == entry.stageCode.toUpperCase();
                final stageColor = _getStageColor(entry.stage);
                final isCurrentOrCompleted = entry.status != AcademicStatus.pathway;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter =
                          _selectedFilter == entry.stageCode ? 'all' : entry.stageCode;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? stageColor.withValues(alpha: 0.25)
                          : isCurrentOrCompleted
                              ? const Color(0xFF21262D)
                              : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? stageColor
                            : isCurrentOrCompleted
                                ? stageColor.withValues(alpha: 0.4)
                                : const Color(0xFF30363D),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              entry.isHighestActiveLevel
                                  ? Icons.star
                                  : entry.isCompleted
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                              size: 13,
                              color: entry.isHighestActiveLevel
                                  ? const Color(0xFFFBBF24)
                                  : entry.isCompleted
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.stageCode,
                              style: TextStyle(
                                color: isCurrentOrCompleted ? Colors.white : Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.isHighestActiveLevel
                              ? 'Active'
                              : entry.isCompleted
                                  ? 'Done'
                                  : 'Target',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: entry.isHighestActiveLevel
                                ? const Color(0xFFFBBF24)
                                : entry.isCompleted
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControls() {
    return Row(
      children: [
        _buildFilterChip(label: 'All Levels (KG to PhD)', filterKey: 'all'),
        const SizedBox(width: 8),
        _buildFilterChip(
          label: 'Highest Level & Completed',
          filterKey: 'active_only',
        ),
      ],
    );
  }

  Widget _buildFilterChip({required String label, required String filterKey}) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4C8DFF).withValues(alpha: 0.2)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4C8DFF) : const Color(0xFF30363D),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicEntryCard(AcademicRecordEntry entry) {
    final stageColor = _getStageColor(entry.stage);
    final isCredentialExpanded = _expandedCredentials.contains(entry.stageCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isHighestActiveLevel
              ? stageColor.withValues(alpha: 0.6)
              : entry.isCompleted
                  ? const Color(0xFF30363D)
                  : const Color(0xFF21262D),
          width: entry.isHighestActiveLevel ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: stageColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getStageIcon(entry.stage), color: stageColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            entry.stageCode,
                            style: TextStyle(
                              color: stageColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              entry.levelTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        entry.burmeseTitle,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(entry),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Degree / Certificate Title
                Text(
                  entry.degreeOrCertificate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),

                // Institution & Years
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.institution,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.academicYears,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Performance & Grade Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_outlined, size: 15, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.performanceRating,
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Thesis Title if present
                if (entry.thesisOrCapstoneTitle != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: stageColor.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.stage == AcademicStage.phd
                              ? 'DOCTORAL DISSERTATION'
                              : 'CAPSTONE / THESIS',
                          style: TextStyle(
                            color: stageColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '"${entry.thesisOrCapstoneTitle}"',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Competencies tags
                if (entry.competencies.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Key Competencies & Subjects:',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: entry.competencies.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Honors
                if (entry.honors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entry.honors.map((h) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.verified,
                                size: 12,
                                color: Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                h,
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 10),
                const Divider(color: Color(0xFF21262D), height: 1),
                const SizedBox(height: 8),

                // Verifiable Credential Expansion
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isCredentialExpanded) {
                        _expandedCredentials.remove(entry.stageCode);
                      } else {
                        _expandedCredentials.add(entry.stageCode);
                      }
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_outlined, size: 14, color: Color(0xFF60A5FA)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'W3C Verifiable Credential & Blockchain Proof',
                          style: TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        isCredentialExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: const Color(0xFF93C5FD),
                      ),
                    ],
                  ),
                ),

                if (isCredentialExpanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProofField('Credential URI', entry.credentialId),
                        const SizedBox(height: 4),
                        _buildProofField(
                          'Polygon Proof Hash',
                          entry.blockchainProofHash,
                        ),
                        const SizedBox(height: 4),
                        _buildProofField(
                          'Issuing Authority',
                          'Ministry of Education (DBE) & University Academic Senate',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(AcademicRecordEntry entry) {
    if (entry.isHighestActiveLevel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3B82F6)),
        ),
        child: const Text(
          'HIGHEST ACTIVE',
          style: TextStyle(
            color: Color(0xFF93C5FD),
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else if (entry.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF059669).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: const Text(
          'COMPLETED',
          style: TextStyle(
            color: Color(0xFF34D399),
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'PATHWAY',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
  }

  Widget _buildProofField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontFamily: 'monospace',
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildExportAndAttestationFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFF34D399), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Comprehensive Lifelong Learner Record (CLR)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Cryptographically verifiable from early childhood (KG) to doctoral (PhD) completion. Compliant with W3C Verifiable Credentials and Myanmar National Qualifications Framework (MNQF).',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.download_done, size: 18),
              label: const Text(
                'Export Verifiable Lifelong Transcript (KG → PhD)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
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
                            'Official Lifelong Transcript generated for ${widget.profile.studentName} (KG to ${widget.profile.highestLevelEntry.stageCode})',
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
