import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Modal dialog or bottom sheet for checking, viewing, and downloading updates.
class UpdateDialog extends StatefulWidget {
  final bool autoCheckOnOpen;

  const UpdateDialog({super.key, this.autoCheckOnOpen = true});

  /// Convenient helper to display the update dialog as a modal bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const UpdateDialog(),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isLoading = false;
  UpdateCheckResult? _result;
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadInitialVersion();
    if (widget.autoCheckOnOpen) {
      _checkForUpdates(force: false);
    }
  }

  Future<void> _loadInitialVersion() async {
    final v = await UpdateService.getCurrentAppVersion();
    if (mounted) {
      setState(() => _currentVersion = v);
    }
  }

  Future<void> _checkForUpdates({bool force = true}) async {
    setState(() => _isLoading = true);
    final res = await UpdateService.checkForUpdates(forceRefresh: force);
    if (mounted) {
      setState(() {
        _result = res;
        _currentVersion = res.currentVersion;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadApk() async {
    final release = _result?.latestRelease;
    final apkUrl = release?.apkDownloadUrl;
    if (apkUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No APK asset found for this release.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final launched = await UpdateService.launchApkDownload(apkUrl);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open browser for download. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewOnWeb() async {
    final release = _result?.latestRelease;
    final url = release?.htmlUrl ?? 'https://github.com/drmyothiha/edu_mobile/releases';
    await UpdateService.launchWebUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = _result?.status == UpdateStatus.updateAvailable;
    final isUpToDate = _result?.status == UpdateStatus.upToDate;
    final isError = _result?.status == UpdateStatus.error;
    final release = _result?.latestRelease;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          hasUpdate ? const Color(0xFF10B981) : AppTheme.primary,
                          hasUpdate ? const Color(0xFF059669) : AppTheme.primaryDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (hasUpdate ? const Color(0xFF10B981) : AppTheme.primary)
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      hasUpdate
                          ? Icons.system_update
                          : (isUpToDate ? Icons.check_circle_outline : Icons.cloud_download_outlined),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Software Update',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ဆော့ဖ်ဝဲလ် အဆင့်မြှင့်တင်ခြင်း • Installed v$_currentVersion',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Status Card
              if (_isLoading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Column(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Checking for latest release on GitHub...',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ဗားရှင်းအသစ် ရှာဖွေနေပါသည်...',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                )
              else if (hasUpdate && release != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'UPDATE AVAILABLE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            release.tagName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        release.releaseName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF064E3B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 13, color: Color(0xFF047857)),
                          const SizedBox(width: 4),
                          Text(
                            UpdateService.formatPublishedDate(release.publishedAt),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                          ),
                          const SizedBox(width: 14),
                          const Icon(Icons.sd_storage, size: 13, color: Color(0xFF047857)),
                          const SizedBox(width: 4),
                          Text(
                            UpdateService.formatFileSize(release.apkSize),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                          ),
                        ],
                      ),
                      if (release.body.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFFA7F3D0)),
                        const SizedBox(height: 8),
                        const Text(
                          'Release Notes (အသစ်ပါဝင်မှုများ):',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: SingleChildScrollView(
                            child: Text(
                              release.body,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: Color(0xFF064E3B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else if (isUpToDate)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 36),
                      const SizedBox(height: 10),
                      const Text(
                        'Your App is Up to Date!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'လက်ရှိဗားရှင်း v$_currentVersion သည် နောက်ဆုံးထွက်ဗားရှင်းဖြစ်ပါသည်။',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else if (isError)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Update Check Error',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _result?.errorMessage ?? 'Failed to check GitHub releases.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Primary Action Buttons
              if (hasUpdate) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text(
                      'Download & Install Update (ဒေါင်းလုဒ်ရယူမည်)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _downloadApk,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_browser, size: 16),
                        label: const Text('View on GitHub'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _viewOnWeb,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Check Again'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _checkForUpdates(force: true),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text(
                          'Check for Updates (စစ်ဆေးမည်)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isLoading ? null : () => _checkForUpdates(force: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text(
                      'View Releases on GitHub Repository',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: _viewOnWeb,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
