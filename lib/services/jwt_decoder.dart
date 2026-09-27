import 'dart:convert';
import '../models/user_role.dart';

/// Utility to decode and parse JSON Web Tokens (JWT)
/// and extract role-based access control (RBAC) claims.
class JwtDecoder {
  /// Decodes the payload portion of a JWT string.
  /// Returns a map of claims, or null if the token is invalid.
  static Map<String, dynamic>? decode(String? token) {
    if (token == null || token.trim().isEmpty) return null;

    final cleanToken = token.trim();
    final parts = cleanToken.split('.');
    if (parts.length < 2) return null;

    try {
      final payloadNormalized = base64Url.normalize(parts[1]);
      final decodedBytes = base64Url.decode(payloadNormalized);
      final decodedString = utf8.decode(decodedBytes);
      return json.decode(decodedString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the user role from JWT claims.
  /// Matches "role", "user_role", or "role_name" claim keys.
  static AppUserRole? getRole(String? token) {
    final payload = decode(token);
    if (payload == null) return null;

    final roleStr = payload['role'] ?? payload['user_role'] ?? payload['role_name'];
    if (roleStr != null) {
      return AppUserRoleExtension.fromString(roleStr.toString());
    }
    return null;
  }

  /// Extracts email claim from JWT
  static String? getEmail(String? token) {
    final payload = decode(token);
    return payload?['email']?.toString();
  }

  /// Extracts user_id / sub claim from JWT
  static String? getUserId(String? token) {
    final payload = decode(token);
    return (payload?['user_id'] ?? payload?['sub'])?.toString();
  }

  /// Checks if token is expired based on 'exp' claim
  static bool isExpired(String? token) {
    final payload = decode(token);
    if (payload == null) return true;

    final exp = payload['exp'];
    if (exp == null) return false;

    if (exp is num) {
      final expDate = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().isAfter(expDate);
    }
    return false;
  }

  /// Utility to generate a valid mock 3-part JWT for offline testing / demo accounts.
  static String generateMockToken({
    required String role,
    required String email,
    String? userId,
    Duration duration = const Duration(hours: 24),
  }) {
    final now = DateTime.now();
    final exp = now.add(duration);

    final header = {
      'alg': 'HS256',
      'typ': 'JWT',
    };

    final payload = {
      'user_id': userId ?? 'demo-user-id',
      'sub': userId ?? 'demo-user-id',
      'email': email,
      'role': role,
      'iss': 'edu-platform',
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': exp.millisecondsSinceEpoch ~/ 1000,
    };

    final headerBase64 = base64Url.encode(utf8.encode(json.encode(header))).replaceAll('=', '');
    final payloadBase64 = base64Url.encode(utf8.encode(json.encode(payload))).replaceAll('=', '');
    final sigBase64 = base64Url.encode(utf8.encode('mock-signature-ed25519-hs256')).replaceAll('=', '');

    return '$headerBase64.$payloadBase64.$sigBase64';
  }
}
