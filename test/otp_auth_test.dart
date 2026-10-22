import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/services/storage_service.dart';
import 'package:edu_mobile/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('Standard Clean LoginScreen Widget Tests', () {
    testWidgets('LoginScreen displays standard username, password, login button, and links', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Standard fields and buttons
      expect(find.text('AugmentEd'), findsOneWidget);
      expect(find.text('Username or Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('Tapping Forgot password opens info dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('OK (နားလည်ပါပြီ)'), findsOneWidget);
    });

    testWidgets('Tapping Register opens registration sheet', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Parent Account Registration'), findsOneWidget);
      expect(find.text('Register Account (အကောင့်ဖွင့်မည်)'), findsOneWidget);
    });
  });
}
