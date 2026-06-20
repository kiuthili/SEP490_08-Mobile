import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/staff_controller.dart';
import '../services/storage_service.dart';
import '../utils/jwt_utils.dart';
import '../utils/auth_gate.dart';

class ShellController extends GetxController {
  ShellController({int? initialTab}) {
    if (initialTab != null) {
      selectedIndex.value = initialTab;
    }
  }

  final StorageService _storage = Get.find<StorageService>();
  final selectedIndex = 0.obs;

  /// Gợi ý tìm kiếm khi chuyển từ Trang chủ → Khám phá (giống query `/search` web).
  final exploreSearchTerm = Rxn<String>();
  final exploreOpenFilters = false.obs;

  bool get isStaff {
    final token = _storage.accessToken;
    if (token == null) return _storage.user?.isStaff ?? false;
    return JwtUtils.isStaff(token) || (_storage.user?.isStaff ?? false);
  }

  void changeTab(int index) {
    if (!AuthGate.isLoggedIn && index >= 2) {
      AuthGate.requireLogin(shellTab: index);
      return;
    }
    selectedIndex.value = index;
    if (!isStaff || !Get.isRegistered<StaffController>()) return;
    // Chỉ tải dữ liệu lịch khi mở tab cần — không fetch khi bấm danh sách lịch.
    if (index == 1 || index == 2) {
      Get.find<StaffController>().loadSelectedScheduleData();
    }
  }

  void openExplore({String? searchTerm, bool openFilters = false}) {
    if (searchTerm != null && searchTerm.trim().isNotEmpty) {
      exploreSearchTerm.value = searchTerm.trim();
    }
    exploreOpenFilters.value = openFilters;
    changeTab(1);
  }

  void openBookingsTab() => changeTab(3);
}
