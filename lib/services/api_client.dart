import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../constants/api_constants.dart';
import '../models/api_response.dart';
import '../routes/app_routes.dart';
import 'storage_service.dart';

class ApiClient {
  late final Dio dio;
  final StorageService _storage = Get.find<StorageService>();
  bool _isRefreshing = false;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !_isRefreshing &&
              _storage.refreshToken != null) {
            try {
              _isRefreshing = true;
              final refreshed = await _tryRefreshToken();
              _isRefreshing = false;
              if (refreshed) {
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer ${_storage.accessToken}';
                final clone = await dio.fetch(opts);
                return handler.resolve(clone);
              }
            } catch (_) {
              _isRefreshing = false;
            }
            await _storage.clearSession();
            Get.offAllNamed(AppRoutes.login);
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    final refresh = _storage.refreshToken;
    if (refresh == null) return false;

    final response = await dio.post(
      '${ApiConstants.auth}/refresh-token',
      data: {'refreshToken': refresh},
    );

    final data = response.data as Map<String, dynamic>;
    final inner = data['data'] as Map<String, dynamic>?;
    if (inner == null) return false;

    await _storage.updateTokens(
      token: inner['token'] as String,
      refreshToken: inner['refreshToken'] as String,
    );
    return true;
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? parser,
  }) async {
    final response = await dio.get(path, queryParameters: queryParameters);
    return _parseResponse(response, parser);
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? parser,
  }) async {
    final response = await dio.post(path, data: data);
    return _parseResponse(response, parser);
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? parser,
  }) async {
    final response = await dio.put(path, data: data);
    return _parseResponse(response, parser);
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? parser,
  }) async {
    final response = await dio.patch(path, data: data);
    return _parseResponse(response, parser);
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? parser,
  }) async {
    final response = await dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    return _parseResponse(response, parser);
  }

  T _parseResponse<T>(Response response, T Function(dynamic)? parser) {
    final body = response.data;
    if (parser == null) return body as T;
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return parser(body['data']);
    }
    return parser(body);
  }

  ApiError parseError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is String &&
        (data.contains('405 Not Allowed') || data.contains('nginx'))) {
      return ApiError(
        message:
            'Lỗi 405 từ nginx — API phải trỏ Gateway (http://127.0.0.1:7010), '
            'không phải Frontend (:5173). Chạy: ./tool/run_linux.sh',
        statusCode: status ?? 405,
      );
    }

    if (status == 405) {
      return ApiError(
        message:
            'HTTP 405 — sai địa chỉ API hoặc phương thức. '
            'Dùng Gateway :7010 (Docker) hoặc :5046 (dotnet run).',
        statusCode: 405,
      );
    }

    if (data is Map<String, dynamic>) {
      return ApiError.fromJson(data, statusCode: status);
    }
    return ApiError(
      message: e.message ?? 'Không thể kết nối máy chủ',
      statusCode: status,
    );
  }
}
