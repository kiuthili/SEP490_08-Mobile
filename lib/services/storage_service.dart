import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import '../constants/storage_keys.dart';
import '../models/user_model.dart';

class StorageService {
  final GetStorage _box = GetStorage();

  String? get accessToken => _box.read<String>(StorageKeys.accessToken);
  String? get refreshToken => _box.read<String>(StorageKeys.refreshToken);
  bool get isLoggedIn => _box.read<bool>(StorageKeys.isLoggedIn) ?? false;

  UserModel? get user {
    final raw = _box.read<String>(StorageKeys.userJson);
    if (raw == null) return null;
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSession({
    required String token,
    required String refreshToken,
    required UserModel user,
  }) async {
    await _box.write(StorageKeys.accessToken, token);
    await _box.write(StorageKeys.refreshToken, refreshToken);
    await _box.write(StorageKeys.userJson, jsonEncode(user.toJson()));
    await _box.write(StorageKeys.isLoggedIn, true);
  }

  Future<void> updateTokens({
    required String token,
    required String refreshToken,
  }) async {
    await _box.write(StorageKeys.accessToken, token);
    await _box.write(StorageKeys.refreshToken, refreshToken);
  }

  Future<void> updateUser(UserModel user) async {
    await _box.write(StorageKeys.userJson, jsonEncode(user.toJson()));
  }

  Future<void> clearSession() async {
    await _box.remove(StorageKeys.accessToken);
    await _box.remove(StorageKeys.refreshToken);
    await _box.remove(StorageKeys.userJson);
    await _box.write(StorageKeys.isLoggedIn, false);
  }
}
