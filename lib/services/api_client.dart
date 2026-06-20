import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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
    _configureLocalDevCertificates();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.accessToken;
          if (token != null && token.isNotEmpty && _shouldAttachAuth(options)) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          var currentError = error;
          try {
            final redirect = await _tryFollowPreservedRedirect(currentError);
            if (redirect != null) {
              return handler.resolve(redirect);
            }
          } on DioException catch (redirectError) {
            currentError = redirectError;
          }

          if (currentError.response?.statusCode == 401) {
            if (!_isRefreshing && _storage.refreshToken != null) {
              try {
                _isRefreshing = true;
                final refreshed = await _tryRefreshToken();
                _isRefreshing = false;
                if (refreshed) {
                  final opts = currentError.requestOptions;
                  opts.headers['Authorization'] =
                      'Bearer ${_storage.accessToken}';
                  final clone = await dio.fetch(opts);
                  return handler.resolve(clone);
                }
              } catch (_) {
                _isRefreshing = false;
              }
            }
            await _storage.clearSession();
            Get.offAllNamed(AppRoutes.login);
          }
          handler.next(currentError);
        },
      ),
    );
  }

  bool _shouldAttachAuth(RequestOptions options) {
    final path = options.path.toLowerCase();
    final uri = Uri.tryParse(path);
    final normalizedPath = uri?.path.toLowerCase() ?? path;
    const publicAuthPaths = {
      '/api/auth/login',
      '/api/auth/register',
      '/api/auth/google-login',
      '/api/auth/forgot-password',
      '/api/auth/reset-password',
      '/api/auth/refresh-token',
    };
    if (publicAuthPaths.contains(normalizedPath)) return false;

    const publicPrefixes = {
      '/api/tours/public',
      '/api/tours/search',
      '/api/categories',
      '/api/banners',
      '/api/tickettypes',
      '/api/tourisminformation',
      '/api/touritineraries',
      '/api/tourscheduleitineraries',
    };
    if (publicPrefixes.any(normalizedPath.startsWith)) return false;

    final isPublicTourReview =
        normalizedPath.startsWith('/api/reviews/tour/') &&
            !normalizedPath.endsWith('/mine');
    return !isPublicTourReview;
  }

  Future<Response<dynamic>?> _tryFollowPreservedRedirect(
    DioException error,
  ) async {
    final status = error.response?.statusCode;
    if (status != 307 && status != 308) return null;

    final rawLocation = error.response?.headers.value('location');
    if (rawLocation == null || rawLocation.isEmpty) return null;

    final current = error.requestOptions.uri;
    final target = current.resolve(rawLocation);
    if (!_isAllowedLocalRedirect(current, target)) return null;

    final redirectCount =
        (error.requestOptions.extra['redirectCount'] as int?)?.clamp(0, 10) ??
            0;
    if (redirectCount >= 3) return null;

    final normalizedTarget = _normalizeLocalRedirectHost(current, target);
    final opts = error.requestOptions.copyWith(
      baseUrl: '',
      path: normalizedTarget.toString(),
      queryParameters: const {},
      extra: {
        ...error.requestOptions.extra,
        'redirectCount': redirectCount + 1,
      },
    );

    return dio.fetch<dynamic>(opts);
  }

  bool _isAllowedLocalRedirect(Uri current, Uri target) {
    if (current.scheme != 'http' || target.scheme != 'https') return false;
    if (!_isLocalDevHost(current.host) || !_isLocalDevHost(target.host)) {
      return false;
    }
    return current.path == target.path;
  }

  Uri _normalizeLocalRedirectHost(Uri current, Uri target) {
    if (target.host == 'localhost' || target.host == '127.0.0.1') {
      return target.replace(host: current.host);
    }
    return target;
  }

  void _configureLocalDevCertificates() {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        return HttpClient()
          ..badCertificateCallback = (_, host, port) {
            return _isLocalDevHost(host);
          };
      },
    );
  }

  bool _isLocalDevHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' ||
        normalized == '::1' ||
        normalized == '10.0.2.2' ||
        normalized == '127.0.0.1') {
      return true;
    }
    if (normalized.startsWith('127.') ||
        normalized.startsWith('10.') ||
        normalized.startsWith('192.168.')) {
      return true;
    }

    final parts = normalized.split('.');
    if (parts.length != 4 || parts.first != '172') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
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
        message: 'HTTP 405 — sai địa chỉ API hoặc phương thức. '
            'Dùng Gateway :7010 (Docker) hoặc :5046 (dotnet run).',
        statusCode: 405,
      );
    }

    if (data is Map<String, dynamic>) {
      final error = ApiError.fromJson(data, statusCode: status);
      if (error.retryAfterSeconds != null) return error;

      final retryAfter = int.tryParse(
        e.response?.headers.value('retry-after') ?? '',
      );
      return ApiError(
        message: error.message,
        statusCode: error.statusCode,
        retryAfterSeconds: retryAfter,
      );
    }
    return ApiError(
      message: e.message ?? 'Không thể kết nối máy chủ',
      statusCode: status,
    );
  }
}
