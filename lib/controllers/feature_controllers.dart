import 'dart:async';

import 'package:get/get.dart';
import '../models/ai_models.dart';
import '../models/api_response.dart';
import '../models/feature_models.dart';
import '../models/order_model.dart';
import '../models/tour_model.dart';
import '../services/feature_services.dart';
import '../services/catalog_service.dart';
import '../services/location_helper.dart';
import '../services/order_service.dart';
import '../services/signalr_service.dart';
import '../services/social_service.dart';
import '../services/storage_service.dart';
import '../services/tour_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/ai_session.dart';

class OrderController extends GetxController {
  final OrderService _service = Get.find<OrderService>();
  final StorageService _storage = Get.find<StorageService>();

  final orders = <OrderModel>[].obs;
  final eligibleSchedules = <EligibleScheduleModel>[].obs;
  final selectedOrder = Rxn<OrderModel>();
  final statusFilter = Rxn<String>();
  final isLoading = false.obs;
  int _page = 1;
  int _totalPages = 1;

  void setStatusFilter(String? status) {
    statusFilter.value = status;
    fetchOrders(refresh: true);
  }

  Future<void> fetchEligibleSchedules() async {
    try {
      eligibleSchedules.assignAll(await _service.getEligibleSchedules());
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }

  Future<void> fetchOrders({bool refresh = false}) async {
    final userId = _storage.user?.id;
    if (userId == null) return;
    if (refresh) {
      _page = 1;
      orders.clear();
    }
    isLoading.value = true;
    try {
      final result = await _service.getMyOrders(
        userId: userId,
        page: _page,
        status: statusFilter.value,
      );
      if (refresh) {
        orders.assignAll(result.data);
      } else {
        orders.addAll(result.data);
      }
      _totalPages = result.totalPages;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  bool get canLoadMoreOrders => _page < _totalPages;

  Future<void> loadMoreOrders() async {
    if (isLoading.value || !canLoadMoreOrders) return;
    _page++;
    await fetchOrders();
  }

  Future<void> fetchOrderDetail(int id) async {
    isLoading.value = true;
    try {
      selectedOrder.value = await _service.getOrderDetail(id);
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> cancelOrder(int id) async {
    try {
      await _service.cancelOrder(id);
      orders.removeWhere((o) => o.id == id);
      if (selectedOrder.value?.id == id) {
        await fetchOrderDetail(id);
      }
      SnackbarHelper.success('Đã hủy đơn hàng');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    }
  }

  Future<bool> requestCancellation({
    required int orderId,
    required String reason,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
  }) async {
    try {
      await _service.requestCancellation(
        orderId: orderId,
        reason: reason,
        bankName: bankName,
        accountNumber: accountNumber,
        accountHolderName: accountHolderName,
      );
      SnackbarHelper.success('Đã gửi yêu cầu hủy tour');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    }
  }
}

class WishlistController extends GetxController {
  final WishlistService _service = Get.find<WishlistService>();
  final items = <WishlistItemModel>[].obs;
  final isLoading = false.obs;
  final processingTourIds = <int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchWishlist();
  }

  bool containsTour(int tourId) => items.any((i) => i.tourId == tourId);

  bool isProcessing(int tourId) => processingTourIds.contains(tourId);

  Future<void> fetchWishlist() async {
    isLoading.value = true;
    try {
      items.assignAll(await _service.getWishlist());
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Không tải được wishlist');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> toggleWishlist(
    int tourId, {
    required bool isInWishlist,
    bool showMessage = true,
  }) async {
    if (processingTourIds.contains(tourId)) return false;
    processingTourIds.add(tourId);
    processingTourIds.refresh();
    try {
      if (isInWishlist) {
        await _service.removeFromWishlist(tourId);
        items.removeWhere((i) => i.tourId == tourId);
        if (showMessage) SnackbarHelper.success('Đã xóa khỏi wishlist');
      } else {
        await _service.addToWishlist(tourId);
        await fetchWishlist();
        if (showMessage) SnackbarHelper.success('Đã thêm vào wishlist');
      }
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    } finally {
      processingTourIds.remove(tourId);
      processingTourIds.refresh();
    }
  }
}

class VoucherController extends GetxController {
  final VoucherService _service = Get.find<VoucherService>();
  final vouchers = <VoucherModel>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;

  Future<void> fetchVouchers() async {
    isLoading.value = true;
    try {
      final result = await _service.getMyVouchers();
      vouchers.assignAll(result.data);
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Không tải được danh sách voucher');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveVoucher(String code) async {
    isSaving.value = true;
    try {
      await _service.saveVoucher(code);
      await fetchVouchers();
      SnackbarHelper.success('Đã lưu voucher');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}

class AiController extends GetxController {
  final AiService _service = Get.find<AiService>();
  final recommendations = <TourRecommendationModel>[].obs;
  final recommendationDetail = Rxn<PersonalizedRecommendationModel>();
  final chatMessages = <AiChatMessageModel>[].obs;
  final summary = RxnString();
  final isLoading = false.obs;
  final isSendingChat = false.obs;
  final questionnaireLoading = false.obs;
  final questionnaireSubmitting = false.obs;
  final questionnaire = Rxn<StandardQuestionnaire>();
  final _chatSessionId = getOrCreateAiSessionId();

  Future<void> loadQuestionnaire() async {
    questionnaireLoading.value = true;
    try {
      questionnaire.value = await _service.getQuestionnaire();
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      questionnaireLoading.value = false;
    }
  }

  Future<bool> submitQuestionnaire(Map<String, dynamic> payload) async {
    questionnaireSubmitting.value = true;
    try {
      final result = await _service.recommendFromProfile(payload);
      recommendationDetail.value = result;
      recommendations.assignAll(result.recommendedTours);
      summary.value = result.summary.isEmpty ? null : result.summary;
      SnackbarHelper.success('Đã tạo gợi ý tour phù hợp');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    } finally {
      questionnaireSubmitting.value = false;
    }
  }

  Future<void> fetchRecommendations() async {
    isLoading.value = true;
    try {
      final result = await _service.getRecommendations();
      recommendationDetail.value = result;
      recommendations.assignAll(result.recommendedTours);
      summary.value = result.summary.isEmpty ? null : result.summary;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendChatMessage(String message) async {
    final text = message.trim();
    if (text.length < 2) {
      SnackbarHelper.error('Tin nhắn phải có ít nhất 2 ký tự');
      return;
    }
    if (text.length > 2000) {
      SnackbarHelper.error('Tin nhắn tối đa 2000 ký tự');
      return;
    }

    chatMessages.add(
      AiChatMessageModel(
        id: 'u-${DateTime.now().microsecondsSinceEpoch}',
        role: 'user',
        text: text,
      ),
    );
    isSendingChat.value = true;
    try {
      final response = await _service.sendChatMessage(
        message: text,
        sessionId: _chatSessionId,
      );
      chatMessages.add(
        AiChatMessageModel(
          id: 'a-${DateTime.now().microsecondsSinceEpoch}',
          role: 'assistant',
          text: response.reply,
          response: response,
        ),
      );
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isSendingChat.value = false;
    }
  }
}

class SocialController extends GetxController {
  final SocialService _service = Get.find<SocialService>();
  final SignalRService _signalR = Get.find<SignalRService>();
  final StorageService _storage = Get.find<StorageService>();

  final friends = <FriendModel>[].obs;
  final pendingRequests = <FriendRequestModel>[].obs;
  final searchResults = <UserSearchModel>[].obs;
  final moments = <MomentModel>[].obs;
  final chatRooms = <ChatRoomModel>[].obs;
  final groupChatRooms = <ChatRoomModel>[].obs;
  final isLoading = false.obs;
  final isFriendsLoading = false.obs;
  final isRequestsLoading = false.obs;
  final isSearchingUsers = false.obs;
  final isChatLoading = false.obs;
  final processingUserIds = <int>{}.obs;
  final processingRequestIds = <int>{}.obs;
  final processingFriendshipIds = <int>{}.obs;
  final sentRequestUserIds = <int>{}.obs;

  List<ChatRoomModel> get tourGroupChats =>
      chatRooms.where((r) => r.isGroup && r.scheduleId != null).toList();

  List<ChatRoomModel> get directChats =>
      chatRooms.where((r) => !r.isGroup).toList();

  @override
  void onInit() {
    super.onInit();
    unawaited(_connectFriendshipRealtime());
  }

  Future<void> _connectFriendshipRealtime() async {
    try {
      await _signalR.connectFriendship(
        onFriendRequest: () {
          unawaited(fetchPendingRequests());
          SnackbarHelper.success('Bạn có lời mời kết bạn mới');
        },
        onRequestResponded: (responderId, status) {
          sentRequestUserIds.remove(responderId);
          if (status.toLowerCase() == 'accepted') {
            unawaited(fetchFriends());
            SnackbarHelper.success('Lời mời kết bạn đã được chấp nhận');
          } else if (status.toLowerCase() == 'declined') {
            SnackbarHelper.info('Lời mời kết bạn đã bị từ chối');
          }
        },
        onFriendshipDeleted: (userId) {
          friends.removeWhere((friend) => friend.userId == userId);
          unawaited(fetchFriends());
          SnackbarHelper.info('Danh sách bạn bè vừa được cập nhật');
        },
        onReconnected: () {
          unawaited(fetchFriends());
          unawaited(fetchPendingRequests());
        },
      );
    } catch (_) {
      // REST flows remain available when the realtime connection is offline.
    }
  }

  @override
  void onClose() {
    unawaited(_signalR.disconnectFriendship());
    super.onClose();
  }

  void clearSocialState() {
    friends.clear();
    pendingRequests.clear();
    searchResults.clear();
    moments.clear();
    chatRooms.clear();
    groupChatRooms.clear();
    isLoading.value = false;
    isFriendsLoading.value = false;
    isRequestsLoading.value = false;
    isSearchingUsers.value = false;
    isChatLoading.value = false;
    processingUserIds.clear();
    processingRequestIds.clear();
    processingFriendshipIds.clear();
    sentRequestUserIds.clear();
  }

  Future<void> searchUsers(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      searchResults.clear();
      return;
    }
    isSearchingUsers.value = true;
    try {
      final result = await _service.searchUsers(query: normalized);
      final currentUserId = _storage.user?.id;
      searchResults.assignAll(
        result.data.where((user) => user.id != currentUserId),
      );
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isSearchingUsers.value = false;
    }
  }

  Future<void> fetchFriends() async {
    isFriendsLoading.value = true;
    try {
      friends.assignAll(await _service.getFriends());
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isFriendsLoading.value = false;
    }
  }

  Future<void> fetchPendingRequests() async {
    isRequestsLoading.value = true;
    try {
      pendingRequests.assignAll(await _service.getPendingRequests());
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isRequestsLoading.value = false;
    }
  }

  bool isFriend(int userId) => friends.any((friend) => friend.userId == userId);

  bool hasIncomingRequest(int userId) =>
      pendingRequests.any((request) => request.senderId == userId);

  Future<bool> sendFriendRequest(int receiverId) async {
    if (processingUserIds.contains(receiverId)) return false;
    processingUserIds.add(receiverId);
    try {
      await _service.sendFriendRequest(receiverId);
      sentRequestUserIds.add(receiverId);
      SnackbarHelper.success('Đã gửi lời mời kết bạn');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    } finally {
      processingUserIds.remove(receiverId);
    }
  }

  Future<bool> respondRequest(int requestId, bool accept) async {
    if (processingRequestIds.contains(requestId)) return false;
    processingRequestIds.add(requestId);
    try {
      await _service.respondFriendRequest(requestId: requestId, accept: accept);
      pendingRequests.removeWhere((r) => r.id == requestId);
      if (accept) await fetchFriends();
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    } finally {
      processingRequestIds.remove(requestId);
    }
  }

  Future<bool> unfriend(int friendshipId) async {
    if (processingFriendshipIds.contains(friendshipId)) return false;
    processingFriendshipIds.add(friendshipId);
    try {
      await _service.unfriend(friendshipId);
      friends.removeWhere((f) => f.friendshipId == friendshipId);
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    } finally {
      processingFriendshipIds.remove(friendshipId);
    }
  }

  Future<ChatRoomModel?> createDirectChat(int friendId) async {
    if (processingUserIds.contains(friendId)) return null;
    processingUserIds.add(friendId);
    try {
      final room = await _service.createDirectChat(friendId);
      await fetchChatRooms();
      return room;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return null;
    } finally {
      processingUserIds.remove(friendId);
    }
  }

  Future<void> fetchMoments({int? scheduleId}) async {
    isLoading.value = true;
    try {
      moments.assignAll(await _service.getMoments(scheduleId: scheduleId));
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> shareMoment({
    required int scheduleId,
    required String imagePath,
    String? caption,
  }) async {
    final userId = _storage.user?.id;
    if (userId == null) return false;
    try {
      final pos = await LocationHelper.getCurrentPosition();
      await _service.createMoment(
        userId: userId,
        scheduleId: scheduleId,
        imagePath: imagePath,
        lat: pos?.latitude ?? 0,
        lng: pos?.longitude ?? 0,
        caption: caption,
      );
      await fetchMoments(scheduleId: scheduleId);
      SnackbarHelper.success('Đã chia sẻ moment');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    }
  }

  Future<void> reactMoment(int momentId) async {
    final userId = _storage.user?.id;
    if (userId == null) return;
    try {
      await _service.toggleReaction(momentId, userId);
      await fetchMoments();
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }

  Future<void> commentMoment(int momentId, String content) async {
    final userId = _storage.user?.id;
    if (userId == null) return;
    try {
      await _service.addComment(momentId, content, userId);
      await fetchMoments();
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }

  Future<void> updateComment(int commentId, String content) async {
    final userId = _storage.user?.id;
    if (userId == null) return;
    try {
      await _service.updateComment(commentId, content, userId);
      await fetchMoments();
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }

  Future<void> deleteComment(int commentId) async {
    final userId = _storage.user?.id;
    if (userId == null) return;
    try {
      await _service.deleteComment(commentId, userId);
      await fetchMoments();
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }

  Future<void> deleteMoment(int momentId) async {
    final userId = _storage.user?.id;
    if (userId == null) return;
    try {
      await _service.deleteMoment(momentId, userId);
      moments.removeWhere((m) => m.id == momentId);
      SnackbarHelper.success('Đã xóa moment');
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }

  Future<void> fetchChatRooms() async {
    isChatLoading.value = true;
    try {
      chatRooms.assignAll(await _service.getChatRooms());
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isChatLoading.value = false;
    }
  }

  Future<void> shareLocationPing(int scheduleId) async {
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (pos == null) {
        SnackbarHelper.error('Không lấy được vị trí GPS');
        return;
      }
      await _service.pingLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        scheduleId: scheduleId,
      );
      SnackbarHelper.success('Đã chia sẻ vị trí');
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }
}

class StaffController extends GetxController {
  final TourService _tourService = Get.find<TourService>();
  final OrderService _orderService = Get.find<OrderService>();

  final schedules = <AssignedScheduleModel>[].obs;
  final customers = <ScheduleCustomerModel>[].obs;
  final tickets = <TicketModel>[].obs;
  final liveLocations = <LiveLocationModel>[].obs;
  final selectedScheduleId = Rxn<int>();
  final isLoading = false.obs;
  int? _loadedDetailForScheduleId;

  @override
  void onInit() {
    super.onInit();
    fetchAssignedSchedules();
  }

  Future<void> fetchAssignedSchedules() async {
    isLoading.value = true;
    try {
      schedules.assignAll(await _tourService.getAssignedSchedules());
      if (schedules.isNotEmpty && selectedScheduleId.value == null) {
        selectedScheduleId.value = schedules.first.scheduleId;
      }
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  /// Chỉ đổi lịch đang chọn — không gọi API (tránh rebuild tab ẩn khi tap).
  void selectSchedule(int scheduleId) {
    if (selectedScheduleId.value == scheduleId) return;
    selectedScheduleId.value = scheduleId;
    _loadedDetailForScheduleId = null;
  }

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
      customers.assignAll(await _orderService.getScheduleCustomers(scheduleId));
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
  }

  Future<void> fetchTickets(int scheduleId) async {
    try {
      tickets.assignAll(await _orderService.getTicketsBySchedule(scheduleId));
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    }
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

  Future<bool> checkIn(String qrCode) async {
    final scheduleId = selectedScheduleId.value;
    if (scheduleId == null) {
      SnackbarHelper.error('Chọn lịch trình trước');
      return false;
    }
    try {
      await _orderService.checkIn(qrCode: qrCode, scheduleId: scheduleId);
      await fetchTickets(scheduleId);
      SnackbarHelper.success('Check-in thành công');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    }
  }
}

class BookingPassengerInput {
  final int tourScheduleTicketId;
  final int ticketTypeId;
  final int unitPrice;
  final String ticketLabel;

  BookingPassengerInput({
    required this.tourScheduleTicketId,
    required this.ticketTypeId,
    required this.unitPrice,
    required this.ticketLabel,
  });
}

class BookingController extends GetxController {
  final TourService _tourService = Get.find<TourService>();
  final OrderService _orderService = Get.find<OrderService>();
  final VoucherService _voucherService = Get.find<VoucherService>();
  final CatalogService _catalogService = Get.find<CatalogService>();

  final tickets = <ScheduleTicketModel>[].obs;
  final ticketTypeNames = <int, String>{}.obs;
  final selectedSchedule = Rxn<TourScheduleModel>();
  final ticketQuantities = <int, int>{}.obs;
  final voucherCode = ''.obs;
  final discountAmount = 0.obs;
  final isLoading = false.obs;
  final isApplyingVoucher = false.obs;
  final ticketsLoading = false.obs;
  final note = ''.obs;

  String checkoutTourName = '';
  String? checkoutTourImageUrl;
  String? checkoutTourLocation;
  int? checkoutTourId;

  int get totalPassengers =>
      ticketQuantities.values.fold(0, (sum, q) => sum + q);

  int get subtotal {
    var total = 0;
    for (final t in tickets) {
      final q = ticketQuantities[t.id] ?? 0;
      total += t.price * q;
    }
    return total;
  }

  int get finalAmount => (subtotal - discountAmount.value).clamp(0, 1 << 31);

  List<ScheduleTicketModel> get activeTickets => tickets
      .where((t) => t.isActive != false && t.availableQuantity > 0)
      .toList();

  void resetCheckout() {
    tickets.clear();
    ticketTypeNames.clear();
    selectedSchedule.value = null;
    ticketQuantities.clear();
    voucherCode.value = '';
    discountAmount.value = 0;
    note.value = '';
    checkoutTourName = '';
    checkoutTourImageUrl = null;
    checkoutTourLocation = null;
    checkoutTourId = null;
  }

  Future<bool> initCheckout({
    required int tourId,
    required String tourName,
    String? tourImageUrl,
    String? tourLocation,
    required int scheduleId,
    required DateTime departureDate,
    required DateTime returnDate,
  }) async {
    resetCheckout();
    checkoutTourId = tourId;
    checkoutTourName = tourName;
    checkoutTourImageUrl = tourImageUrl;
    checkoutTourLocation = tourLocation;
    selectedSchedule.value = TourScheduleModel(
      id: scheduleId,
      tourId: tourId,
      departureDate: departureDate,
      returnDate: returnDate,
    );
    ticketsLoading.value = true;
    try {
      tickets.assignAll(await _tourService.getScheduleTickets(scheduleId));
      await _loadTicketTypeNames();
      ticketQuantities.clear();
      for (final t in activeTickets) {
        ticketQuantities[t.id] = 0;
      }
      return activeTickets.isNotEmpty;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    } catch (_) {
      SnackbarHelper.error('Không tải được loại vé');
      return false;
    } finally {
      ticketsLoading.value = false;
    }
  }

  int ticketQty(int ticketId) => ticketQuantities[ticketId] ?? 0;

  String ticketTypeName(int ticketTypeId) {
    final name = ticketTypeNames[ticketTypeId]?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Loại vé #$ticketTypeId';
  }

  Future<void> _loadTicketTypeNames() async {
    final ids = tickets
        .map((ticket) => ticket.ticketTypeId)
        .where((id) => id > 0)
        .toSet();
    if (ids.isEmpty) return;

    final entries = await Future.wait(
      ids.map((id) async {
        try {
          final ticketType = await _catalogService.getTicketTypeById(id);
          final name = ticketType.name.trim();
          if (name.isEmpty) return null;
          return MapEntry(id, name);
        } catch (_) {
          return null;
        }
      }),
    );

    ticketTypeNames.addEntries(entries.whereType<MapEntry<int, String>>());
  }

  void setTicketQty(int ticketId, int qty) {
    final ticket = tickets.firstWhereOrNull((t) => t.id == ticketId);
    if (ticket == null) return;
    final max = ticket.availableQuantity;
    ticketQuantities[ticketId] = qty.clamp(0, max);
    discountAmount.value = 0;
  }

  void incrementTicket(int ticketId) {
    setTicketQty(ticketId, ticketQty(ticketId) + 1);
  }

  void decrementTicket(int ticketId) {
    setTicketQty(ticketId, ticketQty(ticketId) - 1);
  }

  List<BookingPassengerInput> buildPassengerSlots() {
    final slots = <BookingPassengerInput>[];
    for (final t in tickets) {
      final q = ticketQty(t.id);
      for (var i = 0; i < q; i++) {
        slots.add(
          BookingPassengerInput(
            tourScheduleTicketId: t.id,
            ticketTypeId: t.ticketTypeId,
            unitPrice: t.price,
            ticketLabel: ticketTypeName(t.ticketTypeId),
          ),
        );
      }
    }
    return slots;
  }

  Future<bool> applyVoucher({bool saveBeforeApply = false}) async {
    final schedule = selectedSchedule.value;
    if (schedule == null || voucherCode.value.isEmpty || subtotal <= 0) {
      return false;
    }
    isApplyingVoucher.value = true;
    try {
      if (saveBeforeApply) {
        try {
          await _voucherService.saveVoucher(voucherCode.value);
        } on ApiError catch (e) {
          final msg = e.message.toLowerCase();
          if (!msg.contains('already saved')) rethrow;
        }
      }
      final result = await _voucherService.applyVoucher(
        code: voucherCode.value,
        billAmount: subtotal,
        tourId: schedule.tourId,
      );
      discountAmount.value = (result['discountAmount'] as num?)?.toInt() ?? 0;
      SnackbarHelper.success('Áp dụng voucher thành công');
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      discountAmount.value = 0;
      return false;
    } finally {
      isApplyingVoucher.value = false;
    }
  }

  Future<OrderModel?> bookTour({
    required List<Map<String, dynamic>> passengers,
    String? orderNote,
  }) async {
    final schedule = selectedSchedule.value;
    if (schedule == null) {
      SnackbarHelper.error('Thiếu lịch khởi hành');
      return null;
    }
    if (passengers.isEmpty) {
      SnackbarHelper.error('Chọn ít nhất một vé');
      return null;
    }

    final detailsByTicket = <int, List<Map<String, dynamic>>>{};
    for (final p in passengers) {
      final ticketId = p['tourScheduleTicketId'] as int;
      detailsByTicket.putIfAbsent(ticketId, () => []).add(p);
    }

    final orderDetails = <Map<String, dynamic>>[];
    for (final entry in detailsByTicket.entries) {
      final ticket = tickets.firstWhereOrNull((t) => t.id == entry.key);
      if (ticket == null) continue;
      orderDetails.add({
        'tourScheduleTicketId': ticket.id,
        'ticketTypeId': ticket.ticketTypeId,
        'unitPrice': ticket.price,
        'tickets': entry.value
            .map(
              (p) => {
                'attendeeName': p['attendeeName'],
                'idCard': p['idCard'],
                'dateOfBirth': p['dateOfBirth'],
                'gender': p['gender'],
                'nationality': p['nationality'],
              },
            )
            .toList(),
      });
    }

    isLoading.value = true;
    try {
      final order = await _orderService.createOrder(
        scheduleId: schedule.id,
        finalAmount: finalAmount,
        voucherCode: voucherCode.value.isNotEmpty ? voucherCode.value : null,
        note: orderNote,
        orderDetails: orderDetails,
      );
      SnackbarHelper.success(
        'Đã tạo đơn. Hoàn tất thanh toán để xác nhận chỗ.',
      );
      return order;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
    return null;
  }
}
