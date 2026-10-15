import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_mobile/models/user_role.dart';
import 'package:edu_mobile/services/nfc_auth_service.dart';
import 'package:edu_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NfcAuthService Offline DID Verification Tests', () {
    test('Simulate demo card login for KG student creates verified offline session', () async {
      final result = await NfcAuthService.simulateDemoCardLogin(
        studentName: 'Maung Aung Kaung Myat',
        rollNumber: 'ROLL-KG-001',
        gradeLevel: 'Kindergarten (KG)',
      );

      expect(result.success, isTrue);
      expect(result.isOffline, isTrue);
      expect(result.user, isNotNull);
      expect(result.user!.role, AppUserRole.student);
      expect(result.user!.fullName, 'Maung Aung Kaung Myat');
      expect(result.user!.gradeLevel, 'Kindergarten (KG)');

      // Check session was persisted locally
      final currentUser = await StorageService.getCurrentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!.fullName, 'Maung Aung Kaung Myat');

      final cachedCred = await StorageService.getCachedCredential();
      expect(cachedCred, isNotNull);
      expect(cachedCred!['id'], contains('did:edu:mm:013'));
    });

    test('Authenticate with compact DID JSON payload', () async {
      final compactPayload = jsonEncode({
        'did': 'did:edu:mm:013:MMR013035-BEHS01-2026-STU0099',
        'student_id': 'stu-uuid-9999',
        'name': 'Ma Hnin Nu (Grade 10)',
        'roll': 'ROLL-G10-001',
        'school_name': 'BEHS Intaing (အထက အင်းတိုင်)',
        'school_code': 'MMR013035-BEHS01',
        'grade': 'Grade 10',
      });

      final result = await NfcAuthService.authenticateWithCard(
        rawPayload: compactPayload,
      );

      expect(result.success, isTrue);
      expect(result.user?.fullName, 'Ma Hnin Nu (Grade 10)');
      expect(result.user?.role, AppUserRole.student);

      final currentUser = await StorageService.getCurrentUser();
      expect(currentUser?.fullName, 'Ma Hnin Nu (Grade 10)');
    });

    test('Authenticate with raw DID string URI', () async {
      const rawDid = 'did:edu:mm:013:MMR013035-BEHS01-2026-ROLL005';

      final result = await NfcAuthService.authenticateWithCard(
        rawPayload: rawDid,
      );

      expect(result.success, isTrue);
      expect(result.user?.role, AppUserRole.student);
      expect(result.user?.email, contains('roll005@'));
    });

    test('Authenticate with hardware NFC UID tag fallback', () async {
      const hardwareUid = '04A1B2C3D4E5F6';

      final result = await NfcAuthService.authenticateWithCard(
        rawPayload: '',
        hardwareId: hardwareUid,
      );

      expect(result.success, isTrue);
      expect(result.user?.role, AppUserRole.student);
      expect(result.user?.id, 'stu-nfc-$hardwareUid');
    });

    test('Unrecognized or empty card payload returns error result', () async {
      final result = await NfcAuthService.authenticateWithCard(
        rawPayload: 'random_unrecognized_text',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Unrecognized card data'));
    });
  });
}
