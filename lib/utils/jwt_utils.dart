import 'dart:convert';

class JwtUtils {
  JwtUtils._();

  static const _roleClaim =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static List<String> extractRoles(String token) {
    final payload = decodePayload(token);
    if (payload == null) return [];

    final roles = <String>[];
    void add(dynamic value) {
      if (value is String && value.isNotEmpty) roles.add(value);
      if (value is List) {
        for (final item in value) {
          if (item is String && item.isNotEmpty) roles.add(item);
        }
      }
    }

    add(payload[_roleClaim]);
    add(payload['role']);
    add(payload['roles']);
    return roles.toSet().toList();
  }

  static bool hasRole(String token, String role) =>
      extractRoles(token).any((r) => r.toLowerCase() == role.toLowerCase());

  static bool isStaff(String token) => hasRole(token, 'Staff');
}
