/// Represents a W3C Verifiable Credentials 2.0 Student Identity Credential
/// Spec: https://www.w3.org/TR/vc-data-model-2.0/
class VerifiableCredential {
  final List<String> context;
  final String id;
  final List<String> type;
  final String issuer;
  final String validFrom;
  final String? validUntil;
  final StudentSubject credentialSubject;
  final CredentialProof proof;

  VerifiableCredential({
    required this.context,
    required this.id,
    required this.type,
    required this.issuer,
    required this.validFrom,
    this.validUntil,
    required this.credentialSubject,
    required this.proof,
  });

  factory VerifiableCredential.fromJson(Map<String, dynamic> json) {
    return VerifiableCredential(
      context: (json['@context'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['https://www.w3.org/ns/credentials/v2'],
      id: json['id']?.toString() ?? '',
      type: (json['type'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['VerifiableCredential', 'StudentIdentityCredential'],
      issuer: json['issuer']?.toString() ?? '',
      validFrom: json['validFrom']?.toString() ??
          json['issuanceDate']?.toString() ??
          '',
      validUntil: json['validUntil']?.toString(),
      credentialSubject: StudentSubject.fromJson(
          json['credentialSubject'] as Map<String, dynamic>? ?? {}),
      proof: CredentialProof.fromJson(
          json['proof'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        '@context': context,
        'id': id,
        'type': type,
        'issuer': issuer,
        'validFrom': validFrom,
        if (validUntil != null) 'validUntil': validUntil,
        'credentialSubject': credentialSubject.toJson(),
        'proof': proof.toJson(),
      };
}

class StudentSubject {
  final String id; // did:edu:mm:...
  final String studentId;
  final String studentRollNumber;
  final String schoolCode;
  final String schoolName;
  final String region;
  final String township;
  final String academicYear;
  final String publicKey;

  StudentSubject({
    required this.id,
    required this.studentId,
    required this.studentRollNumber,
    required this.schoolCode,
    required this.schoolName,
    required this.region,
    required this.township,
    required this.academicYear,
    required this.publicKey,
  });

  factory StudentSubject.fromJson(Map<String, dynamic> json) {
    return StudentSubject(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentRollNumber: json['student_roll_number']?.toString() ?? '',
      schoolCode: json['school_code']?.toString() ?? '',
      schoolName: json['school_name']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      township: json['township']?.toString() ?? '',
      academicYear: json['academic_year']?.toString() ?? '',
      publicKey: json['public_key']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'student_roll_number': studentRollNumber,
        'school_code': schoolCode,
        'school_name': schoolName,
        'region': region,
        'township': township,
        'academic_year': academicYear,
        'public_key': publicKey,
      };
}

class CredentialProof {
  final String type; // DataIntegrityProof or Ed25519Signature2020
  final String cryptosuite;
  final String created;
  final String verificationMethod;
  final String proofPurpose;
  final String proofValue;

  CredentialProof({
    required this.type,
    required this.cryptosuite,
    required this.created,
    required this.verificationMethod,
    required this.proofPurpose,
    required this.proofValue,
  });

  factory CredentialProof.fromJson(Map<String, dynamic> json) {
    return CredentialProof(
      type: json['type']?.toString() ?? 'DataIntegrityProof',
      cryptosuite: json['cryptosuite']?.toString() ?? 'eddsa-jcs-2022',
      created: json['created']?.toString() ?? '',
      verificationMethod: json['verificationMethod']?.toString() ?? '',
      proofPurpose: json['proofPurpose']?.toString() ?? 'assertionMethod',
      proofValue: json['proofValue']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'cryptosuite': cryptosuite,
        'created': created,
        'verificationMethod': verificationMethod,
        'proofPurpose': proofPurpose,
        'proofValue': proofValue,
      };
}

/// Offline / Online Verification Outcome
class VerificationResult {
  final bool isValid;
  final bool signatureValid;
  final bool isRevoked;
  final bool isOffline;
  final String did;
  final String studentName;
  final String studentRoll;
  final String schoolName;
  final String schoolCode;
  final String township;
  final String region;
  final String academicYear;
  final String credentialHash;
  final String? merkleRoot;
  final String? polygonTxHash;
  final DateTime verificationTime;
  final String message;

  VerificationResult({
    required this.isValid,
    required this.signatureValid,
    required this.isRevoked,
    this.isOffline = true,
    required this.did,
    required this.studentName,
    required this.studentRoll,
    required this.schoolName,
    required this.schoolCode,
    required this.township,
    required this.region,
    required this.academicYear,
    required this.credentialHash,
    this.merkleRoot,
    this.polygonTxHash,
    required this.verificationTime,
    required this.message,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      isValid: json['is_valid'] == true,
      signatureValid: json['signature_valid'] == true,
      isRevoked: json['is_revoked'] == true,
      isOffline: false,
      did: json['did']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? '',
      studentRoll: '',
      schoolName: json['school_name']?.toString() ?? '',
      schoolCode: json['school_code']?.toString() ?? '',
      township: '',
      region: '',
      academicYear: '',
      credentialHash: json['credential_hash']?.toString() ?? '',
      merkleRoot: json['merkle_root']?.toString(),
      polygonTxHash: json['polygon_tx_hash']?.toString(),
      verificationTime: json['verification_time'] != null
          ? DateTime.tryParse(json['verification_time'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'is_valid': isValid,
        'signature_valid': signatureValid,
        'is_revoked': isRevoked,
        'is_offline': isOffline,
        'did': did,
        'student_name': studentName,
        'student_roll': studentRoll,
        'school_name': schoolName,
        'school_code': schoolCode,
        'township': township,
        'region': region,
        'academic_year': academicYear,
        'credential_hash': credentialHash,
        'merkle_root': merkleRoot,
        'polygon_tx_hash': polygonTxHash,
        'verification_time': verificationTime.toIso8601String(),
        'message': message,
      };
}
