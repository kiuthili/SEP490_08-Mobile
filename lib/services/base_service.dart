import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'api_client.dart';

mixin BaseServiceMixin on GetxService {
  ApiClient get api => Get.find<ApiClient>();

  Future<T> request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw api.parseError(e);
    }
  }

  T parseData<T>(dynamic body, T Function(Map<String, dynamic>) fromJson) {
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      if (map.containsKey('data') && map['data'] is Map) {
        return fromJson(Map<String, dynamic>.from(map['data'] as Map));
      }
      return fromJson(map);
    }
    throw StateError('Unexpected response format');
  }

  List<T> parseList<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    dynamic list = body;
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      if (map['data'] is List) {
        list = map['data'];
      } else if (map['data'] is Map) {
        final inner = Map<String, dynamic>.from(map['data'] as Map);
        list = inner['data'] ?? inner['items'] ?? [];
      }
    }
    if (list is! List) return [];
    final out = <T>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        out.add(fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Bỏ qua phần tử lỗi parse — tránh crash cả list.
      }
    }
    return out;
  }

  PaginationModel<T> parsePagination<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      final inner = map.containsKey('data') && map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : map;
      return PaginationModel.fromJson(inner, fromJson);
    }
    return PaginationModel(
      data: [],
      total: 0,
      totalPages: 0,
      currentPage: 1,
      pageSize: 10,
    );
  }
}

class PaginationModel<T> {
  final List<T> data;
  final int total;
  final int totalPages;
  final int currentPage;
  final int pageSize;

  PaginationModel({
    required this.data,
    required this.total,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  bool get hasMore => currentPage < totalPages;

  factory PaginationModel.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final rawList = json['data'] as List<dynamic>? ?? [];
    return PaginationModel(
      data: rawList
          .where((e) => e is Map)
          .map((e) => itemFromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      currentPage: json['currentPage'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
    );
  }
}
