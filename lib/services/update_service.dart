import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateStatus {
  idle,
  checking,
  updateAvailable,
  upToDate,
  error,
}

/// Metadata describing a mobile application release.
class AppReleaseInfo {
  final String tagName;
  final String version;
  final String releaseName;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final String? apkDownloadUrl;
  final String? apkFileName;
  final int? apkSize;

  AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.releaseName,
    required this.body,
    required this.htmlUrl,
    this.publishedAt,
    this.apkDownloadUrl,
    this.apkFileName,
    this.apkSize,
  });

  factory AppReleaseInfo.fromGitHubJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? 'v1.0.0';
    final cleanVersion = tagName.replaceFirst(RegExp(r'^[vV]'), '');
    final assets = json['assets'] as List<dynamic>? ?? [];

    String? apkUrl;
    String? apkName;
    int? apkSize;

    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          apkName = name;
          apkSize = asset['size'] as int?;
          break;
        }
      }
    }

    if (apkUrl == null && tagName.isNotEmpty) {
      apkUrl =
          'https://github.com/drmyothiha/edu_mobile/releases/download/$tagName/edu_mobile-$tagName.apk';
      apkName = 'edu_mobile-$tagName.apk';
    }

    DateTime? publishedDate;
    if (json['published_at'] != null) {
      try {
        publishedDate = DateTime.parse(json['published_at'] as String);
      } catch (_) {}
    }

    return AppReleaseInfo(
      tagName: tagName,
      version: cleanVersion,
      releaseName: json['name'] as String? ?? 'AugmentEd Mobile $tagName',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ??
          'https://github.com/drmyothiha/edu_mobile/releases',
      publishedAt: publishedDate,
      apkDownloadUrl: apkUrl,
      apkFileName: apkName,
      apkSize: apkSize,
    );
  }

  factory AppReleaseInfo.fromManifestJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? 'v1.0.0';
    final version = json['version'] as String? ??
        tagName.replaceFirst(RegExp(r'^[vV]'), '');
    DateTime? publishedDate;
    if (json['published_at'] != null) {
      try {
        publishedDate = DateTime.parse(json['published_at'] as String);
      } catch (_) {}
    }

    return AppReleaseInfo(
      tagName: tagName,
      version: version,
      releaseName: json['release_name'] as String? ??
          'AugmentEd Mobile $tagName',
      body: json['release_notes'] as String? ??
          json['notes'] as String? ??
          'Bug fixes and performance enhancements.',
      htmlUrl:
          'https://github.com/drmyothiha/edu_mobile/releases/tag/$tagName',
      publishedAt: publishedDate,
      apkDownloadUrl: json['download_url'] as String?,
      apkFileName: json['apk_name'] as String?,
      apkSize: json['apk_size'] as int?,
    );
  }
}

/// The result returned after checking for updates.
class UpdateCheckResult {
  final UpdateStatus status;
  final String currentVersion;
  final AppReleaseInfo? latestRelease;
  final String? errorMessage;

  UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    this.latestRelease,
    this.errorMessage,
  });
}

/// Central service for checking and initiating mobile application updates.
class UpdateService {
  static const String githubRepo = 'drmyothiha/edu_mobile';
  static const String fallbackCurrentVersion = '1.0.0';

  static UpdateCheckResult? _cachedResult;
  static DateTime? _lastCheckTime;

  /// Clean version string for standard semver comparison: v1.0.0 -> [1, 0, 0]
  static List<int> parseVersion(String v) {
    final clean = v.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final parts = clean.split(RegExp(r'[-+.]'));
    return parts.take(3).map((part) => int.tryParse(part) ?? 0).toList();
  }

  /// Compares remote tag against current version.
  /// Returns true if remote version is strictly newer than current version.
  static bool isNewerVersion(String remoteTag, String currentTag) {
    final remote = parseVersion(remoteTag);
    final current = parseVersion(currentTag);

    for (var i = 0; i < 3; i++) {
      final r = i < remote.length ? remote[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Formats byte size into human-readable string (e.g. 28.5 MB)
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Universal APK';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  /// Formats date for display
  static String formatPublishedDate(DateTime? dt) {
    if (dt == null) return 'Recent';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// Reads the local installed application version from package_info_plus.
  static Future<String> getCurrentAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        return info.version;
      }
    } catch (e) {
      debugPrint('[UpdateService] Warning: Could not read PackageInfo: $e');
    }
    return fallbackCurrentVersion;
  }

  /// Checks for available updates from GitHub Releases API or manifest fallback.
  static Future<UpdateCheckResult> checkForUpdates({
    bool forceRefresh = false,
  }) async {
    // Return cached result if within 60 seconds unless forced
    if (!forceRefresh &&
        _cachedResult != null &&
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) <
            const Duration(seconds: 60)) {
      return _cachedResult!;
    }

    final currentVersion = await getCurrentAppVersion();

    try {
      // 1. Query GitHub Releases API for latest published release
      final uri = Uri.parse(
          'https://api.github.com/repos/$githubRepo/releases/latest');
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final release = AppReleaseInfo.fromGitHubJson(data);
        final hasUpdate = isNewerVersion(release.tagName, currentVersion);

        final result = UpdateCheckResult(
          status: hasUpdate
              ? UpdateStatus.updateAvailable
              : UpdateStatus.upToDate,
          currentVersion: currentVersion,
          latestRelease: release,
        );
        _cachedResult = result;
        _lastCheckTime = DateTime.now();
        return result;
      }

      if (response.statusCode == 404) {
        // No releases published on repo yet
        final result = UpdateCheckResult(
          status: UpdateStatus.upToDate,
          currentVersion: currentVersion,
        );
        _cachedResult = result;
        _lastCheckTime = DateTime.now();
        return result;
      }

      // If GitHub API is rate-limited (403) or other HTTP code, try manifest fallback
      debugPrint(
          '[UpdateService] GitHub API returned ${response.statusCode}, trying raw manifest fallback...');
    } catch (e) {
      debugPrint('[UpdateService] GitHub API query error: $e, trying raw fallback...');
    }

    // 2. Fallback to raw version.json manifest in main branch
    try {
      final fallbackUri = Uri.parse(
          'https://raw.githubusercontent.com/$githubRepo/main/version.json');
      final fallbackRes = await http
          .get(fallbackUri)
          .timeout(const Duration(seconds: 5));

      if (fallbackRes.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(fallbackRes.body);
        final release = AppReleaseInfo.fromManifestJson(data);
        final hasUpdate = isNewerVersion(release.tagName, currentVersion);

        final result = UpdateCheckResult(
          status: hasUpdate
              ? UpdateStatus.updateAvailable
              : UpdateStatus.upToDate,
          currentVersion: currentVersion,
          latestRelease: release,
        );
        _cachedResult = result;
        _lastCheckTime = DateTime.now();
        return result;
      }
    } catch (fallbackError) {
      debugPrint('[UpdateService] Fallback manifest error: $fallbackError');
    }

    final errorResult = UpdateCheckResult(
      status: UpdateStatus.error,
      currentVersion: currentVersion,
      errorMessage:
          'Unable to check for updates. Please check your internet connection and try again.',
    );
    _cachedResult = errorResult;
    _lastCheckTime = DateTime.now();
    return errorResult;
  }

  /// Opens the APK download URL via the system browser / download manager.
  static Future<bool> launchApkDownload(String? url) async {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.parse(url);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UpdateService] Failed to launch APK download URL: $e');
      return false;
    }
  }

  /// Opens the GitHub Release page in browser.
  static Future<bool> launchWebUrl(String? url) async {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.parse(url);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UpdateService] Failed to launch web URL: $e');
      return false;
    }
  }

  /// Reset cache for testing or manual check
  static void clearCache() {
    _cachedResult = null;
    _lastCheckTime = null;
  }
}
