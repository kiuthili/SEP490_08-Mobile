import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../utils/jwt_utils.dart';
import 'base_service.dart';
import 'storage_service.dart';

class AuthService extends GetxService with BaseServiceMixin {
  final StorageService _storage = Get.find<StorageService>();

  Future<LoginResponse> login(LoginRequest payload) async {
    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.auth}/login',
        data: payload.toJson(),
      );
      return _handleAuthResponse(response.data as Map<String, dynamic>);
    });
  }

  Future<LoginResponse> register(RegisterRequest payload) async {
    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.auth}/register',
        data: payload.toJson(),
      );
      return _handleAuthResponse(response.data as Map<String, dynamic>);
    });
  }

  Future<UserModel> getProfile() async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.auth}/profile');
      final map = response.data as Map<String, dynamic>;
      final user = _withRoles(
        UserModel.fromJson(map['data'] as Map<String, dynamic>),
      );
      await _storage.updateUser(user);
      return user;
    });
  }

  Future<LoginResponse> googleLogin() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: ApiConstants.googleClientId.isNotEmpty
          ? ApiConstants.googleClientId
          : null,
      scopes: ['email', 'profile'],
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      throw ApiError(message: 'Đăng nhập Google bị hủy');
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw ApiError(message: 'Không lấy được Google ID token');
    }

    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.auth}/google-login',
        data: {'idToken': idToken},
      );
      return _handleAuthResponse(response.data as Map<String, dynamic>);
    });
  }

  Future<UserModel> updateProfile({
    required String fullName,
    String? phoneNumber,
    String? gender,
    String? dateOfBirth,
    String? avatarPath,
  }) async {
    return request(() async {
      final phone = phoneNumber?.trim();
      final formMap = <String, dynamic>{
        'fullName': fullName.trim(),
        if (phone != null && phone.isNotEmpty) 'phoneNumber': phone,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (dateOfBirth != null && dateOfBirth.isNotEmpty)
          'dateOfBirth': dateOfBirth,
        if (avatarPath != null)
          'avatarFile': await MultipartFile.fromFile(
            avatarPath,
            filename: avatarPath.split('/').last,
          ),
      };
      final response = await api.dio.put(
        '${ApiConstants.auth}/profile',
        data: FormData.fromMap(formMap),
        options: Options(
          contentType: 'multipart/form-data',
          headers: const {'Content-Type': null},
        ),
      );
      final map = response.data;
      if (map is! Map<String, dynamic>) {
        throw StateError('Phản hồi cập nhật hồ sơ không hợp lệ');
      }
      final data = map['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Thiếu data trong phản hồi cập nhật hồ sơ');
      }
      final loginResponse = LoginResponse.fromJson(data);
      final previousRefresh = _storage.refreshToken;
      final user = _withRoles(loginResponse.user, loginResponse.token);
      await _storage.saveSession(
        token: loginResponse.token,
        refreshToken: loginResponse.refreshToken.isNotEmpty
            ? loginResponse.refreshToken
            : previousRefresh ?? '',
        user: user,
      );
      return user;
    });
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await request(() async {
      await api.dio.post(
        '${ApiConstants.auth}/change-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );
    });
  }

  Future<void> forgotPassword(String email) async {
    await request(() async {
      await api.dio.post(
        '${ApiConstants.auth}/forgot-password',
        data: {'email': email},
      );
    });
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await request(() async {
      await api.dio.post(
        '${ApiConstants.auth}/reset-password',
        data: {
          'email': email,
          'code': code,
          'newPassword': newPassword,
        },
      );
    });
  }

  Future<void> logout() async {
    final refresh = _storage.refreshToken;
    if (refresh != null) {
      try {
        await api.dio.post(
          '${ApiConstants.auth}/logout',
          data: {'refreshToken': refresh},
        );
      } catch (_) {}
    }
    await _storage.clearSession();
  }

  Future<LoginResponse> _handleAuthResponse(Map<String, dynamic> map) async {
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiError(message: 'Phản hồi đăng nhập không hợp lệ');
    }
    final loginResponse = LoginResponse.fromJson(data);
    final user = _withRoles(loginResponse.user, loginResponse.token);
    if (!user.isCustomerOnly) {
      await _revokeRejectedSession(loginResponse.refreshToken);
      await _storage.clearSession();
      throw ApiError(
        message: 'Ứng dụng di động chỉ dành cho tài khoản Customer',
        statusCode: 403,
      );
    }
    await _storage.saveSession(
      token: loginResponse.token,
      refreshToken: loginResponse.refreshToken,
      user: user,
    );
    return LoginResponse(
      user: user,
      token: loginResponse.token,
      refreshToken: loginResponse.refreshToken,
    );
  }

  Future<void> _revokeRejectedSession(String refreshToken) async {
    if (refreshToken.isEmpty) return;
    try {
      await api.dio.post(
        '${ApiConstants.auth}/logout',
        data: {'refreshToken': refreshToken},
      );
    } catch (_) {
      // The local session is still cleared when server-side revocation fails.
    }
  }

  UserModel _withRoles(UserModel user, [String? token]) {
    final accessToken = token ?? _storage.accessToken;
    if (accessToken == null) return user;
    final roles = JwtUtils.extractRoles(accessToken);
    return user.copyWith(roles: roles);
  }
}
