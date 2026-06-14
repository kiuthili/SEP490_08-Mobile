import '../utils/json_utils.dart';

class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String? provider;
  final String? phoneNumber;
  final String? gender;
  final String? dateOfBirth;
  final DateTime? lastOnline;
  final List<String> roles;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.provider,
    this.phoneNumber,
    this.gender,
    this.dateOfBirth,
    this.lastOnline,
    this.roles = const [],
  });

  bool get isStaff => roles.any((r) => r.toLowerCase() == 'staff');

  bool get isCustomerOnly {
    if (roles.isEmpty) return false;
    return roles.every((role) => role.toLowerCase() == 'customer');
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = JsonUtils.pick(json, ['roles', 'Roles']);
    final roles = <String>[];
    if (rawRoles is List) {
      for (final r in rawRoles) {
        if (r is String) roles.add(r);
      }
    }
    return UserModel(
      id: JsonUtils.readInt(JsonUtils.pick(json, ['id', 'Id'])),
      email: JsonUtils.readString(JsonUtils.pick(json, ['email', 'Email'])) ?? '',
      fullName:
          JsonUtils.readString(JsonUtils.pick(json, ['fullName', 'FullName'])) ??
              '',
      avatarUrl:
          JsonUtils.readString(JsonUtils.pick(json, ['avatarUrl', 'AvatarUrl'])),
      provider:
          JsonUtils.readString(JsonUtils.pick(json, ['provider', 'Provider'])),
      phoneNumber: JsonUtils.readString(
        JsonUtils.pick(json, ['phoneNumber', 'PhoneNumber']),
      ),
      gender: JsonUtils.readString(JsonUtils.pick(json, ['gender', 'Gender'])),
      dateOfBirth: JsonUtils.readString(
        JsonUtils.pick(json, ['dateOfBirth', 'DateOfBirth']),
      ),
      lastOnline: JsonUtils.readDateTime(
        JsonUtils.pick(json, ['lastOnline', 'LastOnline']),
      ),
      roles: roles,
    );
  }

  UserModel copyWith({List<String>? roles}) => UserModel(
        id: id,
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        provider: provider,
        phoneNumber: phoneNumber,
        gender: gender,
        dateOfBirth: dateOfBirth,
        lastOnline: lastOnline,
        roles: roles ?? this.roles,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'provider': provider,
        'phoneNumber': phoneNumber,
        'gender': gender,
        'dateOfBirth': dateOfBirth,
        'lastOnline': lastOnline?.toIso8601String(),
        'roles': roles,
      };
}
