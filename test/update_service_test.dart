import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_mobile/services/update_service.dart';
import 'package:edu_mobile/widgets/update_dialog.dart';

void main() {
  group('UpdateService Version Parsing & Semver Comparison', () {
    test('parseVersion handles v-prefixes, dots, and build identifiers', () {
      expect(UpdateService.parseVersion('v1.0.0'), [1, 0, 0]);
      expect(UpdateService.parseVersion('V2.3.4'), [2, 3, 4]);
      expect(UpdateService.parseVersion('1.2.3+45'), [1, 2, 3]);
      expect(UpdateService.parseVersion('v0.9.1-beta'), [0, 9, 1]);
      expect(UpdateService.parseVersion(''), [0]);
    });

    test('isNewerVersion accurately compares semantic version strings', () {
      // Remote newer cases
      expect(UpdateService.isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('v1.1.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.0.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewerVersion('V1.0.1', 'v1.0.0'), isTrue);

      // Same or older version cases
      expect(UpdateService.isNewerVersion('v1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('v0.9.9', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('v1.0.0', '1.0.1'), isFalse);
    });

    test('formatFileSize formats byte amounts into KB and MB cleanly', () {
      expect(UpdateService.formatFileSize(null), 'Universal APK');
      expect(UpdateService.formatFileSize(0), 'Universal APK');
      expect(UpdateService.formatFileSize(512000), '500 KB');
      expect(UpdateService.formatFileSize(31457280), '30.0 MB');
    });

    test('formatPublishedDate converts DateTime into clean month-day-year string', () {
      expect(UpdateService.formatPublishedDate(null), 'Recent');
      final dt = DateTime(2026, 10, 19);
      expect(UpdateService.formatPublishedDate(dt), 'Oct 19, 2026');
    });
  });

  group('AppReleaseInfo JSON Deserialization', () {
    test('parses GitHub release response with APK asset', () {
      final json = {
        'tag_name': 'v1.1.0',
        'name': 'AugmentEd Mobile v1.1.0',
        'body': 'Added automated mobile updates and CI/CD pipelines.',
        'html_url': 'https://github.com/drmyothiha/edu_mobile/releases/tag/v1.1.0',
        'published_at': '2026-10-19T12:00:00Z',
        'assets': [
          {
            'name': 'edu_mobile-v1.1.0.apk',
            'browser_download_url': 'https://github.com/drmyothiha/edu_mobile/releases/download/v1.1.0/edu_mobile-v1.1.0.apk',
            'size': 32500000,
          },
          {
            'name': 'checksums.txt',
            'browser_download_url': 'https://github.com/drmyothiha/edu_mobile/releases/download/v1.1.0/checksums.txt',
            'size': 120,
          }
        ],
      };

      final release = AppReleaseInfo.fromGitHubJson(json);
      expect(release.tagName, 'v1.1.0');
      expect(release.version, '1.1.0');
      expect(release.releaseName, 'AugmentEd Mobile v1.1.0');
      expect(release.apkFileName, 'edu_mobile-v1.1.0.apk');
      expect(release.apkDownloadUrl, contains('.apk'));
      expect(release.apkSize, 32500000);
      expect(release.publishedAt, isNotNull);
    });

    test('parses version.json updater manifest fallback', () {
      final manifestJson = {
        'version': '1.0.5',
        'tag_name': 'v1.0.5',
        'build_number': 5,
        'release_name': 'AugmentEd Mobile v1.0.5',
        'apk_name': 'edu_mobile-v1.0.5.apk',
        'apk_size': 31000000,
        'download_url': 'https://github.com/drmyothiha/edu_mobile/releases/download/v1.0.5/edu_mobile-v1.0.5.apk',
        'release_notes': 'Hotfix release for gate scanner.',
        'published_at': '2026-10-19T14:30:00Z',
      };

      final release = AppReleaseInfo.fromManifestJson(manifestJson);
      expect(release.tagName, 'v1.0.5');
      expect(release.version, '1.0.5');
      expect(release.releaseName, 'AugmentEd Mobile v1.0.5');
      expect(release.apkFileName, 'edu_mobile-v1.0.5.apk');
      expect(release.apkDownloadUrl, contains('v1.0.5'));
      expect(release.body, contains('Hotfix release'));
    });
  });

  group('UpdateDialog Widget Rendering Tests', () {
    testWidgets('renders UpdateDialog header and manual check button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateDialog(autoCheckOnOpen: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Software Update'), findsOneWidget);
      expect(find.textContaining('ဆော့ဖ်ဝဲလ် အဆင့်မြှင့်တင်ခြင်း'), findsOneWidget);
      expect(find.text('Check for Updates (စစ်ဆေးမည်)'), findsOneWidget);
      expect(find.text('View Releases on GitHub Repository'), findsOneWidget);
    });
  });
}
