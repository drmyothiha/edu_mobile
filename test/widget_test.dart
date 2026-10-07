import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/main.dart';
import 'package:edu_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EduMobileApp initializes and renders navigation tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTesting();
    await StorageService.clearSession();

    await tester.pumpWidget(const EduMobileApp());
    await tester.pumpAndSettle();

    // App should start in unauthenticated multi-view with ID Card and Notices
    expect(find.text('ID Card'), findsOneWidget);
    expect(find.text('Notices'), findsOneWidget);
  });
}
