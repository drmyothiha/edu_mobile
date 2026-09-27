import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import '../models/verifiable_credential.dart';

class CryptoService {
  /// Deterministically derives a school authority's public key from their MIMU Option A Code
  /// This matches the Go backend authority seed formula:
  /// `sha256("edu-school-authority-signing-key:" + schoolCode)`
  static ed.PublicKey deriveSchoolPublicKey(String schoolCode) {
    final seedString = 'edu-school-authority-signing-key:$schoolCode';
    final seedHash = sha256.convert(utf8.encode(seedString));
    final privateKey = ed.newKeyFromSeed(Uint8List.fromList(seedHash.bytes));
    return ed.public(privateKey);
  }

  /// Calculates the canonical SHA-256 digest of student claims matching Go's `ComputeCredentialHash`
  static String computeCredentialHash(Map<String, dynamic> claims) {
    final claimsJson = json.encode(claims);
    final digest = sha256.convert(utf8.encode(claimsJson));
    return '0x${digest.toString()}';
  }

  /// Converts hex string to byte list
  static Uint8List hexToBytes(String hexStr) {
    hexStr = hexStr.replaceAll('0x', '').trim();
    final bytes = <int>[];
    for (int i = 0; i < hexStr.length; i += 2) {
      bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  /// Verifies a W3C Verifiable Credential 2.0 offline using pure Ed25519
  static VerificationResult verifyCredentialOffline(VerifiableCredential vc) {
    final now = DateTime.now();
    final subject = vc.credentialSubject;
    final schoolCode = subject.schoolCode;

    if (schoolCode.isEmpty) {
      return VerificationResult(
        isValid: false,
        signatureValid: false,
        isRevoked: false,
        isOffline: true,
        did: subject.id,
        studentName: subject.studentRollNumber,
        studentRoll: subject.studentRollNumber,
        schoolName: subject.schoolName,
        schoolCode: schoolCode,
        township: subject.township,
        region: subject.region,
        academicYear: subject.academicYear,
        credentialHash: '',
        verificationTime: now,
        message: 'Missing school facility code in credential claims',
      );
    }

    try {
      // 1. Recompute canonical digest
      final claimsMap = subject.toJson();
      final claimsJson = json.encode(claimsMap);
      final hash = sha256.convert(utf8.encode(claimsJson));
      final hashHex = '0x$hash';

      // 2. Derive school authority public key
      final schoolPubKey = deriveSchoolPublicKey(schoolCode);

      // 3. Verify Ed25519 signature
      final sigBytes = hexToBytes(vc.proof.proofValue);
      final sigValid = ed.verify(
        schoolPubKey,
        Uint8List.fromList(hash.bytes),
        sigBytes,
      );

      final isValid = sigValid;

      String message;
      if (isValid) {
        message = 'Authentic Student ID verified offline (Ed25519 valid)';
      } else {
        message = 'Signature Verification Failed: Credential data modified';
      }

      return VerificationResult(
        isValid: isValid,
        signatureValid: sigValid,
        isRevoked: false,
        isOffline: true,
        did: subject.id,
        studentName: subject.studentRollNumber,
        studentRoll: subject.studentRollNumber,
        schoolName: subject.schoolName,
        schoolCode: schoolCode,
        township: subject.township,
        region: subject.region,
        academicYear: subject.academicYear,
        credentialHash: hashHex,
        verificationTime: now,
        message: message,
      );
    } catch (e) {
      return VerificationResult(
        isValid: false,
        signatureValid: false,
        isRevoked: false,
        isOffline: true,
        did: subject.id,
        studentName: subject.studentRollNumber,
        studentRoll: subject.studentRollNumber,
        schoolName: subject.schoolName,
        schoolCode: schoolCode,
        township: subject.township,
        region: subject.region,
        academicYear: subject.academicYear,
        credentialHash: '',
        verificationTime: now,
        message: 'Verification parsing error: ${e.toString()}',
      );
    }
  }

  /// Parses raw QR scan data (could be full JSON, compacted JSON, URL, or plain DID)
  static Map<String, dynamic>? parseScannedPayload(String rawData) {
    rawData = rawData.trim();

    // Check if rawData is a JSON payload
    if (rawData.startsWith('{') && rawData.endsWith('}')) {
      try {
        final decoded = json.decode(rawData);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        return null;
      }
    }

    // Check if rawData is an EduPlatform Verification URL e.g. http://.../edu/verify?did=...
    if (rawData.contains('verify?')) {
      try {
        final uri = Uri.parse(rawData);
        final did = uri.queryParameters['did'] ?? uri.queryParameters['identifier'];
        if (did != null) {
          return {'did': did, 'is_query': true};
        }
      } catch (_) {
        // fallback
      }
    }

    // Check if plain DID
    if (rawData.startsWith('did:edu:')) {
      return {'did': rawData, 'is_query': true};
    }

    return null;
  }
}
