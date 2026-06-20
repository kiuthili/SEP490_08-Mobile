import 'package:get/get.dart';
import 'package:stayhub_mobile/models/api_response.dart';
import 'package:stayhub_mobile/models/notification_model.dart';
import 'package:stayhub_mobile/services/notification_service.dart';
import 'package:stayhub_mobile/services/signalr_service.dart';
import 'package:stayhub_mobile/utils/snackbar_helper.dart';
import 'package:stayhub_mobile/utils/auth_gate.dart';

class NotificationController extends GetxController {
  final _service = Get.find<NotificationService>();
  final _signalRService = Get.find<SignalRService>();

  final notifications = <NotificationModel>[].obs;
  final isLoading = false.obs;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  void onInit() {
    super.onInit();
    if (!AuthGate.isLoggedIn) return;
    fetchNotifications();
    _connectRealtime();
  }

  @override
  void onClose() {
    _signalRService.disconnectNotification();
    super.onClose();
  }

  Future<void> fetchNotifications() async {
    if (!AuthGate.isLoggedIn) return;
    isLoading.value = true;
    try {
      notifications.assignAll(await _service.getNotifications());
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  /// Kết nối NotificationHub để nhận thông báo realtime khi app đang mở.
  Future<void> _connectRealtime() async {
    try {
      await _signalRService.connectNotification(
        onNotification: _handleIncomingNotification,
        onReconnected: () {
          // Sau khi reconnect, fetch lại để đảm bảo không miss thông báo
          // nào trong lúc mất kết nối.
          fetchNotifications();
        },
      );
    } catch (e) {
      // Không chặn UI nếu realtime fail — user vẫn xem được qua REST API.
    }
  }

  void _handleIncomingNotification(Map<String, dynamic> data) {
    try {
      final newNoti = NotificationModel.fromJson(data);

      // Tránh duplicate nếu đã có (ví dụ do fetch lại sau reconnect)
      if (notifications.any((n) => n.id == newNoti.id)) return;

      notifications.insert(0, newNoti);
    } catch (_) {
      // Nếu parse lỗi, fallback fetch lại toàn bộ list
      fetchNotifications();
    }
  }

  Future<void> markRead(int id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx < 0 || notifications[idx].isRead) return;

    // 1. Cập nhật UI ngay lập tức cho mượt
    notifications[idx] = notifications[idx].copyWith(isRead: true);

    // 2. Gọi API ngầm
    try {
      await _service.markAsRead(id);
    } on ApiError catch (e) {
      // 3. Nếu lỗi mạng, hoàn tác lại trạng thái chưa đọc
      notifications[idx] = notifications[idx].copyWith(isRead: false);
      SnackbarHelper.error(e.message);
    }
  }

  Future<void> deleteNotification(int id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx < 0) return;

    // Lưu lại item phòng khi xóa lỗi
    final backupItem = notifications[idx];

    // 1. Cập nhật UI ngay lập tức
    notifications.removeAt(idx);

    // 2. Gọi API
    try {
      await _service.deleteNotification(id);
    } on ApiError catch (e) {
      // 3. Khôi phục nếu lỗi
      notifications.insert(idx, backupItem);
      SnackbarHelper.error(e.message);
    }
  }
}
