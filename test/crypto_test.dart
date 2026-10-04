import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:edu_mobile/models/verifiable_credential.dart';

void main() {
  test('Cross-platform Ed25519 signature test with Go backend claims', () {
    const schoolCode = 'MMR013001001-PV01';
    final seedHash = sha256.convert(utf8.encode('edu-school-authority-signing-key:$schoolCode'));
    final privateKey = ed.newKeyFromSeed(Uint8List.fromList(seedHash.bytes));
    final publicKey = ed.public(privateKey);

    // Exact JSON string as marshaled in Go
    final claimsMap = {
      "id": "did:edu:mm:013:MMR013001001-PV01-2026-STU4883",
      "student_id": "4f703f66-22d3-4514-b5cc-1b449d3f1313",
      "student_roll_number": "ROLL-4883",
      "school_code": "MMR013001001-PV01",
      "school_name": "Yangon Academy High School",
      "region": "Yangon Region",
      "township": "Dagon",
      "academic_year": "2026-2027",
      "public_key": "5bf5fb13c1d233b8241382355718e439ac282133083c37b1668e5a00d9a6aaad"
    };

    final claimsJson = json.encode(claimsMap);
    final hash = sha256.convert(utf8.encode(claimsJson));

    // Decode signature hex
    const sigHex = "be0ea8168eb7ee6ab75d97b8c0eb65517197d8938f4578e266850806dc5c43b24b2a02403e31d959cf1a6544e8f4c40a1a47f939e15ba40193c65366b3e40d07";
    final sigBytes = <int>[];
    for (int i = 0; i < sigHex.length; i += 2) {
      sigBytes.add(int.parse(sigHex.substring(i, i + 2), radix: 16));
    }

    final isValid = ed.verify(publicKey, Uint8List.fromList(hash.bytes), Uint8List.fromList(sigBytes));
    expect(isValid, isTrue);
  });

  test('W3C VC 2.0 JSON parsing with credentialSchema and credentialStatus', () {
    final rawJson = {
      "@context": [
        "https://www.w3.org/ns/credentials/v2",
        "https://schema.edu.gov.mm/credentials/v2"
      ],
      "id": "urn:uuid:e8a2ec6a-b358-451f-aec6-35e677e71693",
      "type": ["VerifiableCredential", "StudentIdentityCredential"],
      "issuer": "did:edu:school:MMR013001001-PV01",
      "validFrom": "2026-09-28T14:33:20Z",
      "validUntil": "2027-05-31T23:59:59Z",
      "credentialSubject": {
        "id": "did:edu:mm:013:MMR013001001-PV01-2026-STU5779",
        "academic_year": "2026-2027",
        "region": "Yangon Region",
        "school_code": "MMR013001001-PV01",
        "school_name": "Yangon Academy High School",
        "student_id": "e8a2ec6a-b358-451f-aec6-35e677e71693",
        "student_roll_number": "ROLL-5779",
        "township": "Dagon"
      },
      "credentialSchema": {
        "id": "https://schema.edu.gov.mm/credentials/StudentIdentity.json",
        "type": "JsonSchema"
      },
      "credentialStatus": {
        "id": "https://registry.edu.gov.mm/status/1#42",
        "type": "BitstringStatusListEntry",
        "statusPurpose": "revocation",
        "statusListIndex": "42",
        "statusListCredential": "https://registry.edu.gov.mm/status/1"
      },
      "proof": {
        "type": "DataIntegrityProof",
        "cryptosuite": "eddsa-jcs-2022",
        "created": "2026-09-28T14:33:20Z",
        "proofPurpose": "assertionMethod",
        "verificationMethod": "did:edu:school:MMR013001001-PV01#key-1",
        "proofValue": "a4d382f..."
      }
    };

    final vc = VerifiableCredential.fromJson(rawJson);
    expect(vc.id, equals("urn:uuid:e8a2ec6a-b358-451f-aec6-35e677e71693"));
    expect(vc.credentialSchema, isNotNull);
    expect(vc.credentialSchema?.id, equals("https://schema.edu.gov.mm/credentials/StudentIdentity.json"));
    expect(vc.credentialSchema?.type, equals("JsonSchema"));
    expect(vc.credentialStatus, isNotNull);
    expect(vc.credentialStatus?.type, equals("BitstringStatusListEntry"));
    expect(vc.credentialStatus?.statusPurpose, equals("revocation"));
    expect(vc.credentialStatus?.statusListIndex, equals("42"));
    expect(vc.credentialStatus?.statusListCredential, equals("https://registry.edu.gov.mm/status/1"));
    expect(vc.credentialSubject.publicKey, isNull);
    expect(vc.credentialSubject.id, equals("did:edu:mm:013:MMR013001001-PV01-2026-STU5779"));

    final serialized = vc.toJson();
    expect(serialized['credentialSchema'], isNotNull);
    expect(serialized['credentialStatus'], isNotNull);
    expect(serialized['credentialSubject']['public_key'], isNull);
  });
}
