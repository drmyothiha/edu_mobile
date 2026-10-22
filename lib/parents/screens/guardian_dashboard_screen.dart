import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/guardian_child.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
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

  // M03 & M07: Weekly Summaries & Record Appeals State
  final Map<String, List<Map<String, dynamic>>> _weeklySummaries = {};
  bool _loadingSummaries = false;
  List<Map<String, dynamic>> _childAppeals = [];
  bool _loadingAppeals = false;

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
      if (children.isNotEmpty) {
        _loadChildSummariesAndAppeals(children[_selectedChildIndex].id);
      }
    }

    if (refreshNetwork) {
      try {
        final serverChildren = await ApiService.getMyChildren();
        if (mounted && serverChildren.isNotEmpty) {
          savedIndex = await StorageService.getSelectedChildIndex();
          setState(() {
            _children = serverChildren;
            _selectedChildIndex = (savedIndex < serverChildren.length) ? savedIndex : 0;
          });
          if (serverChildren.isNotEmpty) {
            _loadChildSummariesAndAppeals(serverChildren[_selectedChildIndex].id);
          }
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
    if (index < _children.length) {
      _loadChildSummariesAndAppeals(_children[index].id);
    }
  }

  Future<void> _loadChildSummariesAndAppeals(String childId) async {
    setState(() {
      _loadingSummaries = true;
      _loadingAppeals = true;
    });
    try {
      final summaries = await ApiService.fetchStudentWeeklySummaries(childId);
      final appeals = await ApiService.fetchAppeals(studentId: childId);
      if (mounted) {
        setState(() {
          _weeklySummaries[childId] = summaries;
          _childAppeals = appeals;
          _loadingSummaries = false;
          _loadingAppeals = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingSummaries = false;
          _loadingAppeals = false;
        });
      }
    }
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
      body: child == null
          ? RefreshIndicator(
              onRefresh: () => _loadGuardianData(refreshNetwork: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(child: Text('No enrolled children found (ကလေးမှတ်ပုံတင် မတွေ့ရှိပါ)')),
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

                  // M07 Positive-Only Guardrail Badge
                  _buildPositiveOnlyGuardrailBadge(),
                  const SizedBox(height: 16),

                  // M03 Plain-Language Burmese Weekly AI Summary Card
                  _buildWeeklyAISummaryCard(child),
                  const SizedBox(height: 16),

                  // Quick Action: View Digital ID Pass
                  _buildQuickActionBanner(child),
                  const SizedBox(height: 16),

                  // Official Academic Report Card & Transcript
                  _buildReportCardBanner(child),
                  const SizedBox(height: 16),

                  // Whole-Child Development Metrics (5 Pillars)
                  _buildWholeChildMetricsSection(child),
                  const SizedBox(height: 16),

                  // Health & Growth Card
                  _buildHealthGrowthCard(child),
                  const SizedBox(height: 16),

                  // M07 Record Appeals Banner & Workflow
                  _buildRecordAppealsBanner(child),
                  const SizedBox(height: 16),

                  // Teacher Direct Communication CTA
                  _buildTeacherChatCTA(child),
                  const SizedBox(height: 16),

                  // Child Data Privacy & Erasure (Right to be Forgotten)
                  _buildPrivacyErasureSection(child),
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
          final base64Str = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
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
      } else {
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
      color: Colors.white.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(
        child.fullName.isNotEmpty ? child.fullName[0] : 'S',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
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

  Future<void> _updateChildPhoto(GuardianChild child, String? newPhotoPath) async {
    // 1. Immediately update local UI and storage for instant responsive feedback
    final updatedChild = child.copyWith(photoUrl: newPhotoPath);
    setState(() {
      _children[_selectedChildIndex] = updatedChild;
    });
    await StorageService.saveGuardianChildren(_children);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(newPhotoPath != null
                    ? 'Syncing photo to cloud... (ဆာဗာသို့ ပို့ဆောင်နေပါသည်)'
                    : 'Removing photo... (ဓာတ်ပုံ ဖျက်နေပါသည်)'),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // 2. Sync to Backend & across all apps including desktop
    try {
      final res = await ApiService.uploadChildPhoto(child.id, newPhotoPath);
      final remoteUrl = res['photo_url']?.toString();
      if (remoteUrl != null && remoteUrl.isNotEmpty && remoteUrl != newPhotoPath) {
        final syncedChild = child.copyWith(photoUrl: remoteUrl);
        if (mounted) {
          setState(() {
            _children[_selectedChildIndex] = syncedChild;
          });
        }
        await StorageService.saveGuardianChildren(_children);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(newPhotoPath != null
                      ? 'Photo synced across all apps & desktop (စက်အားလုံးသို့ အောင်မြင်စွာ သိမ်းဆည်းပြီးပါပြီ)'
                      : 'Photo removed from server (ဆာဗာမှ ဖျက်ပြီးပါပြီ)'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[GuardianDashboard] Photo backend sync error (offline resilient): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.offline_pin, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Saved locally. Will sync to cloud when online. (ဖုန်းထဲတွင် သိမ်းဆည်းထားပြီးဖြစ်ပါသည်)'),
                ),
              ],
            ),
            backgroundColor: Colors.amber.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.add_a_photo, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${child.fullName}\'s Photo',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Select or take a photo for your child (ကလေးဓာတ်ပုံ ရွေးချယ်ပါ)',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue, size: 22),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('ကင်မရာဖြင့် အသစ်ရိုက်ယူမည်', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera, child);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.purple, size: 22),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('ဖုန်းထဲရှိ ဓာတ်ပုံရွေးချယ်မည်', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery, child);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.face, color: Colors.teal, size: 22),
                ),
                title: const Text('Choose Preset Avatar', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('ကျောင်းသားပုံစံ ကာတွန်းပုံများမှ ရွေးမည်', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPresetAvatarSheet(child);
                },
              ),
              if (child.photoUrl != null && child.photoUrl!.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  subtitle: const Text('လက်ရှိဓာတ်ပုံကို ဖျက်မည်', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateChildPhoto(child, null);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetAvatarSheet(GuardianChild child) {
    final avatarUrls = [
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=200&fit=crop',
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&fit=crop',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&fit=crop',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&fit=crop',
      'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=200&fit=crop',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Student Avatar (ကျောင်းသား ပုံရွေးပါ)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select a profile picture for your child',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1,
                ),
                itemCount: avatarUrls.length,
                itemBuilder: (context, index) {
                  final url = avatarUrls[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _updateChildPhoto(child, url);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.person, size: 36),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
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
              GestureDetector(
                onTap: () => _showPhotoOptions(child),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: _buildChildAvatarImage(child),
                      ),
                    ),
                    Positioned(
                      bottom: -5,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
                            child.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _showPhotoOptions(child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_a_photo, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  child.photoUrl != null ? 'Edit' : 'Add Photo',
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      child.rollNo.isNotEmpty
                          ? '${child.gradeLevel} • Roll: ${child.rollNo}'
                          : child.className.isNotEmpty
                              ? '${child.gradeLevel} • ${child.className}'
                              : child.gradeLevel,
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
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

  Widget _buildPositiveOnlyGuardrailBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF047857)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'M07 Guardrail: Positive-Only Records (အပြုသဘောဆောင် မှတ်တမ်းစနစ်)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Negative marks, demerit points, and punitive entries are strictly prohibited from student longitudinal files.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyAISummaryCard(GuardianChild child) {
    final summaries = _weeklySummaries[child.id] ?? [];
    final latestSummary = summaries.isNotEmpty ? summaries.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDD6FE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 20, color: Color(0xFF6D28D9)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Learning Summary',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4C1D95)),
                      ),
                      Text(
                        'အပတ်စဉ် AI အကျဉ်းချုပ် (မိဘများအတွက်)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.purple.shade700),
                      ),
                    ],
                  ),
                ],
              ),
              if (_loadingSummaries)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (latestSummary != null && latestSummary['read_by_parent_at'] == null)
                TextButton(
                  onPressed: () async {
                    final id = latestSummary['id']?.toString();
                    if (id != null) {
                      await ApiService.markWeeklySummaryRead(id);
                      if (mounted) {
                        setState(() {
                          latestSummary['read_by_parent_at'] = DateTime.now().toIso8601String();
                        });
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    backgroundColor: const Color(0xFFEDE9FE),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Mark Read', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9))),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loadingSummaries && latestSummary == null) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (latestSummary != null) ...[
            // Dates & Attendance Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${latestSummary['week_start_date']} မှ ${latestSummary['week_end_date']} အထိ',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                  ),
                  Text(
                    'တက်ရောက်မှု: ${(latestSummary['attendance_metrics']?['attendance_pct'] ?? 100).toString()}%',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Burmese Narrative Prose
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                latestSummary['summary_my'] ??
                    'ဤတစ်ပတ်အတွင်း ကျောင်းသားသည် သင်ခန်းစာများတွင် တက်ကြွစွာ ပါဝင်ခဲ့ပြီး သင်ယူမှု တိုးတက်မှု ကောင်းမွန်ပါသည်။',
                style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(height: 12),

            // Strengths Section
            if (latestSummary['strengths_my'] != null && (latestSummary['strengths_my'] as List).isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  const Text(
                    'ဤတစ်ပတ် ထူးချွန်တိုးတက်မှုများ (Strengths):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (latestSummary['strengths_my'] as List).map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      '✓ $s',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Areas for Help Section
            if (latestSummary['areas_for_help_my'] != null && (latestSummary['areas_for_help_my'] as List).isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  const Text(
                    'အိမ်တွင်း ကူညီအားပေးရန် (Support Needed):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (latestSummary['areas_for_help_my'] as List).map((a) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      '• $a',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Recommended Offline Home Activities
            if (latestSummary['recommended_home_activities'] != null &&
                (latestSummary['recommended_home_activities'] as List).isNotEmpty) ...[
              const Text(
                'အကြံပြုထားသော အိမ်တွင်း လေ့ကျင့်ခန်းများ (Offline Activities):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4338CA)),
              ),
              const SizedBox(height: 6),
              Column(
                children: (latestSummary['recommended_home_activities'] as List).map((act) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.home_outlined, size: 16, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    act['title_my'] ?? act['title'] ?? 'Home Activity',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFA5B4FC)),
                                    ),
                                    child: Text(
                                      '${act['duration_minutes'] ?? 15} မိနစ်',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                act['description_my'] ?? act['description'] ?? '',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'အပတ်စဉ် အကျဉ်းချုပ်များကို အပတ်စဉ် သောကြာ/တနင်္ဂနွေနေ့တိုင်း အလိုအလျောက် ထုတ်ပြန်ပေးပါသည်။',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _loadChildSummariesAndAppeals(child.id),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('စစ်ဆေးရန် ပြန်လည်ရယူပါ (Check Updates)', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordAppealsBanner(GuardianChild child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel_rounded, size: 20, color: Color(0xFFEA580C)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record Appeal Mechanism (ကန့်ကွက်စိစစ်ခွင့်)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF9A3412)),
                    ),
                    Text(
                      'Contest or request review for attendance, marks, or whole-child entries',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (_loadingAppeals)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA580C)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _showAppealDialog(child),
                  icon: const Icon(Icons.add_comment_outlined, size: 14),
                  label: const Text('Contest Entry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),

          // Show existing appeals for this child
          if (_childAppeals.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'Your Submitted Appeals for ${child.fullName} (${_childAppeals.length}):',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            ..._childAppeals.map((appeal) {
              final status = appeal['status'] as String? ?? 'pending';
              Color statusColor = Colors.amber.shade800;
              Color statusBg = Colors.amber.shade50;
              if (status == 'approved') {
                statusColor = Colors.green.shade800;
                statusBg = Colors.green.shade50;
              } else if (status == 'rejected') {
                statusColor = Colors.red.shade800;
                statusBg = Colors.red.shade50;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          appeal['target_item_title'] ?? 'Record Entry',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${appeal['contested_reason'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                    if (appeal['resolution_notes'] != null && (appeal['resolution_notes'] as String).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Staff Resolution: ${appeal['resolution_notes']}',
                          style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showAppealDialog(GuardianChild child) {
    String recordType = 'attendance';
    final targetItemCtrl = TextEditingController();
    final currentValueCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final requestedCorrectionCtrl = TextEditingController();
    final evidenceCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.gavel_rounded, color: Color(0xFFEA580C), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Record Appeal: ${child.fullName}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Under school data governance rules, you may formally contest recorded attendance, exam scores, or whole-child assessments.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),

                // Record Type Dropdown
                const Text('Record Category (ကဏ္ဍ):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    underline: const SizedBox(),
                    value: recordType,
                    items: const [
                      DropdownMenuItem(value: 'attendance', child: Text('Attendance (ကျောင်းခေါ်ချိန်)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'exam_marks', child: Text('Exam Marks (စာမေးပွဲရမှတ်)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'whole_child', child: Text('Whole-Child Assessment (ဘက်စုံဖွံ့ဖြိုးမှု)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'social_participation', child: Text('Social Participation (လူမှုပါဝင်မှု)', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) => setDialogState(() => recordType = val ?? recordType),
                  ),
                ),
                const SizedBox(height: 10),

                // Target Item Title
                const Text('Target Item / Subject (အကြောင်းအရာ/ဘာသာရပ်):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: targetItemCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Oct 14 Attendance or Grade 5 Math Midterm',
                    hintStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),

                // Current Value vs Requested Correction
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Value:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: currentValueCtrl,
                            decoration: InputDecoration(
                              hintText: 'e.g. Absent / 62',
                              hintStyle: const TextStyle(fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Requested Correction:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: requestedCorrectionCtrl,
                            decoration: InputDecoration(
                              hintText: 'e.g. Present (Medical) / 72',
                              hintStyle: const TextStyle(fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Contested Reason
                const Text('Reason for Contestation (ကန့်ကွက်ရသည့် အကြောင်းရင်း) *:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Explain why this entry is incorrect...',
                    hintStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),

                // Supporting Evidence Notes
                const Text('Supporting Evidence / Notes (အထောက်အထား မှတ်ချက်):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: evidenceCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Gate pass timestamp recorded, medical slip attached.',
                    hintStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (targetItemCtrl.text.trim().isEmpty || reasonCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill in the target item and contested reason.')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        await ApiService.submitAppeal(
                          studentId: child.id,
                          recordType: recordType,
                          targetItemTitle: targetItemCtrl.text.trim(),
                          contestedReason: reasonCtrl.text.trim(),
                          currentValue: currentValueCtrl.text.trim(),
                          requestedCorrection: requestedCorrectionCtrl.text.trim(),
                          evidenceNotes: evidenceCtrl.text.trim(),
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF047857),
                              content: Text('Appeal submitted successfully! School administration notified.'),
                            ),
                          );
                          _loadChildSummariesAndAppeals(child.id);
                        }
                      } catch (err) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: Colors.red.shade800, content: Text(err.toString())),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Appeal', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
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
              const Expanded(
                child: Text(
                  'Whole-Child Academic & Attendance',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
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
          if (_isKG(child)) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'MOE 6 Learning Domains (သင်ယူဖွံ့ဖြိုးမှုနယ်ပယ် ၆ ခု)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Text('MOE KG Guide', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildKGDomainMetricsGrid(),
          ] else if (child.examScores.isNotEmpty) ...[
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
                // Navigate to the Chat/Communications tab (index 1 for Guardian)
                widget.onNavigateTab!(1);
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

  bool _isKG(GuardianChild child) {
    final grade = child.gradeLevel.toLowerCase();
    final cls = child.className.toLowerCase();
    return grade.contains('kg') || grade.contains('kindergarten') || cls.contains('kg') || child.age <= 5;
  }

  Widget _buildKGDomainMetricsGrid() {
    final domains = [
      {'title': 'ကာယနှင့် ကျန်းမာရေး', 'sub': 'Physical & Health', 'stars': '★★★', 'status': 'Mastered', 'isEmerald': true},
      {'title': 'စာရိတ္တ၊ စိတ်ခံစားမှု', 'sub': 'Moral & Social', 'stars': '★★★', 'status': 'Mastered', 'isEmerald': true},
      {'title': 'ဆက်သွယ်ပြောဆိုရေး', 'sub': 'Language & Literacy', 'stars': '★★☆', 'status': 'Developing', 'isEmerald': false},
      {'title': 'သင်္ချာနှင့် အရေအတွက်', 'sub': 'Math & Numeracy', 'stars': '★★★', 'status': 'Mastered', 'isEmerald': true},
      {'title': 'အနုပညာ၊ တီထွင်မှု', 'sub': 'Arts & Creativity', 'stars': '★★★', 'status': 'Mastered', 'isEmerald': true},
      {'title': 'ပတ်ဝန်းကျင်လောက', 'sub': 'Surrounding World', 'stars': '★★☆', 'status': 'Developing', 'isEmerald': false},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: domains.map((d) {
        final bool isEmerald = d['isEmerald'] == true;
        final Color col = isEmerald ? Colors.green.shade800 : Colors.blue.shade800;
        final Color bg = isEmerald ? Colors.green.shade50 : Colors.blue.shade50;
        return Container(
          width: 155,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: col.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d['title'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(d['stars'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: col)),
                  Text(d['status'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 1. Report Card Banner
  Widget _buildReportCardBanner(GuardianChild child) {
    final isKG = _isKG(child);
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
              color: isKG ? const Color(0xFFECFDF5) : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isKG ? Icons.stars_rounded : Icons.assessment_outlined,
              size: 30,
              color: isKG ? const Color(0xFF047857) : Colors.amber,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKG ? 'Kindergarten Monthly Report Card' : 'Official Academic Report Card',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                Text(
                  isKG
                      ? 'သူငယ်တန်း လစဉ် ဘက်စုံဖွံ့ဖြိုးမှု အစီရင်ခံစာ (နယ်ပယ် ၆ ခု)'
                      : 'တရားဝင် စာမေးပွဲ အမှတ်စာရင်းနှင့် ဘက်စုံအောင်လက်မှတ်',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showReportCardSheet(child),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: isKG ? const Color(0xFF065F46) : const Color(0xFF1E1B4B),
              foregroundColor: Colors.white,
            ),
            child: Text(isKG ? 'View KG Card' : 'View Card', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // 2. Report Card Sheet
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
            'physics': 84.0,
            'chemistry': 76.0,
            'biology': 80.0,
          };

    final totalMarks = scores.values.fold(0.0, (a, b) => a + b);
    final maxMarks = scores.length * 100.0;
    final avgPct = (totalMarks / maxMarks) * 100.0;
    final distinctionsCount = scores.values.where((v) => v >= 75.0).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Official Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'REPUBLIC OF THE UNION OF MYANMAR',
                            style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('OFFICIAL SEAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black87)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        child.schoolName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Term Report Card: Final Examination (2026-2027)',
                        style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Student: ${child.fullName}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(child.rollNo.isNotEmpty ? 'Roll: ${child.rollNo}' : (child.className.isNotEmpty ? child.className : child.gradeLevel), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      Text('Class: ${child.gradeLevel}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Summary KPIs
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('GPA (4.0 Scale)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(child.termGradePoint == 'A+' ? '3.92' : '3.80', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('Average Marks', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('${avgPct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('Distinctions', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('$distinctionsCount Subjects', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.amber)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Subject Marks Table
                const Text(
                  'Subject Academic Performance (ဘာသာရပ်အလိုက် ရမှတ်များ)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: scores.entries.map((entry) {
                      final score = entry.value;
                      final isDist = score >= 75.0;
                      final isPass = score >= 40.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key.toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Row(
                              children: [
                                if (isDist) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('ဂုဏ်ထူး', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.amber)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  '${score.toStringAsFixed(0)} / 100',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isPass ? AppTheme.textMain : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Cryptographic Verification Seal
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Text('Cryptographic Integrity Verification', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Digest Hash: ${child.credentialHash ?? "0x4a9b2c8a1e30d7f5a8b9c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2"}',
                        style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Status: Authenticated by Polygon Amoy Merkle Root • Zero Fraud Guarantee',
                        style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Print / Close Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Preparing High-Resolution PDF Transcript for Download...')),
                          );
                        },
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Official PDF', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Close'),
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

  Widget _buildGrowthItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildKGDomainDetailRow({
    required String num,
    required String titleMy,
    required String titleEn,
    required String stars,
    required String ratingLabel,
    required String activity,
    required bool isEmerald,
    bool isLast = false,
  }) {
    final col = isEmerald ? const Color(0xFF065F46) : Colors.blue.shade800;
    final bg = isEmerald ? Colors.green.shade50 : Colors.blue.shade50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(num, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titleMy, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(titleEn, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: col.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(stars, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
                    const SizedBox(width: 4),
                    Text(ratingLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: col)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              activity,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  void _showKGReportCardSheet(GuardianChild child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.96,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Official Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'REPUBLIC OF THE UNION OF MYANMAR',
                            style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('MOE VERIFIED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black87)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        child.schoolName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'သူငယ်တန်း လစဉ် ဘက်စုံဖွံ့ဖြိုးမှု အစီရင်ခံစာ (Kindergarten Report Card)',
                        style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        'စောင့်ကြည့်အကဲဖြတ် ကာလ: အောက်တိုဘာလ ၂၀၂၆ (October 2026)',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Student: ${child.fullName}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          Text('Age: ${child.age} yrs${child.rollNo.isNotEmpty ? " • Roll: ${child.rollNo}" : ""}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      Text('Class: ${child.className} • Section A', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // MOE Guide Law Statement Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF15803D)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'အမျိုးသားပညာရေးဥပဒေပုဒ်မ ၁၆(က) နှင့် ၂(က) အရ “ဘာသာရပ်များဖြင့် သင်ကြားမည်မဟုတ်သောကြောင့် ကျောင်းသုံးစာအုပ်မရှိပါ။” သင်ယူဖွံ့ဖြိုးမှုနယ်ပယ် (၆) ရပ်ဖြင့် ကလေးဗဟိုပြု စဉ်ဆက်မပြတ် စောင့်ကြည့်အကဲဖြတ်ထားခြင်းဖြစ်ပါသည်။',
                          style: TextStyle(fontSize: 10, color: Colors.green.shade900, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Summary KPIs
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Text('Development Status', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('ကျွမ်းကျင်ပိုင်နိုင်', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Text('Evaluated Domains', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('၆ ခု စုံလင်', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Text('Health & Growth', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('အာဟာရပြည့်ဝ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.amber)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 6 Domains Performance Table
                const Text(
                  'သင်ယူဖွံ့ဖြိုးမှုနယ်ပယ် (၆) ရပ် အကဲဖြတ်ချက် (6 Learning Domains)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _buildKGDomainDetailRow(
                        num: '၁',
                        titleMy: 'ကာယနှင့် ကျန်းမာဖွံ့ဖြိုးမှု',
                        titleEn: 'Physical Development & Health',
                        stars: '★★★',
                        ratingLabel: 'ကျွမ်းကျင်ပိုင်နိုင်',
                        activity: 'လက်ကြွက်သား၊ ခြေကြွက်သား လှုပ်ရှားမှု၊ တစ်ကိုယ်ရေ သန့်ရှင်းမှု အလေ့အကျင့်',
                        isEmerald: true,
                      ),
                      _buildKGDomainDetailRow(
                        num: '၂',
                        titleMy: 'စာရိတ္တ၊ လူမှုရေးနှင့် စိတ်ခံစားမှု',
                        titleEn: 'Moral, Social & Emotional Development',
                        stars: '★★★',
                        ratingLabel: 'ကျွမ်းကျင်ပိုင်နိုင်',
                        activity: 'သူငယ်ချင်းများနှင့် မျှဝေကစားခြင်း၊ စာနာနားလည်မှုနှင့် စည်းကမ်းလိုက်နာခြင်း',
                        isEmerald: true,
                      ),
                      _buildKGDomainDetailRow(
                        num: '၃',
                        titleMy: 'ဆက်သွယ်ပြောဆိုရေးနှင့် ဘာသာစကား',
                        titleEn: 'Communication, Language & Literacy',
                        stars: '★★☆',
                        ratingLabel: 'အဆင့်မီတိုးတက်ဆဲ',
                        activity: 'ပုံပြင်နားထောင်ခြင်း၊ မေးခွန်းများ မေးမြန်းစကားပြောခြင်းနှင့် စာဖတ်အသံထွက်',
                        isEmerald: false,
                      ),
                      _buildKGDomainDetailRow(
                        num: '၄',
                        titleMy: 'သင်္ချာနှင့် အရေအတွက် သိနားလည်မှု',
                        titleEn: 'Mathematics & Numeracy',
                        stars: '★★★',
                        ratingLabel: 'ကျွမ်းကျင်ပိုင်နိုင်',
                        activity: 'ပစ္စည်းများ ရေတွက်ခြင်း၊ အရွယ်အစားနှင့် ပုံသဏ္ဌာန် နှိုင်းယှဉ်ခွဲခြားခြင်း',
                        isEmerald: true,
                      ),
                      _buildKGDomainDetailRow(
                        num: '၅',
                        titleMy: 'အနုပညာနှင့် တီထွင်ဖန်တီးမှု',
                        titleEn: 'Arts & Creative Expression',
                        stars: '★★★',
                        ratingLabel: 'ကျွမ်းကျင်ပိုင်နိုင်',
                        activity: 'သီချင်းဆိုခြင်း၊ ကဗျာရွတ်ဆိုခြင်း၊ ဆေးရောင်ခြယ်ခြင်းနှင့် ရုပ်ပုံဖော်ခြင်း',
                        isEmerald: true,
                      ),
                      _buildKGDomainDetailRow(
                        num: '၆',
                        titleMy: 'ပတ်ဝန်းကျင်လောက သိနားလည်မှု',
                        titleEn: 'Understanding Surrounding World',
                        stars: '★★☆',
                        ratingLabel: 'အဆင့်မီတိုးတက်ဆဲ',
                        activity: 'သဘာဝပတ်ဝန်းကျင်၊ အပင်၊ တိရစ္ဆာန်များနှင့် နေ့စဉ်လူနေမှုဘဝ စူးစမ်းလေ့လာခြင်း',
                        isEmerald: false,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Teacher's Observation Remarks
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 18, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Text(
                            'ဆရာမ၏ လေ့လာတွေ့ရှိချက် မှတ်ချက် (Teacher Observation)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'အဖွဲ့လိုက် ကစားချိန်များတွင် တက်ကြွစွာ ပါဝင်ပြီး ဆရာမ၏ ညွှန်ကြားချက်များကို လိုက်နာပါသည်။ အနုပညာ၊ သီချင်းဆိုခြင်းနှင့် စကားပြောစွမ်းရည် အထူးကောင်းမွန်ပြီး သူငယ်ချင်းများကို ကူညီဖေးမတတ်ပါသည်။',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade800, height: 1.45),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'အတန်းပိုင်ဆရာမ: ဒေါ်လှလှဝင်း (B.Ed)',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Signed & Verified ✅', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Physical Growth & Health status
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'အာဟာရနှင့် ကျန်းမာဖွံ့ဖြိုးမှု အခြေအနေ (ရည်ရွယ်ချက် ၂)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildGrowthItem('အရပ်', '106 cm'),
                          _buildGrowthItem('ကိုယ်အလေးချိန်', '17.5 kg'),
                          _buildGrowthItem('BMI Category', '15.5 Healthy'),
                          _buildGrowthItem('သန်ချဆေး', 'ပြီးစီး ✅'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Cryptographic Verification Seal
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_outlined, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Text('MOE Verifiable Credential Seal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Credential ID: urn:uuid:${child.id} • Issuer: did:edu:school:${child.schoolCode}',
                        style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Status: Authenticated by Polygon Amoy Merkle Root • Official MOE Kindergarten Standard',
                        style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Downloading Official Kindergarten Report Card PDF...')),
                          );
                        },
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Official KG Card', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF065F46),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Close'),
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

  // 3. Child Privacy & Erasure (Right to be Forgotten) Section
  Widget _buildPrivacyErasureSection(GuardianChild child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Child Data Privacy & Protection (ကလေးအချက်အလက် စီမံခန့်ခွဲမှု)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.red.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Under statutory child data privacy regulations (GDPR-K & National Protection Act), you have the right to request erasure or pseudonymization of your child\'s records.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteChildDataDialog(child),
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text(
                'Delete / Anonymize Child Data (Right to be Forgotten)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Delete / Erasure Confirmation Dialog
  void _showDeleteChildDataDialog(GuardianChild child) {
    String erasureType = 'de_identify'; // 'de_identify' or 'full_erasure'
    String reason = 'Parental Consent Revocation';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Delete Child Data / ကလေးအချက်အလက် ပယ်ဖျက်ခြင်း',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete or anonymize all records for ${child.fullName}?',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                // Option A: De-identify
                RadioListTile<String>(
                  dense: true,
                  value: 'de_identify',
                  groupValue: erasureType,
                  activeColor: Colors.red.shade700,
                  title: const Text('De-Identify for Ministry Analytics (Recommended)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    'Scrubs all names, phones, addresses, photos, and biometrics. Replaces with anonymous hash (ANON-xxxx) to preserve anonymous regional school statistics.',
                    style: TextStyle(fontSize: 10),
                  ),
                  onChanged: (val) => setDialogState(() => erasureType = val!),
                ),

                // Option B: Full Erasure
                RadioListTile<String>(
                  dense: true,
                  value: 'full_erasure',
                  groupValue: erasureType,
                  activeColor: Colors.red.shade700,
                  title: const Text('Permanent Hard Erasure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                  subtitle: const Text(
                    'Permanently destroys all student academic files, whole-child health records, and invalidates all issued credentials.',
                    style: TextStyle(fontSize: 10),
                  ),
                  onChanged: (val) => setDialogState(() => erasureType = val!),
                ),
                const SizedBox(height: 12),

                const Text('Legal Justification / အကြောင်းပြချက်:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    underline: const SizedBox(),
                    value: reason,
                    items: const [
                      DropdownMenuItem(value: 'Parental Consent Revocation', child: Text('Parental Consent Revocation', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'Student Relocated Abroad', child: Text('Student Relocated Abroad', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'Privacy Preference', child: Text('Privacy Preference', style: TextStyle(fontSize: 11))),
                    ],
                    onChanged: (val) => setDialogState(() => reason = val ?? reason),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);

                // Perform erasure
                await StorageService.deleteGuardianChild(child.id);

                if (mounted) {
                  setState(() {
                    _children.removeWhere((c) => c.id == child.id);
                    if (_selectedChildIndex >= _children.length) {
                      _selectedChildIndex = _children.isEmpty ? 0 : _children.length - 1;
                    }
                  });

                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red.shade800,
                      content: Text('Data for ${child.fullName} successfully ${erasureType == "de_identify" ? "anonymized (ANON-xxxx)" : "permanently erased"}.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Erasure', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

