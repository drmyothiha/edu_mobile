import 'package:flutter/material.dart';
import '../models/lifelong_academic_record.dart';

/// Interactive modal sheet displaying a student's lifelong academic record
/// in a clean, modern White Theme with high-contrast monochrome accents,
/// with a vertical timeline running from KG at the lowest (bottom) to the Latest Class at the topmost (top).
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
  // 'all', 'active_only', or specific stage code e.g. 'KG', 'BEPS'
  String _selectedFilter = 'all';

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

    // Timeline ONLY shows up to the highest active level
    // (with highest active class at the TOPMOST and KG at the LOWEST/bottom)
    final entriesUpToActive = widget.profile.completedAndCurrentEntries;

    List<AcademicRecordEntry> timelineEntries;
    if (_selectedFilter == 'all' || _selectedFilter == 'active_only') {
      timelineEntries = entriesUpToActive.reversed.toList();
    } else {
      final matches = entriesUpToActive
          .where((e) => e.stageCode.toUpperCase() == _selectedFilter.toUpperCase())
          .toList();
      timelineEntries = matches.isNotEmpty ? matches : entriesUpToActive.reversed.toList();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.60,
      maxChildSize: 0.96,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white, // Clean modern white theme
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -6),
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
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Top Header Bar in White Theme
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(Icons.history_edu, color: Color(0xFF0F172A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lifelong Academic Record',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'KG to PhD Level Educational Trajectory (တစ်သက်တာ ပညာသင်မှတ်တမ်း)',
                          style: TextStyle(
                            color: Color(0xFF64748B),
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
                    icon: const Icon(Icons.close, color: Color(0xFF0F172A), size: 22),
                  ),
                ],
              ),
            ),

            Divider(color: Colors.grey.shade200, height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Student Identity & Highest Level Banner (White Theme)
                    _buildStudentIdentityBanner(highestEntry),
                    const SizedBox(height: 16),

                    // 2. Timeline Bar with KG lowest & Latest class topmost (up to highest active)
                    _buildTrajectoryTimelineBar(highestEntry),
                    const SizedBox(height: 16),

                    // 3. Filter Controls (White Theme)
                    _buildFilterControls(highestEntry),
                    const SizedBox(height: 16),

                    // 4. Timeline Header Indicator (Latest Topmost -> KG Lowest)
                    _buildTimelineDirectionIndicator(),
                    const SizedBox(height: 12),

                    // 5. Academic Record Timeline Cards (Latest Topmost down to KG Lowest)
                    if (timelineEntries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          'No records matching selected filter.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else
                      ...List.generate(timelineEntries.length, (idx) {
                        final entry = timelineEntries[idx];
                        return _buildTimelineItem(
                          entry: entry,
                          index: idx,
                          total: timelineEntries.length,
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Student Identity Banner styled in White Theme with clean dark borders
  Widget _buildStudentIdentityBanner(AcademicRecordEntry highestEntry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade700,
                child: Text(
                  widget.profile.studentName.isNotEmpty
                      ? widget.profile.studentName[0].toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    color: Colors.white,
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
                              color: Color(0xFF0F172A),
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
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            widget.profile.rollNo,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
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
                        color: Color(0xFF64748B),
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
          Divider(color: Colors.grey.shade300, height: 1),
          const SizedBox(height: 12),

          // Highest Level Highlight Card (White Card with Solid Black Tag)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1.0),
            ),
            child: Row(
              children: [
                Icon(_getStageIcon(highestEntry.stage), color: const Color(0xFF0F172A), size: 22),
                const SizedBox(width: 12),
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
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'HIGHEST LEVEL ATTAINED / ACTIVE',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            highestEntry.academicYears,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        highestEntry.levelTitle,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        highestEntry.degreeOrCertificate,
                        style: const TextStyle(
                          color: Color(0xFF475569),
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

  /// Trajectory Stepper Bar in White Theme (shows up to highest active level)
  Widget _buildTrajectoryTimelineBar(AcademicRecordEntry highestEntry) {
    final activeEntries = widget.profile.completedAndCurrentEntries;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.timeline, color: Color(0xFF0F172A), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Active Pathway: ${activeEntries.map((e) => e.stageCode).join(' ➔ ')}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
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
              children: activeEntries.map((entry) {
                final isSelected =
                    _selectedFilter.toUpperCase() == entry.stageCode.toUpperCase();
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
                          ? Colors.grey.shade800
                          : isCurrentOrCompleted
                              ? Colors.white
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.grey.shade600
                            : isCurrentOrCompleted
                                ? Colors.grey.shade300
                                : Colors.grey.shade200,
                        width: 1.0,
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
                              color: isSelected
                                  ? Colors.white
                                  : entry.isHighestActiveLevel
                                      ? Colors.black
                                      : entry.isCompleted
                                          ? const Color(0xFF1E293B)
                                          : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.stageCode,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : isCurrentOrCompleted
                                        ? const Color(0xFF0F172A)
                                        : Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
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
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : entry.isHighestActiveLevel
                                    ? const Color(0xFF0F172A)
                                    : Colors.grey.shade600,
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

  /// Filter Controls styled in White Theme
  Widget _buildFilterControls(AcademicRecordEntry highestEntry) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Timeline (KG → ${highestEntry.stageCode})',
            filterKey: 'all',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Highest Active (${highestEntry.stageCode})',
            filterKey: 'active_only',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required String filterKey}) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.grey.shade600 : Colors.grey.shade300,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Indicator highlighting the requested timeline direction:
  /// From Latest Class (TOPMOST) down to Kindergarten (LOWEST)
  Widget _buildTimelineDirectionIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_upward, size: 14, color: Color(0xFF0F172A)),
              SizedBox(width: 6),
              Text(
                'LATEST CLASS (TOPMOST)',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Icon(Icons.more_vert, size: 14, color: Colors.grey),
          Row(
            children: [
              Text(
                'KG LEVEL (LOWEST)',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.arrow_downward, size: 14, color: Color(0xFF475569)),
            ],
          ),
        ],
      ),
    );
  }

  /// Individual Timeline Card connected via a vertical timeline line
  Widget _buildTimelineItem({
    required AcademicRecordEntry entry,
    required int index,
    required int total,
  }) {
    final isTopmost = index == 0;
    final isLowest = index == total - 1;
    final isLatestActive = entry.isHighestActiveLevel;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical Timeline Line & Node in White Theme
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Top line
                Container(
                  width: 2,
                  height: isTopmost ? 14 : 18,
                  color: isTopmost ? Colors.transparent : Colors.grey.shade300,
                ),
                // Timeline Node
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isLatestActive ? Colors.grey.shade700 : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isLatestActive ? Colors.grey.shade500 : Colors.grey.shade300,
                      width: isLatestActive ? 2 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isLatestActive
                          ? Icons.star
                          : entry.isCompleted
                              ? Icons.check
                              : Icons.circle,
                      size: isLatestActive ? 12 : 10,
                      color: isLatestActive ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
                // Bottom connecting line
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLowest ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Main Academic Entry Card
          Expanded(
            child: _buildAcademicEntryCard(entry),
          ),
        ],
      ),
    );
  }

  /// Academic Entry Card in clean White Theme
  Widget _buildAcademicEntryCard(AcademicRecordEntry entry) {
    final isLatestActive = entry.isHighestActiveLevel;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatestActive
              ? Colors.grey.shade400
              : entry.isCompleted
                  ? Colors.grey.shade300
                  : Colors.grey.shade200,
          width: isLatestActive ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header in White Theme
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isLatestActive
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Icon(
                    _getStageIcon(entry.stage),
                    color: const Color(0xFF0F172A),
                    size: 18,
                  ),
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
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              entry.levelTitle,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
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
                          color: Color(0xFF64748B),
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
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),

                // Institution & Years
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.institution,
                        style: const TextStyle(
                          color: Color(0xFF475569),
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
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        entry.academicYears,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Performance & Grade Badge (White Theme)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_outlined, size: 15, color: Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.performanceRating,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.stage == AcademicStage.phd
                              ? 'DOCTORAL DISSERTATION'
                              : 'CAPSTONE / THESIS',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '"${entry.thesisOrCapstoneTitle}"',
                          style: const TextStyle(
                            color: Color(0xFF334155),
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
                      color: Color(0xFF64748B),
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
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Status Pill in White Theme
  Widget _buildStatusPill(AcademicRecordEntry entry) {
    if (entry.isHighestActiveLevel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'HIGHEST ACTIVE',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else if (entry.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 1.0),
        ),
        child: Text(
          'COMPLETED',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'PATHWAY',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
  }
}
