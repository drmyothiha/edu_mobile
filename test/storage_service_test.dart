import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('StorageService.getServerUrl normalizes 10.0.2.2 on non-android platforms (macOS/iOS/web)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({
      'server_api_base_url': 'http://10.0.2.2:8080',
    });

    final url = await StorageService.getServerUrl();
    expect(url, equals('http://localhost:8080'));
  });

  test('StorageService.getServerUrl preserves 10.0.2.2 on Android emulator', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({
      'server_api_base_url': 'http://10.0.2.2:8080',
    });

    final url = await StorageService.getServerUrl();
    expect(url, equals('http://10.0.2.2:8080'));
  });

  test('StorageService.getServerUrl preserves custom LAN IP', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({
      'server_api_base_url': 'http://192.168.1.50:8080',
    });

    final url = await StorageService.getServerUrl();
    expect(url, equals('http://192.168.1.50:8080'));
  });
}
