import 'package:get/get.dart';
import '../models/api_response.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';
import '../services/storage_service.dart';
import '../utils/snackbar_helper.dart';
import '../routes/app_routes.dart';
import '../utils/auth_gate.dart';

class ReviewController extends GetxController {
  final ReviewService _service = Get.find<ReviewService>();
  final reviews = <ReviewModel>[].obs;
  final myReviews = <ReviewModel>[].obs;
  final myReview = Rxn<ReviewModel>();
  final isLoading = false.obs;

  Future<void> fetchMyReviews() async {
    isLoading.value = true;
    try {
      myReviews.assignAll(await _service.getMyReviews());
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchReviews(int tourId) async {
    isLoading.value = true;
    try {
      reviews.assignAll(await _service.getReviewsByTour(tourId));
      final storage = Get.find<StorageService>();
      myReview.value =
          storage.isLoggedIn ? await _service.getMyReviewByTour(tourId) : null;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> submitReview({
    required int tourId,
    required int rating,
    String? comment,
    int? existingReviewId,
  }) async {
    if (!AuthGate.requireLogin(
      route: AppRoutes.tourDetail,
      arguments: tourId,
      message: 'login_required_review'.tr,
    )) {
      return false;
    }
    final customerId = Get.find<StorageService>().user?.id;
    if (customerId == null) {
      SnackbarHelper.error('login_required_review'.tr);
      return false;
    }
    if (existingReviewId != null &&
        (comment == null || comment.trim().isEmpty)) {
      SnackbarHelper.error('Nhận xét không được để trống khi cập nhật');
      return false;
    }
    try {
      if (existingReviewId != null) {
        await _service.updateReview(
          customerId: customerId,
          id: existingReviewId,
          rating: rating,
          comment: comment!.trim(),
        );
      } else {
        await _service.createReview(
          customerId: customerId,
          tourId: tourId,
          rating: rating,
          comment: comment,
        );
      }
      await fetchReviews(tourId);
      SnackbarHelper.success('Đã gửi đánh giá');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    }
  }
}
