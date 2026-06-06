import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../models/ai_models.dart';
import '../models/feature_models.dart';
import '../models/tour_model.dart';
import 'base_service.dart';

class NotificationService extends GetxService with BaseServiceMixin {
  Future<List<NotificationModel>> getNotifications() async {
    return request(() async {
      final response = await api.dio.get(ApiConstants.notifications);
      return parseList(response.data, NotificationModel.fromJson);
    });
  }

  Future<void> markAsRead(int id) async {
    await request(() async {
      await api.dio.put('${ApiConstants.notifications}/$id/read');
    });
  }

  Future<void> deleteNotification(int id) async {
    await request(() async {
      await api.dio.delete('${ApiConstants.notifications}/$id');
    });
  }
}

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

class ReviewService extends GetxService with BaseServiceMixin {
  Future<List<ReviewModel>> getReviewsByTour(int tourId) async {
    return request(() async {
      final response =
          await api.dio.get('${ApiConstants.reviews}/tour/$tourId');
      return parseList(response.data, ReviewModel.fromJson);
    });
  }

  Future<ReviewModel?> getMyReviewByTour(int tourId) async {
    return request(() async {
      try {
        final response =
            await api.dio.get('${ApiConstants.reviews}/tour/$tourId/mine');
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return ReviewModel.fromJson(body);
        }
        return null;
      } catch (_) {
        return null;
      }
    });
  }

  Future<ReviewModel> createReview({
    required int customerId,
    required int tourId,
    required int rating,
    String? comment,
  }) async {
    return request(() async {
      final response = await api.dio.post(
        ApiConstants.reviews,
        data: {
          'customerId': customerId,
          'tourId': tourId,
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return ReviewModel.fromJson(body);
      }
      throw StateError('Invalid review response');
    });
  }

  Future<ReviewModel> updateReview({
    required int customerId,
    required int id,
    required int rating,
    required String comment,
  }) async {
    return request(() async {
      final response = await api.dio.patch(
        '${ApiConstants.reviews}/$id',
        data: {
          'customerId': customerId,
          'rating': rating,
          'comment': comment,
        },
      );
      return ReviewModel.fromJson(response.data as Map<String, dynamic>);
    });
  }

  Future<List<ReviewModel>> getMyReviews() async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.reviews}/mine');
      return parseList(response.data, ReviewModel.fromJson);
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
  }) async {
    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.aiTourAssistant}/chat',
        data: {
          'message': message,
          'sessionId': sessionId,
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
