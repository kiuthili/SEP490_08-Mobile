import 'package:get/get.dart';
import 'package:stayhub_mobile/models/api_response.dart';
import 'package:stayhub_mobile/models/check_in_result_model.dart';
import 'package:stayhub_mobile/models/feature_models.dart';
import 'package:stayhub_mobile/models/order_model.dart';
import 'package:stayhub_mobile/models/assigned_schedule_model.dart';
import 'package:stayhub_mobile/models/schedule_customer_model.dart';
import 'package:stayhub_mobile/models/staff_ticket_model.dart';
import 'package:stayhub_mobile/services/order_service.dart';
import 'package:stayhub_mobile/services/social_service.dart';
import 'package:stayhub_mobile/services/staff_service.dart';
import 'package:stayhub_mobile/utils/snackbar_helper.dart';

class StaffController extends GetxController {
  final StaffScheduleService _staffScheduleService =
  Get.find<StaffScheduleService>();
  final OrderService _orderService = Get.find<OrderService>();

  // ── Schedules list state ───────────────────────────────────────────────────
  final schedules = <AssignedScheduleModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final selectedScheduleId = Rxn<int>();

  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 10;

  final upcomingOnly = false.obs;
  final searchQuery = ''.obs;
  final customerNameFilter = ''.obs;
  // ── Schedule detail state ──────────────────────────────────────────────────
  final customers = <ScheduleCustomerModel>[].obs;
  final tickets = <StaffTicketModel>[].obs;
  final liveLocations = <LiveLocationModel>[].obs;
  int? _loadedDetailForScheduleId;

  // ── Ticket filter state ────────────────────────────────────────────────────
  final isLoadingTickets = false.obs;
  final ticketAttendeeFilter = ''.obs;
  final ticketStatusFilter = Rxn<String>(); // null = tất cả

  @override
  void onInit() {
    super.onInit();
    fetchAssignedSchedules();
  }

  // ── Schedule list ──────────────────────────────────────────────────────────

  Future<void> fetchAssignedSchedules() async {
    _currentPage = 1;
    _hasMore = true;
    isLoading.value = true;
    try {
      final result = await _staffScheduleService.getAssignedSchedules(
        page: _currentPage,
        pageSize: _pageSize,
        upcomingOnly: upcomingOnly.value,
        tourName: searchQuery.value.trim().isEmpty
            ? null
            : searchQuery.value.trim(),
      );
      schedules.assignAll(result.data);
      _hasMore = result.currentPage < result.totalPages;

      if (selectedScheduleId.value == null && result.data.isNotEmpty) {
        selectedScheduleId.value = result.data.first.scheduleId;
      }
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || isLoadingMore.value || isLoading.value) return;
    isLoadingMore.value = true;
    try {
      _currentPage++;
      final result = await _staffScheduleService.getAssignedSchedules(
        page: _currentPage,
        pageSize: _pageSize,
        upcomingOnly: upcomingOnly.value,
        tourName: searchQuery.value.trim().isEmpty
            ? null
            : searchQuery.value.trim(),
      );
      schedules.addAll(result.data);
      _hasMore = result.currentPage < result.totalPages;
    } on ApiError catch (e) {
      _currentPage--;
      SnackbarHelper.error(e.message);
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> setUpcomingOnly(bool value) async {
    if (upcomingOnly.value == value) return;
    upcomingOnly.value = value;
    await fetchAssignedSchedules();
  }

  Future<void> applySearch(String query) async {
    searchQuery.value = query;
    await fetchAssignedSchedules();
  }

  /// Chọn lịch trình → tự động tải dữ liệu (vé, khách, vị trí)
  void selectSchedule(int scheduleId) {
    if (selectedScheduleId.value == scheduleId) return;
    selectedScheduleId.value = scheduleId;
    _loadedDetailForScheduleId = null;
    // Reset filter khi đổi lịch
    ticketAttendeeFilter.value = '';
    ticketStatusFilter.value = null;
    tickets.clear();
    customers.clear();
    liveLocations.clear();
    loadSelectedScheduleData();
  }

  // ── Schedule detail ────────────────────────────────────────────────────────

  Future<void> loadSelectedScheduleData({bool force = false}) async {
    final scheduleId = selectedScheduleId.value;
    if (scheduleId == null) return;
    if (!force && _loadedDetailForScheduleId == scheduleId) return;
    _loadedDetailForScheduleId = scheduleId;
    await Future.wait([
      fetchCustomers(scheduleId),
      fetchTickets(scheduleId),
      fetchLiveLocations(scheduleId),
    ]);
  }

  Future<void> fetchCustomers(int scheduleId) async {
    try {
      customers.assignAll(
        await _orderService.getScheduleCustomers(
          scheduleId,
          attendeeName: customerNameFilter.value.trim().isEmpty
              ? null
              : customerNameFilter.value.trim(),
        ),
      );
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }

// Thêm method apply customer filter:
  Future<void> applyCustomerFilter(String name) async {
    customerNameFilter.value = name;
    final scheduleId = selectedScheduleId.value;
    if (scheduleId != null) await fetchCustomers(scheduleId);
  }

  /// Lấy danh sách vé – hỗ trợ filter tên hành khách & trạng thái check-in
  Future<void> fetchTickets(int scheduleId) async {
    isLoadingTickets.value = true;
    try {
      tickets.assignAll(
        await _orderService.getTicketsBySchedule(
          scheduleId,
          attendeeName: ticketAttendeeFilter.value.trim().isEmpty
              ? null
              : ticketAttendeeFilter.value.trim(),
          checkInStatus: ticketStatusFilter.value,
        ),
      );
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoadingTickets.value = false;
    }
  }

  /// Gọi lại API vé sau khi thay đổi filter
  Future<void> applyTicketFilters({
    required String attendeeName,
    required String? checkInStatus,
  }) async {
    ticketAttendeeFilter.value = attendeeName;
    ticketStatusFilter.value = checkInStatus;
    final scheduleId = selectedScheduleId.value;
    if (scheduleId != null) await fetchTickets(scheduleId);
  }

  Future<void> fetchLiveLocations(int scheduleId) async {
    try {
      final social = Get.find<SocialService>();
      liveLocations.assignAll(
        await social.getScheduleLiveLocations(scheduleId),
      );
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }

  Future<CheckInResultModel?> checkIn(String qrCode) async {
    try {
      final result = await _orderService.checkIn(qrCode: qrCode);
      // Reload vé của lịch trình hiện tại để cập nhật trạng thái
      final scheduleId = selectedScheduleId.value;
      if (scheduleId != null) await fetchTickets(scheduleId);
      return result;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return null;
    }
  }
}