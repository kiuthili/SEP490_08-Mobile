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
    if (selectedTour.value?.id != id) {
      selectedTour.value = null;
    }
    detailSchedules.clear();
    try {
      selectedTour.value = await _tourService.getPublicTourDetail(id);
      detailSchedules.assignAll(await _tourService.getSchedulesByTour(id));
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      selectedTour.value = null;
    } catch (e) {
      SnackbarHelper.error('Không tải được chi tiết tour');
      selectedTour.value = null;
    } finally {
      detailLoading.value = false;
    }
  }
}
