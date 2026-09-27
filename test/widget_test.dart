import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EduMobileApp initializes and renders navigation tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const EduMobileApp());
    await tester.pumpAndSettle();

    // Verify presence of Multi-Module Navigation
    expect(find.text('ID Card'), findsOneWidget);
    expect(find.text('Kiosk'), findsOneWidget);
    expect(find.text('Whole-Child'), findsOneWidget);
    expect(find.text('Parent Chat'), findsOneWidget);
  });
}
