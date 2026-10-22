import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EduMobileApp initializes and renders login screen when unauthenticated', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const EduMobileApp());
    await tester.pumpAndSettle();

    // Verify standard login screen elements appear
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Username or Phone Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
