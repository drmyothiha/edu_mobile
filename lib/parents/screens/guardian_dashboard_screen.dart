import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/guardian_child.dart';
import '../../models/lifelong_academic_record.dart';
import '../../widgets/lifelong_academic_record_sheet.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class GuardianDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final VoidCallback? onSwitchRole;

  const GuardianDashboardScreen({
    super.key,
    this.onNavigateTab,
    this.onSwitchRole,
  });

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  List<GuardianChild> _children = [];
  int _selectedChildIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuardianData();
  }

  Future<void> _loadGuardianData({bool refreshNetwork = true}) async {
    setState(() => _isLoading = true);
    var children = await StorageService.getGuardianChildren();
    var savedIndex = await StorageService.getSelectedChildIndex();

    if (mounted) {
      setState(() {
        _children = children;
        _selectedChildIndex = (savedIndex < children.length) ? savedIndex : 0;
        _isLoading = false;
      });
    }

    if (refreshNetwork) {
      try {
        final serverChildren = await ApiService.getMyChildren();
        if (mounted && serverChildren.isNotEmpty) {
          savedIndex = await StorageService.getSelectedChildIndex();
          setState(() {
            _children = serverChildren;
            _selectedChildIndex =
                (savedIndex < serverChildren.length) ? savedIndex : 0;
          });
        }
      } catch (e) {
        debugPrint('Failed to refresh guardian children from network: $e');
      }
    }
  }

  void _selectChild(int index) {
    setState(() {
      _selectedChildIndex = index;
    });
    StorageService.setSelectedChildIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final child =
        _children.isNotEmpty ? _children[_selectedChildIndex] : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: child == null
          ? RefreshIndicator(
              onRefresh: () => _loadGuardianData(refreshNetwork: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(
                    child: Text('No enrolled children found'),
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadGuardianData(refreshNetwork: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Simple Child Switcher
                    if (_children.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_children.length, (index) {
                            final c = _children[index];
                            final isSelected = index == _selectedChildIndex;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  c.fullName,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textMain,
                                ),
                                onSelected: (_) => _selectChild(index),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 1. Clean Child Info Card (Name, Age, Grade)
                    _buildChildHeaderCard(child),
                    const SizedBox(height: 16),

                    // 2. Clean Report Section
                    _buildReportSection(child),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildChildAvatarImage(GuardianChild child) {
    if (child.photoUrl != null && child.photoUrl!.isNotEmpty) {
      final url = child.photoUrl!;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return Image.network(
          url,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackInitial(child),
        );
      } else if (url.startsWith('data:image')) {
        try {
          final commaIndex = url.indexOf(',');
          final base64Str =
              commaIndex != -1 ? url.substring(commaIndex + 1) : url;
          return Image.memory(
            base64Decode(base64Str),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackInitial(child),
          );
        } catch (_) {
          return _buildFallbackInitial(child);
        }
      } else if (!kIsWeb) {
        final file = File(url);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackInitial(child),
          );
        }
      }
    }
    return _buildFallbackInitial(child);
  }

  Widget _buildFallbackInitial(GuardianChild child) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(
        child.fullName.isNotEmpty ? child.fullName[0] : 'S',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, GuardianChild child) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _updateChildPhoto(child, pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick photo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _updateChildPhoto(
      GuardianChild child, String? newPhotoPath) async {
    final updatedChild = child.copyWith(photoUrl: newPhotoPath);
    setState(() {
      _children[_selectedChildIndex] = updatedChild;
    });
    await StorageService.saveGuardianChildren(_children);

    try {
      final res = await ApiService.uploadChildPhoto(child.id, newPhotoPath);
      final remoteUrl = res['photo_url']?.toString();
      if (remoteUrl != null &&
          remoteUrl.isNotEmpty &&
          remoteUrl != newPhotoPath) {
        final syncedChild = child.copyWith(photoUrl: remoteUrl);
        if (mounted) {
          setState(() {
            _children[_selectedChildIndex] = syncedChild;
          });
        }
        await StorageService.saveGuardianChildren(_children);
      }
    } catch (e) {
      debugPrint('[GuardianDashboard] Photo sync error: $e');
    }
  }

  void _showPhotoOptions(GuardianChild child) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${child.fullName}\'s Photo',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera, child);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.purple),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery, child);
                },
              ),
              if (child.photoUrl != null && child.photoUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateChildPhoto(child, null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLifelongRecord(GuardianChild child) {
    final profile = LifelongAcademicProfile.fromStudentData(
      studentId: child.id,
      studentName: child.fullName,
      rollNo: child.rollNo,
      gradeLevel: child.gradeLevel,
      nationalStudentId: child.nationalStudentId,
      photoUrl: child.photoUrl,
      schoolName: child.schoolName,
    );
    showLifelongAcademicRecordModal(context, profile: profile);
  }

  // Clean Card: Name, Age, Grade
  Widget _buildChildHeaderCard(GuardianChild child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showPhotoOptions(child),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _buildChildAvatarImage(child),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildSimpleBadge(
                          label: 'Age ${child.age}',
                          icon: Icons.cake_outlined,
                          color: AppTheme.primary,
                        ),
                        _buildSimpleBadge(
                          label: child.gradeLevel,
                          icon: Icons.school_outlined,
                          color: const Color(0xFF047857),
                        ),
                        InkWell(
                          onTap: () => _showLifelongRecord(child),
                          borderRadius: BorderRadius.circular(10),
                          child: _buildSimpleBadge(
                            label: 'KG → PhD Record',
                            icon: Icons.history_edu,
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showLifelongRecord(child),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.history_edu, size: 18, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lifelong Academic Record (KG to PhD Level)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4338CA),
                          ),
                        ),
                        Text(
                          'View verified timeline & highest level attained',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: Color(0xFF4F46E5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  bool _isKG(GuardianChild child) {
    final grade = child.gradeLevel.toLowerCase();
    final cls = child.className.toLowerCase();
    return grade.contains('kg') ||
        grade.contains('kindergarten') ||
        cls.contains('kg') ||
        child.age <= 5;
  }

  // Clean Report Card Section
  Widget _buildReportSection(GuardianChild child) {
    final isKG = _isKG(child);
    final scores = child.examScores.isNotEmpty
        ? child.examScores
        : {
            'myanmar': 88.0,
            'english': 82.0,
            'mathematics': 95.0,
            'science': 84.0,
          };

    return Container(
      padding: const EdgeInsets.all(20),
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
              Row(
                children: [
                  Icon(
                    Icons.assessment_outlined,
                    size: 22,
                    color: isKG ? const Color(0xFF047857) : AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _showLifelongRecord(child),
                    icon: const Icon(
                      Icons.history_edu,
                      size: 15,
                      color: Color(0xFF4F46E5),
                    ),
                    label: const Text(
                      'KG → PhD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showReportCardSheet(child),
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: const Text(
                      'Full Report',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isKG)
            _buildKGDomainSummaryList()
          else
            Column(
              children: scores.entries.map((entry) {
                final score = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMain,
                        ),
                      ),
                      Text(
                        '${score.toStringAsFixed(0)} / 100',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildKGDomainSummaryList() {
    final domains = [
      {'title': 'ကာယနှင့် ကျန်းမာရေး', 'stars': '★★★', 'status': 'Mastered'},
      {'title': 'စာရိတ္တ၊ စိတ်ခံစားမှု', 'stars': '★★★', 'status': 'Mastered'},
      {'title': 'ဆက်သွယ်ပြောဆိုရေး', 'stars': '★★☆', 'status': 'Developing'},
      {'title': 'သင်္ချာနှင့် အရေအတွက်', 'stars': '★★★', 'status': 'Mastered'},
      {'title': 'အနုပညာ၊ တီထွင်မှု', 'stars': '★★★', 'status': 'Mastered'},
      {'title': 'ပတ်ဝန်းကျင်လောက', 'stars': '★★☆', 'status': 'Developing'},
    ];

    return Column(
      children: domains.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  d['title']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              Text(
                '${d['stars']}  ${d['status']}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showReportCardSheet(GuardianChild child) {
    if (_isKG(child)) {
      _showKGReportCardSheet(child);
      return;
    }

    final scores = child.examScores.isNotEmpty
        ? child.examScores
        : {
            'myanmar': 88.0,
            'english': 82.0,
            'mathematics': 95.0,
            'science': 84.0,
          };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      child.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Age ${child.age} • ${child.gradeLevel}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(height: 28),
                const Text(
                  'Academic Report',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: scores.entries.map((entry) {
                      final score = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade100),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${score.toStringAsFixed(0)} / 100',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF818CF8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.history_edu, size: 18),
                    label: const Text(
                      'View Lifelong Academic Record (KG to PhD Level)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showLifelongRecord(child);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showKGReportCardSheet(GuardianChild child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      child.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Age ${child.age} • ${child.gradeLevel}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(height: 28),
                const Text(
                  'Kindergarten Report (နယ်ပယ် ၆ ခု)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _buildKGDomainSummaryList(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF818CF8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.history_edu, size: 18),
                    label: const Text(
                      'View Lifelong Academic Record (KG to PhD Level)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showLifelongRecord(child);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
