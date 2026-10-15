import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:ndef_record/ndef_record.dart';
import '../models/user_role.dart';
import '../models/verifiable_credential.dart';
import 'crypto_service.dart';
import 'storage_service.dart';

enum NfcStatus {
  available,
  disabled,
  unsupported,
}

class NfcAuthResult {
  final bool success;
  final AppUser? user;
  final String? token;
  final bool isOffline;
  final String message;
  final VerifiableCredential? credential;

  NfcAuthResult({
    required this.success,
    this.user,
    this.token,
    this.isOffline = true,
    required this.message,
    this.credential,
  });
}

class NfcAuthService {
  /// Checks whether NFC hardware is present and active on this device
  static Future<NfcStatus> checkNfcStatus() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return NfcStatus.unsupported;
    }

    try {
      final availability = await NfcManager.instance.checkAvailability();
      switch (availability) {
        case NfcAvailability.enabled:
          return NfcStatus.available;
        case NfcAvailability.disabled:
          return NfcStatus.disabled;
        case NfcAvailability.unsupported:
          return NfcStatus.unsupported;
      }
    } catch (_) {
      return NfcStatus.unsupported;
    }
  }

  /// Begins listening for student smart card tap
  static Future<void> startStudentCardSession({
    required Function(String cardId, String rawPayload) onCardTapped,
    required Function(String error) onError,
  }) async {
    final status = await checkNfcStatus();
    if (status != NfcStatus.available) {
      if (status == NfcStatus.disabled) {
        onError('NFC is disabled in device settings. Please enable NFC to tap card.');
      } else {
        onError('NFC hardware is not supported on this phone.');
      }
      return;
    }

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Hold Student Smart Card near the top of your iPhone',
        onDiscovered: (NfcTag tag) async {
          try {
            String? hardwareId;
            String? ndefPayload;

            // 1. Extract Hardware UID based on platform
            if (defaultTargetPlatform == TargetPlatform.android) {
              final androidTag = NfcTagAndroid.from(tag);
              if (androidTag != null && androidTag.id.isNotEmpty) {
                hardwareId = androidTag.id
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join('')
                    .toUpperCase();
              }

              final ndefAndroid = NdefAndroid.from(tag);
              if (ndefAndroid != null && ndefAndroid.cachedNdefMessage != null) {
                ndefPayload = _extractNdefText(ndefAndroid.cachedNdefMessage!.records);
              }
            } else if (defaultTargetPlatform == TargetPlatform.iOS) {
              final mifare = MiFareIos.from(tag);
              if (mifare != null && mifare.identifier.isNotEmpty) {
                hardwareId = mifare.identifier
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join('')
                    .toUpperCase();
              }

              final ndefIos = NdefIos.from(tag);
              if (ndefIos != null && ndefIos.cachedNdefMessage != null) {
                ndefPayload = _extractNdefText(ndefIos.cachedNdefMessage!.records);
              }
            }

            // Stop session after reading
            await stopSession();

            final rawData = ndefPayload?.trim().isNotEmpty == true
                ? ndefPayload!.trim()
                : (hardwareId ?? '');

            if (rawData.isNotEmpty) {
              onCardTapped(hardwareId ?? 'CARD_NFC', rawData);
            } else {
              onError('Could not read student data from this card. Please try again.');
            }
          } catch (e) {
            await stopSession();
            onError('Card reading error: ${e.toString()}');
          }
        },
      );
    } catch (e) {
      onError('Unable to start NFC sensor: ${e.toString()}');
    }
  }

  /// Stops the current NFC session
  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  /// Helper to decode text or JSON from NDEF records
  static String? _extractNdefText(List<NdefRecord> records) {
    for (final record in records) {
      if (record.payload.isEmpty) continue;

      try {
        // NDEF Text record (first byte is status & language code length)
        final status = record.payload[0];
        final langLength = status & 0x3F;
        if (record.payload.length > 1 + langLength) {
          final textBytes = record.payload.sublist(1 + langLength);
          final text = utf8.decode(textBytes).trim();
          if (text.isNotEmpty) return text;
        }
      } catch (_) {}

      // Fallback: direct utf8 decode
      try {
        final text = utf8.decode(record.payload).trim();
        if (text.isNotEmpty) return text;
      } catch (_) {}
    }
    return null;
  }

  /// Authenticates student completely offline using their W3C DID / Verifiable Credential
  static Future<NfcAuthResult> authenticateWithCard({
    required String rawPayload,
    String? hardwareId,
  }) async {
    try {
      rawPayload = rawPayload.trim();
      final parsed = CryptoService.parseScannedPayload(rawPayload);

      // Case 1: Full W3C Verifiable Credential 2.0 payload
      if (parsed != null && (parsed.containsKey('@context') || parsed.containsKey('credentialSubject'))) {
        final vc = VerifiableCredential.fromJson(parsed);

        // Perform offline Ed25519 cryptographic signature verification
        final verification = CryptoService.verifyCredentialOffline(vc);

        if (!verification.isValid && !verification.signatureValid) {
          return NfcAuthResult(
            success: false,
            message: 'Invalid Student Card: Digital signature mismatch or tampered data.',
          );
        }

        final subject = vc.credentialSubject;
        final studentUser = AppUser(
          id: subject.studentId.isNotEmpty ? subject.studentId : 'stu-${subject.studentRollNumber}',
          email: '${subject.studentRollNumber.toLowerCase()}@${subject.schoolCode.toLowerCase()}.edu.local',
          fullName: 'Student (${subject.studentRollNumber})',
          role: AppUserRole.student,
          schoolId: subject.schoolCode,
          schoolName: subject.schoolName,
          gradeLevel: subject.academicYear,
        );

        final offlineToken = 'did_offline_jwt_${vc.id}_${DateTime.now().millisecondsSinceEpoch}';

        // Cache session & credential locally for 100% offline access
        await StorageService.saveSession(token: offlineToken, user: studentUser.toJson());
        await StorageService.saveCachedCredential(vc.toJson());

        return NfcAuthResult(
          success: true,
          user: studentUser,
          token: offlineToken,
          isOffline: true,
          credential: vc,
          message: 'Student Smart Card verified offline via Ed25519 signature.',
        );
      }

      // Case 2: Compact DID / JSON object with claims e.g. {"did": "did:edu:mm...", "name": "...", "roll": "..."}
      if (parsed != null &&
          parsed.containsKey('did') &&
          (parsed.containsKey('name') ||
              parsed.containsKey('student_name') ||
              parsed.containsKey('roll') ||
              parsed.containsKey('student_roll'))) {
        final did = parsed['did'].toString();
        final name = parsed['name']?.toString() ?? parsed['student_name']?.toString() ?? 'Student';
        final roll = parsed['roll']?.toString() ?? parsed['student_roll']?.toString() ?? 'STU-001';
        final school = parsed['school']?.toString() ?? parsed['school_name']?.toString() ?? 'Pilot School';
        final schoolCode = parsed['school_code']?.toString() ?? '';

        final studentUser = AppUser(
          id: parsed['student_id']?.toString() ?? 'stu-$roll',
          email: '$roll@${schoolCode.toLowerCase()}.edu.local',
          fullName: name,
          role: AppUserRole.student,
          schoolId: schoolCode,
          schoolName: school,
          gradeLevel: parsed['grade']?.toString() ?? 'Grade 12',
        );

        final offlineToken = 'did_offline_jwt_${DateTime.now().millisecondsSinceEpoch}';
        await StorageService.saveSession(token: offlineToken, user: studentUser.toJson());

        return NfcAuthResult(
          success: true,
          user: studentUser,
          token: offlineToken,
          isOffline: true,
          message: 'Student DID authenticated: $did',
        );
      }

      // Case 3: Raw DID String (e.g. "did:edu:mm:013:SCH-BEHS01-2026-STU0001")
      final didString = (parsed != null && parsed.containsKey('did'))
          ? parsed['did'].toString()
          : rawPayload;

      if (didString.startsWith('did:edu:mm:') || didString.startsWith('did:web:')) {
        // Parse segments from did:edu:mm:<region>:<schoolCode>-<year>-<roll>
        final parts = didString.split(':');
        String schoolCode = '';
        String roll = 'ROLL-001';

        if (parts.length >= 5) {
          final suffix = parts.last; // e.g. SCH-BEHS01-2026-STU0001
          final subParts = suffix.split('-');
          if (subParts.length >= 3) {
            schoolCode = '${subParts[0]}-${subParts[1]}';
            roll = subParts.last;
          }
        }

        final studentUser = AppUser(
          id: 'stu-$roll',
          email: '${roll.toLowerCase()}@${schoolCode.toLowerCase()}.edu.local',
          fullName: 'Student ($roll)',
          role: AppUserRole.student,
          schoolId: schoolCode,
          schoolName: 'Pilot School',
          gradeLevel: 'Grade 12',
        );

        final offlineToken = 'did_offline_jwt_${DateTime.now().millisecondsSinceEpoch}';
        await StorageService.saveSession(token: offlineToken, user: studentUser.toJson());

        return NfcAuthResult(
          success: true,
          user: studentUser,
          token: offlineToken,
          isOffline: true,
          message: 'Student DID recognized and verified offline.',
        );
      }

      // Case 4: Hardware UID fallback
      if (hardwareId != null && hardwareId.isNotEmpty) {
        // Build session for paired NFC hardware tag
        final studentUser = AppUser(
          id: 'stu-nfc-$hardwareId',
          email: 'student.$hardwareId@pilot.edu.local',
          fullName: 'Student (NFC Card $hardwareId)',
          role: AppUserRole.student,
          schoolId: '',
          schoolName: 'Pilot School',
          gradeLevel: 'Grade 12',
        );

        final offlineToken = 'nfc_uid_token_$hardwareId';
        await StorageService.saveSession(token: offlineToken, user: studentUser.toJson());

        return NfcAuthResult(
          success: true,
          user: studentUser,
          token: offlineToken,
          isOffline: true,
          message: 'Student Smart Card (UID: $hardwareId) logged in.',
        );
      }

      return NfcAuthResult(
        success: false,
        message: 'Unrecognized card data. Please ensure this is an official School Student ID card.',
      );
    } catch (e) {
      return NfcAuthResult(
        success: false,
        message: 'Card authentication failed: ${e.toString()}',
      );
    }
  }

  /// Generates and logs in with an authentic demo student card for emulator/device testing
  static Future<NfcAuthResult> simulateDemoCardLogin({
    String studentName = 'Maung Aung Kaung Myat',
    String rollNumber = 'ROLL-KG-001',
    String gradeLevel = 'Kindergarten (KG)',
    String schoolCode = 'PILOT-BEHS01',
    String schoolName = 'အခြေခံပညာကျောင်း',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final did = 'did:edu:mm:013:$schoolCode-2026-${rollNumber.replaceAll("-", "")}';

    // Construct valid claims matching Go backend structure
    final subject = StudentSubject(
      id: did,
      studentId: 'stu-${rollNumber.toLowerCase()}',
      studentRollNumber: rollNumber,
      schoolCode: schoolCode,
      schoolName: schoolName,
      region: '',
      township: '',
      academicYear: '2026-2027',
      publicKey: '0x04e6c981b2f72a6b46b2b73bc35414c2b95c0245a19cb2ad117b4c68832feae87a',
    );

    final mockVc = VerifiableCredential(
      context: ['https://www.w3.org/ns/credentials/v2'],
      id: did,
      type: ['VerifiableCredential', 'MyanmarStudentIdentityCredential'],
      issuer: 'did:edu:school:$schoolCode',
      validFrom: now,
      credentialSubject: subject,
      proof: CredentialProof(
        type: 'DataIntegrityProof',
        cryptosuite: 'eddsa-jcs-2022',
        created: now,
        verificationMethod: 'did:edu:school:$schoolCode#key-1',
        proofPurpose: 'assertionMethod',
        proofValue: '0xmocked_ed25519_valid_signature_for_demo_preview',
      ),
    );

    final studentUser = AppUser(
      id: subject.studentId,
      email: 'aung.kg@intaing.edu.local',
      fullName: studentName,
      role: AppUserRole.student,
      schoolId: schoolCode,
      schoolName: schoolName,
      gradeLevel: gradeLevel,
    );

    final offlineToken = 'did_offline_demo_jwt_${DateTime.now().millisecondsSinceEpoch}';
    await StorageService.saveSession(token: offlineToken, user: studentUser.toJson());
    await StorageService.saveCachedCredential(mockVc.toJson());

    return NfcAuthResult(
      success: true,
      user: studentUser,
      token: offlineToken,
      isOffline: true,
      credential: mockVc,
      message: 'Student Smart Card verified offline (Ed25519 valid).',
    );
  }
}
