import '../utils/json_utils.dart';
import 'user_model.dart';

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class RegisterRequest {
  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final String otpCode;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    required this.otpCode,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'otpCode': otpCode,
      };
}

class LoginResponse {
  final UserModel user;
  final String token;
  final String refreshToken;
  final bool requirePhoneNumber;
  final String? idToken;

  LoginResponse({
    required this.user,
    required this.token,
    required this.refreshToken,
    this.requirePhoneNumber = false,
    this.idToken,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final requirePhone = JsonUtils.pick(json, ['requirePhoneNumber', 'RequirePhoneNumber']) == true;
    final userRaw = JsonUtils.pick(json, ['user', 'User']);
    if (userRaw is! Map<String, dynamic>) {
      throw StateError('Thiếu user trong phản hồi đăng nhập');
    }
    final token =
        JsonUtils.readString(JsonUtils.pick(json, ['token', 'Token'])) ?? '';
    final refresh = JsonUtils.readString(
      JsonUtils.pick(json, ['refreshToken', 'RefreshToken']),
    ) ?? '';
    if (!requirePhone && token.isEmpty) {
      throw StateError('Thiếu token trong phản hồi');
    }
    return LoginResponse(
      user: UserModel.fromJson(userRaw),
      token: token,
      refreshToken: refresh,
      requirePhoneNumber: requirePhone,
    );
  }
}

class RefreshTokenRequest {
  final String refreshToken;

  RefreshTokenRequest(this.refreshToken);

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

class ForgotPasswordResult {
  final int? retryAfterSeconds;
  final String? message;

  const ForgotPasswordResult({this.retryAfterSeconds, this.message});
}
