import 'package:get/get.dart';
import '../models/api_response.dart';
import '../models/tour_model.dart';
import '../services/tour_service.dart';
import '../utils/snackbar_helper.dart';

class TourController extends GetxController {
  final TourService _tourService = Get.find<TourService>();

  final tours = <TourModel>[].obs;
  final selectedTour = Rxn<TourModel>();
  final detailSchedules = <TourScheduleModel>[].obs;
  final isLoading = false.obs;
  final detailLoading = false.obs;
  final isLoadingMore = false.obs;
  final detailError = RxnString();

  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void onInit() {
    super.onInit();
    fetchTours();
  }

  Future<void> fetchTours({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      tours.clear();
    }
    isLoading.value = true;
    try {
      final result = await _tourService.getPublicTours(page: _currentPage);
      if (refresh) {
        tours.assignAll(result.data);
      } else {
        tours.addAll(result.data);
      }
      _totalPages = result.totalPages;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || _currentPage >= _totalPages) return;
    isLoadingMore.value = true;
    _currentPage++;
    try {
      final result = await _tourService.getPublicTours(page: _currentPage);
      tours.addAll(result.data);
      _totalPages = result.totalPages;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      _currentPage--;
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> fetchTourDetail(int id) async {
    detailLoading.value = true;
    detailError.value = null;
    if (selectedTour.value?.id != id) {
      selectedTour.value = null;
    }
    detailSchedules.clear();
    try {
      final result = await _tourService.getPublicTourDetail(id);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      selectedTour.value = result.tour;
      detailSchedules.assignAll(
        result.schedules.where(
          (schedule) => !schedule.returnDate.isBefore(today),
        ),
      );
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      detailError.value = e.message;
      selectedTour.value = null;
    } catch (e) {
      const message = 'Không tải được chi tiết tour';
      SnackbarHelper.error(message);
      detailError.value = message;
      selectedTour.value = null;
    } finally {
      detailLoading.value = false;
    }
  }

  Future<bool> requestConsultation({
    required int tourId,
    required String fullName,
    required String phone,
    required String email,
    String? note,
  }) async {
    try {
      await _tourService.requestConsultation(
        tourId: tourId,
        fullName: fullName,
        phone: phone,
        email: email,
        note: note,
      );
      SnackbarHelper.success(
          'Đã gửi yêu cầu tư vấn thành công! Chúng tôi sẽ sớm liên hệ với bạn.');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    } catch (e) {
      SnackbarHelper.error(
          'Không gửi được yêu cầu tư vấn. Vui lòng thử lại sau.');
      return false;
    }
  }
}
