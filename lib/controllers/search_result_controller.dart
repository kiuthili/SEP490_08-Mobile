import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../models/tour_model.dart';
import '../../services/tour_service.dart';
import '../../services/catalog_service.dart';

class SearchResultController extends GetxController {
  final TourService _tourService = Get.find<TourService>();
  final CatalogService _catalogService = Get.find<CatalogService>();

  final tours = <TourModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;

  // Filter States
  final city = ''.obs;
  final startDate = ''.obs;
  final endDate = ''.obs;
  final minPrice = 0.obs;
  final maxPrice = 100000000.obs;
  final duration = 0.obs;
  final Rx<int?> categoryId = Rx<int?>(null);
  final sortBy = ''.obs;

  // Data for filters
  final categories = <CategoryModel>[].obs;
  final provinces = <String>[].obs;
  final isLoadingProvinces = false.obs;

  int _page = 1;
  late String _searchTerm;

  @override
  void onInit() {
    super.onInit();
    _searchTerm = Get.arguments as String? ?? '';
    _loadCategories();
    _loadProvinces();
    _fetchTours(refresh: true);
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _catalogService.getCategories();
      categories.value = list;
    } catch (_) {}
  }

  Future<void> _loadProvinces() async {
    isLoadingProvinces.value = true;
    try {
      final dio = Dio();
      final response =
          await dio.get('https://provinces.open-api.vn/api/v2/?depth=1');
      if (response.statusCode == 200) {
        final List data = response.data;
        provinces.value = data.map((e) => e['name'] as String).toList();
      }
    } catch (_) {
      // Fallback if API fails
      provinces.value = [
        'Thành phố Hồ Chí Minh',
        'Thành phố Hà Nội',
        'Thành phố Đà Nẵng',
        'Thành phố Hải Phòng',
        'Thành phố Cần Thơ',
        'Tỉnh Bà Rịa - Vũng Tàu',
        'Tỉnh Khánh Hòa',
        'Tỉnh Lâm Đồng',
        'Tỉnh Quảng Ninh',
        'Thừa Thiên Huế'
      ];
    } finally {
      isLoadingProvinces.value = false;
    }
  }

  Future<void> _fetchTours({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      hasMore.value = true;
      isLoading.value = true;
    } else {
      if (!hasMore.value || isLoadingMore.value) return;
      isLoadingMore.value = true;
    }

    try {
      final processedCity = _cleanCityName(city.value);

      final result = await _tourService.searchTours(
        searchTerm: _searchTerm,
        page: _page,
        pageSize: 20,
        city: processedCity,
        startDate: startDate.value,
        endDate: endDate.value,
        minPrice: minPrice.value,
        maxPrice: maxPrice.value,
        duration: duration.value,
        categoryId: categoryId.value,
        sortBy: sortBy.value.isEmpty ? null : sortBy.value,
      );

      if (refresh) {
        tours.value = result.data;
      } else {
        tours.addAll(result.data);
      }

      hasMore.value = result.hasMore;
      if (hasMore.value) _page++;
    } catch (_) {
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  void loadMore() => _fetchTours(refresh: false);

  void applyFilters() {
    _fetchTours(refresh: true);
  }

  void clearFilters() {
    city.value = '';
    startDate.value = '';
    endDate.value = '';
    minPrice.value = 0;
    maxPrice.value = 100000000;
    duration.value = 0;
    categoryId.value = null;
    sortBy.value = '';
    applyFilters();
  }

  String get currentSearchTerm => _searchTerm;

  String _cleanCityName(String rawCity) {
    if (rawCity.isEmpty) return '';

    // Remove "Thành phố", "Tỉnh"
    String cleaned = rawCity
        .replaceAll(RegExp(r'^Thành phố\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Tỉnh\s+', caseSensitive: false), '')
        .trim();

    // Remove Vietnamese tones
    cleaned = _removeVietnameseTones(cleaned);

    return cleaned;
  }

  String _removeVietnameseTones(String str) {
    str = str.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    str = str.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    str = str.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    str = str.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    str = str.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    str = str.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    str = str.replaceAll(RegExp(r'[đ]'), 'd');
    str = str.replaceAll(RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'), 'A');
    str = str.replaceAll(RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'), 'E');
    str = str.replaceAll(RegExp(r'[ÌÍỊỈĨ]'), 'I');
    str = str.replaceAll(RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'), 'O');
    str = str.replaceAll(RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'), 'U');
    str = str.replaceAll(RegExp(r'[ỲÝỴỶỸ]'), 'Y');
    str = str.replaceAll(RegExp(r'[Đ]'), 'D');
    return str;
  }
}
