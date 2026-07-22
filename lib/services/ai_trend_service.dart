import 'package:get/get.dart';
import 'base_service.dart';

// ─── Models ─────────────────────────────────────────────────────────────────

class ProvinceForecast {
  final String province;
  final double hotnessScore;
  final String status;

  ProvinceForecast({
    required this.province,
    required this.hotnessScore,
    required this.status,
  });

  factory ProvinceForecast.fromJson(Map<String, dynamic> j) {
    return ProvinceForecast(
      province: j['province'] as String? ?? '',
      hotnessScore: (j['hotnessScore'] as num?)?.toDouble() ?? 0,
      status: j['status'] as String? ?? '',
    );
  }
}

class TrendPredictionResult {
  final List<ProvinceForecast> provinceForecasts;

  TrendPredictionResult({required this.provinceForecasts});
}

// ─── Service ─────────────────────────────────────────────────────────────────

class AiTrendService extends GetxService with BaseServiceMixin {
  static const _fallbackProvinces = [
    'Đà Nẵng',
    'Hội An',
    'Đà Lạt',
    'Hạ Long',
    'Phú Quốc',
    'Sa Pa',
  ];

  /// Lấy top [limit] tỉnh đang hot nhất từ AI trend prediction.
  /// Fallback về danh sách cứng nếu API lỗi hoặc trả về rỗng.
  Future<List<String>> getHotProvinces({int limit = 6}) async {
    try {
      final response = await api.dio.get('/ai/trends/hot-tours');
      final body = response.data;

      List<dynamic> raw = [];
      if (body is Map<String, dynamic>) {
        final inner =
            body.containsKey('data') && body['data'] is Map ? body['data'] : body;
        raw = inner['provinceForecasts'] as List<dynamic>? ?? [];
      }

      if (raw.isEmpty) return _fallbackProvinces.take(limit).toList();

      return raw
          .whereType<Map<String, dynamic>>()
          .map(ProvinceForecast.fromJson)
          .take(limit)
          .map((p) => p.province)
          .where((p) => p.isNotEmpty)
          .toList();
    } catch (_) {
      return _fallbackProvinces.take(limit).toList();
    }
  }
}
