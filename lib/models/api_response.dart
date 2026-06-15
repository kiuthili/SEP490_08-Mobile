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
  final String message;
  final int? statusCode;
  final int? retryAfterSeconds;

  ApiError({
    required this.message,
    this.statusCode,
    this.retryAfterSeconds,
  });

  factory ApiError.fromJson(Map<String, dynamic>? json, {int? statusCode}) {
    final rawRetryAfter = json?['retryAfterSeconds'];
    return ApiError(
      message: json?['message'] as String? ?? 'Đã xảy ra lỗi',
      statusCode: statusCode,
      retryAfterSeconds: rawRetryAfter is int
          ? rawRetryAfter
          : int.tryParse(rawRetryAfter?.toString() ?? ''),
    );
  }
}
