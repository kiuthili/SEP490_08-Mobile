import 'package:get/get.dart';
import '../models/tour_model.dart';
import '../services/tour_service.dart';

class HomeController extends GetxController {
  final TourService _tourService = Get.find<TourService>();

  // Tour sections
  final hotTours = <TourModel>[].obs;
  final saleTours = <TourModel>[].obs;
  final upcomingTours = <TourModel>[].obs;
  final regionTours = <TourModel>[].obs;

  // Loading states
  final isLoadingHot = false.obs;
  final isLoadingSale = false.obs;
  final isLoadingUpcoming = false.obs;
  final isLoadingRegion = false.obs;

  // Region tabs: (display label, API key)
  static const regions = [
    ('Miền Bắc', 'north'),
    ('Miền Trung', 'central'),
    ('Miền Nam', 'south'),
  ];
  final selectedRegionIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAll();
  }

  Future<void> fetchAll() async {
    await Future.wait([
      _fetchHot(),
      _fetchSale(),
      _fetchUpcoming(),
      _fetchRegion(regions[0].$2),
    ]);
  }

  @override
  Future<void> refresh() => fetchAll();

  Future<void> _fetchHot() async {
    isLoadingHot.value = true;
    try {
      final res = await _tourService.getHotTours(pageSize: 10);
      hotTours.value = res.data;
    } catch (_) {
    } finally {
      isLoadingHot.value = false;
    }
  }

  Future<void> _fetchSale() async {
    isLoadingSale.value = true;
    try {
      final res = await _tourService.getSaleTours(pageSize: 10);
      saleTours.value = res.data;
    } catch (_) {
    } finally {
      isLoadingSale.value = false;
    }
  }

  Future<void> _fetchUpcoming() async {
    isLoadingUpcoming.value = true;
    try {
      final res = await _tourService.getUpcomingTours(pageSize: 10);
      upcomingTours.value = res.data;
    } catch (_) {
    } finally {
      isLoadingUpcoming.value = false;
    }
  }

  Future<void> _fetchRegion(String region) async {
    isLoadingRegion.value = true;
    try {
      regionTours.value =
          await _tourService.getToursByRegion(region, pageSize: 12);
    } catch (_) {
    } finally {
      isLoadingRegion.value = false;
    }
  }

  void selectRegion(int index) {
    if (selectedRegionIndex.value == index) return;
    selectedRegionIndex.value = index;
    _fetchRegion(regions[index].$2);
  }
}
