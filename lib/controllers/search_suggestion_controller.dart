import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../services/ai_trend_service.dart';
import '../../services/tour_service.dart';

class SearchSuggestionController extends GetxController {
  final TourService _tourService = Get.find<TourService>();
  final AiTrendService _aiTrendService = Get.find<AiTrendService>();

  final searchController = TextEditingController();
  final focusNode = FocusNode();

  final trendingProvinces = <String>[].obs;
  final hotTours = <TourModel>[].obs;
  final suggestions = <String>[].obs;

  final isLoadingTrending = false.obs;
  final isLoadingHotTours = false.obs;
  final isLoadingSuggestions = false.obs;

  Timer? _debounce;
  final searchTerm = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _fetchTrending();
    _fetchHotTours();

    searchController.addListener(() {
      searchTerm.value = searchController.text;
      _onSearchChanged(searchController.text);
    });
  }

  @override
  void onClose() {
    _debounce?.cancel();
    searchController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      suggestions.clear();
      isLoadingSuggestions.value = false;
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      isLoadingSuggestions.value = true;
      try {
        final normalized = removeVietnameseTones(query.trim());
        suggestions.value = await _tourService.getSearchSuggestions(normalized);
      } catch (e) {
        suggestions.clear();
      } finally {
        isLoadingSuggestions.value = false;
      }
    });
  }

  Future<void> _fetchTrending() async {
    isLoadingTrending.value = true;
    try {
      trendingProvinces.value = await _aiTrendService.getHotProvinces(limit: 6);
    } catch (_) {
    } finally {
      isLoadingTrending.value = false;
    }
  }

  Future<void> _fetchHotTours() async {
    isLoadingHotTours.value = true;
    try {
      final result = await _tourService.getHotTours(pageSize: 4);
      hotTours.value = result.data;
    } catch (_) {
    } finally {
      isLoadingHotTours.value = false;
    }
  }

  void onSearchSubmit(String query) {
    if (query.trim().isEmpty) return;
    final normalized = removeVietnameseTones(query.trim());
    Get.toNamed(AppRoutes.searchResult, arguments: normalized);
  }
}

// Giả lập hàm bỏ dấu tiếng việt đơn giản, tốt nhất dùng thư viện diacritic nếu có
String removeVietnameseTones(String str) {
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
