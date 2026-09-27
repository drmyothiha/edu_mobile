import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

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
}
