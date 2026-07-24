import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../models/ai_models.dart';
import '../models/feature_models.dart';
import '../models/tour_model.dart';
import 'base_service.dart';

class VoucherService extends GetxService with BaseServiceMixin {
  Future<void> saveVoucher(String code) async {
    await request(() async {
      await api.dio.post(
        ApiConstants.customerVouchers,
        data: {'code': code},
      );
    });
  }

  Future<PaginationModel<VoucherModel>> getMyVouchers({
    int page = 1,
    int pageSize = AppConstants.defaultPageSize,
    String? status,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        ApiConstants.customerVouchers,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (status != null) 'status': status,
        },
      );
      return parsePagination(response.data, VoucherModel.fromJson);
    });
  }

  Future<Map<String, dynamic>> applyVoucher({
    required String code,
    required int billAmount,
    int? tourId,
  }) async {
    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.customerVouchers}/apply',
        data: {
          'code': code,
          'billAmount': billAmount,
          if (tourId != null) 'tourId': tourId,
        },
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>? ?? body;
      }
      return {};
    });
  }
}

class WishlistService extends GetxService with BaseServiceMixin {
  Future<List<WishlistItemModel>> getWishlist() async {
    return request(() async {
      final response = await api.dio.get(ApiConstants.wishlists);
      return parseList(response.data, WishlistItemModel.fromJson);
    });
  }

  Future<void> addToWishlist(int tourId) async {
    await request(() async {
      await api.dio.post('${ApiConstants.wishlists}/tours/$tourId');
    });
  }

  Future<void> removeFromWishlist(int tourId) async {
    await request(() async {
      await api.dio.delete('${ApiConstants.wishlists}/tours/$tourId');
    });
  }
}

class AiService extends GetxService with BaseServiceMixin {
  Future<StandardQuestionnaire> getQuestionnaire() async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.aiTourAssistant}/questionnaire',
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return StandardQuestionnaire.fromJson(body);
      }
      throw StateError('Invalid questionnaire response');
    });
  }

  Future<PersonalizedRecommendationModel> recommendFromProfile(
    Map<String, dynamic> payload,
  ) async {
    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.aiTourAssistant}/recommend-from-profile',
        data: payload,
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw StateError('Invalid recommend response');
      }
      return PersonalizedRecommendationModel.fromJson(body);
    });
  }

  Future<AiChatResponseModel> sendChatMessage({
    required String message,
    required String sessionId,
    List<Map<String, String>>? history,
  }) async {
    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.aiIntelligentChat}/chat',
        data: {
          'message': message,
          'sessionId': sessionId,
          if (history != null) 'history': history,
        },
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return AiChatResponseModel.fromJson(body);
      }
      throw StateError('Invalid AI chat response');
    });
  }

  Future<PersonalizedRecommendationModel> getRecommendations({
    int top = 8,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.aiTourAssistant}/recommend',
        queryParameters: {'top': top},
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return PersonalizedRecommendationModel.fromJson(body);
      }
      return PersonalizedRecommendationModel(
        sessionId: '',
        summary: '',
        recommendedTours: parseList(
          response.data,
          TourRecommendationModel.fromJson,
        ),
      );
    });
  }
}
