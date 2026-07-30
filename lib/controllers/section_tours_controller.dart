import 'package:get/get.dart';
import '../models/tour_model.dart';
import '../services/tour_service.dart';
import '../services/base_service.dart';

class SectionToursController extends GetxController {
  final TourService _tourService = Get.find<TourService>();

  final title = ''.obs;
  final sectionType = ''.obs; // 'hot', 'sale', 'upcoming'

  final tours = <TourModel>[].obs;
  final isLoading = false.obs;
  final isLoadMore = false.obs;
  final hasMore = true.obs;

  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      title.value = args['title'] ?? 'Danh sách Tour';
      sectionType.value = args['type'] ?? 'hot';
    }
    fetchTours(isRefresh: true);
  }

  Future<void> fetchTours({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      hasMore.value = true;
      isLoading.value = true;
      tours.clear();
    } else {
      if (!hasMore.value || isLoadMore.value || isLoading.value) return;
      isLoadMore.value = true;
    }

    try {
      PaginationModel<TourModel>? result;
      switch (sectionType.value) {
        case 'hot':
          result = await _tourService.getHotTours(
              page: _currentPage, pageSize: _pageSize);
          break;
        case 'sale':
          result = await _tourService.getSaleTours(
              page: _currentPage, pageSize: _pageSize);
          break;
        case 'upcoming':
          result = await _tourService.getUpcomingTours(
              page: _currentPage, pageSize: _pageSize);
          break;
      }

      if (result != null) {
        if (isRefresh) {
          tours.value = result.data;
        } else {
          tours.addAll(result.data);
        }

        if (!result.hasMore || result.data.isEmpty) {
          hasMore.value = false;
        } else {
          _currentPage++;
        }
      }
    } catch (_) {
      // Handle error implicitly
    } finally {
      isLoading.value = false;
      isLoadMore.value = false;
    }
  }

  void refreshData() => fetchTours(isRefresh: true);
}
