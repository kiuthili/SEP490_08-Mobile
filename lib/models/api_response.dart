/// Wrapper chuẩn từ AuthAPI: { message, data }
class ApiResponse<T> {
  final String? message;
  final T? data;

  ApiResponse({this.message, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      message: json['message'] as String?,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
    );
  }
}

class ApiError {
  static const String silent401Message = 'Phiên đăng nhập đã hết hạn';
  static const String silentTimeoutMessage = 'Kết nối quá hạn (silent)';

  final String message;
  final int? statusCode;
  final int? retryAfterSeconds;
  final int? lockoutMinutes;
  final int? remainingAttempts;
  final bool isSilent;

  ApiError({
    required this.message,
    this.statusCode,
    this.retryAfterSeconds,
    this.lockoutMinutes,
    this.remainingAttempts,
    bool? isSilent,
  }) : isSilent = isSilent ?? (statusCode == 401);

  factory ApiError.fromJson(Map<String, dynamic>? json, {int? statusCode}) {
    final rawRetryAfter = json?['retryAfterSeconds'];
    final rawLockout = json?['lockoutMinutes'];
    final rawRemaining = json?['remainingAttempts'];
    
    final is401 = statusCode == 401;
    String message = json?['message'] as String? ?? 
        (is401 ? silent401Message : 'Đã xảy ra lỗi');

    if (json != null && json.containsKey('errors')) {
      final errors = json['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final firstKey = errors.keys.first;
        final firstList = errors[firstKey];
        if (firstList is List && firstList.isNotEmpty) {
          message = firstList.first.toString();
        }
      }
    }

    return ApiError(
      message: message,
      statusCode: statusCode,
      retryAfterSeconds: rawRetryAfter is int
          ? rawRetryAfter
          : int.tryParse(rawRetryAfter?.toString() ?? ''),
      lockoutMinutes: rawLockout is int
          ? rawLockout
          : int.tryParse(rawLockout?.toString() ?? ''),
      remainingAttempts: rawRemaining is int
          ? rawRemaining
          : int.tryParse(rawRemaining?.toString() ?? ''),
      isSilent: is401,
    );
  }
}
