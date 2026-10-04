import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/services/storage_service.dart';
import 'package:edu_mobile/screens/server_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('Server URL Normalization & Storage Tests', () {
    test(
      'defaultServerUrl defaults to production IP 136.85.95.216 with HTTPS',
      () {
        expect(
          StorageService.defaultServerUrl,
          equals('https://136.85.95.216'),
        );
      },
    );

    test('normalizeServerUrl handles various formats', () {
      expect(
        StorageService.normalizeServerUrl('136.85.95.216'),
        equals('https://136.85.95.216'),
      );
      expect(
        StorageService.normalizeServerUrl('136.85.95.216/'),
        equals('https://136.85.95.216'),
      );
      expect(
        StorageService.normalizeServerUrl('https://136.85.95.216/api/v1'),
        equals('https://136.85.95.216'),
      );
      expect(
        StorageService.normalizeServerUrl('10.0.2.2:8080'),
        equals('http://10.0.2.2:8080'),
      );
      expect(
        StorageService.normalizeServerUrl('localhost:8080'),
        equals('http://localhost:8080'),
      );
      expect(
        StorageService.normalizeServerUrl('http://192.168.1.100:8080/'),
        equals('http://192.168.1.100:8080'),
      );
    });

    test('setServerUrl and getServerUrl persist normalized URL', () async {
      await StorageService.setServerUrl('136.85.95.216');
      final saved = await StorageService.getServerUrl();
      expect(saved, equals('https://136.85.95.216'));

      await StorageService.setServerUrl('192.168.1.20:8080');
      final updated = await StorageService.getServerUrl();
      expect(updated, equals('http://192.168.1.20:8080'));

      await StorageService.resetServerUrl();
      final reset = await StorageService.getServerUrl();
      expect(reset, equals('https://136.85.95.216'));
    });
  });

  group('ServerSettingsScreen Widget Tests', () {
    testWidgets('renders ServerSettingsScreen and loads initial URL', (
      tester,
    ) async {
      await StorageService.setServerUrl('https://136.85.95.216');

      await tester.pumpWidget(const MaterialApp(home: ServerSettingsScreen()));

      await tester.pumpAndSettle();

      expect(
        find.text('Server Configuration (ဆာဗာချိန်ညှိမှု)'),
        findsOneWidget,
      );
      expect(find.text('Backend Server IP / Host'), findsOneWidget);
      expect(find.text('Save & Apply Settings (သိမ်းဆည်းမည်)'), findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('https://136.85.95.216'));
    });

    testWidgets('tapping preset updates text field', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ServerSettingsScreen()));
      await tester.pumpAndSettle();

      final emulatorChip = find.text('Emulator (10.0.2.2:8080)');
      expect(emulatorChip, findsOneWidget);

      await tester.tap(emulatorChip);
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('http://10.0.2.2:8080'));
    });
  });
}
