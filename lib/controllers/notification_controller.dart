import 'package:get/get.dart';
import 'package:stayhub_mobile/models/api_response.dart';
import 'package:stayhub_mobile/models/notification_model.dart';
import 'package:stayhub_mobile/services/notification_service.dart';
import 'package:stayhub_mobile/utils/snackbar_helper.dart';

class NotificationController extends GetxController {
  final _service = Get.find<NotificationService>();
  final notifications = <NotificationModel>[].obs;
  final isLoading = false.obs;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    isLoading.value = true;
    try {
      notifications.assignAll(await _service.getNotifications());
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
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