import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../theme/app_theme.dart';

/// Screen for configuring and testing the backend server IP or URL.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = true;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  static const String defaultUrl = 'https://104.154.135.208';

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await StorageService.getServerUrl();
    if (mounted) {
      setState(() {
        _urlController.text = url;
        _isLoading = false;
      });
    }
  }

  void _applyPreset(String preset) {
    setState(() {
      _urlController.text = preset;
      _testResult = null;
    });
  }

  Future<void> _testConnection() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _testResult = 'Please enter an IP address or server URL';
        _testSuccess = false;
      });
      return;
    }

    final normalized = StorageService.normalizeServerUrl(raw);
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$normalized/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 400) {
        setState(() {
          _testSuccess = true;
          _testResult =
              'Connection successful! (HTTP ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms)';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult =
              'Server returned HTTP ${response.statusCode} (${response.reasonPhrase})';
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _testSuccess = false;
        _testResult =
            'Connection failed: ${e.toString().replaceAll("Exception: ", "")}';
      });
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _saveAndApply() async {
    final raw = _urlController.text.trim();
    final normalized = StorageService.normalizeServerUrl(raw);

    await StorageService.setServerUrl(normalized);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server URL set to: $normalized'),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, normalized);
    }
  }

  Future<void> _resetToDefault() async {
    await StorageService.resetServerUrl();
    setState(() {
      _urlController.text = defaultUrl;
      _testResult = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset to default production IP: 104.154.135.208'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Configuration (ဆာဗာချိန်ညှိမှု)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update_alt),
            tooltip: 'Check for Updates (အပ်ဒိတ်စစ်ဆေးမည်)',
            onPressed: () => UpdateDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to Default (104.154.135.208)',
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    elevation: 0,
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.dns,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Backend Server IP / Host',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Change the API host IP for cloud, campus intranet, or local development.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Server IP / URL Input Field
                  const Text(
                    'Server IP Address or Base URL',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: 'e.g. 104.154.135.208 or https://104.154.135.208',
                      prefixIcon: const Icon(Icons.link, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _urlController.clear(),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      helperText:
                          'You can enter plain IP "104.154.135.208" or full URL "https://104.154.135.208"',
                      helperStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Presets
                  const Text(
                    'Quick Presets (အမြန်ရွေးချယ်ရန်):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(
                          Icons.cloud_done,
                          size: 16,
                          color: Colors.green,
                        ),
                        label: const Text(
                          'Production Server (104.154.135.208)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _applyPreset(defaultUrl),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.android, size: 16),
                        label: const Text(
                          'Emulator (10.0.2.2:8080)',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _applyPreset('http://10.0.2.2:8080'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.laptop, size: 16),
                        label: const Text(
                          'Localhost (8080)',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _applyPreset('http://localhost:8080'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Test Connection Button & Result
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check, size: 18),
                      label: Text(
                        _isTesting
                            ? 'Testing Connection...'
                            : 'Test Server Connectivity (စမ်းသပ်မည်)',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isTesting ? null : _testConnection,
                    ),
                  ),

                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testSuccess
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _testSuccess
                              ? Colors.green.shade300
                              : Colors.red.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testSuccess
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: _testSuccess
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                color: _testSuccess
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Save & Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save & Apply Settings (သိမ်းဆည်းမည်)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saveAndApply,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Reset Default Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Reset to Default IP (104.154.135.208)'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                      ),
                      onPressed: _resetToDefault,
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Software Update Card
                  _buildSoftwareUpdateSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSoftwareUpdateSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.system_update_alt,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Software Updates (ဆော့ဖ်ဝဲလ် အဆင့်မြှင့်တင်ခြင်း)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Check GitHub Releases for new APK updates',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FutureBuilder<String>(
                future: UpdateService.getCurrentAppVersion(),
                builder: (context, snapshot) {
                  final version = snapshot.data ?? '1.0.0';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Installed: v$version',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Check for Updates'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => UpdateDialog.show(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
