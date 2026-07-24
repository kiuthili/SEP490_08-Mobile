import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../models/review_model.dart';
import 'base_service.dart';

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
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) return null;
        rethrow;
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
