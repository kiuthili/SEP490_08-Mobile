import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import 'package:stayhub_mobile/theme/app_colors.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';
import 'package:stayhub_mobile/widgets/app_screen.dart';
import 'package:stayhub_mobile/widgets/empty_state_widget.dart';
import 'package:stayhub_mobile/widgets/loading_widget.dart';
import 'package:stayhub_mobile/widgets/section_header.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends GetView<NotificationController> {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.fetchNotifications,
                color: AppColors.brand,
                child: Obx(() {
                  if (controller.isLoading.value && controller.notifications.isEmpty) {
                    return const Center(child: LoadingWidget(message: 'Đang tải...'));
                  }

                  if (controller.notifications.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 100),
                        EmptyStateWidget(
                          title: 'Thông báo trống',
                          subtitle: 'Chúng tôi sẽ báo cho bạn khi có tin mới',
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: controller.notifications.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const SectionHeader(
                          title: 'Gần đây',
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                        );
                      }

                      final n = controller.notifications[index - 1];
                      return _NotificationCard(
                        key: ValueKey(n.id),
                        notification: n,
                        onRead: () => controller.markRead(n.id),
                        onDelete: () => controller.deleteNotification(n.id),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 10, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF05073C), Color(0xFF0048B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              const Expanded(
                child: Text(
                  'Thông báo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Badge số lượng chưa đọc kết hợp icon chuông
              SizedBox(
                width: 48,
                child: Obx(() {
                  final count = controller.unreadCount;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Badge(
                      label: Text(count > 99 ? '99+' : '$count'),
                      isLabelVisible: count > 0,
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      largeSize: 18,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          count > 0
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.notification,
    required this.onRead,
    required this.onDelete,
  });

  final dynamic notification; // NotificationModel
  final VoidCallback onRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isRead = notification.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        // Đã đọc thì nền trong suốt, Chưa đọc thì nền trắng
        color: isRead ? Colors.white.withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // Chưa đọc thì nổi bóng lên, đã đọc thì phẳng
        boxShadow: isRead
            ? []
            : [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isRead ? Colors.transparent : AppColors.brand.withValues(alpha: 0.15),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: isRead ? null : onRead,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon (Bỏ hình tròn, thêm dấu chấm đỏ nếu chưa đọc)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                        color: isRead ? AppColors.textTertiary : AppColors.brand,
                        size: 26,
                      ),
                      if (!isRead)
                        Positioned(
                          top: 0,
                          right: 2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Nội dung chính
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                          fontSize: 15,
                          color: isRead ? AppColors.textSecondary : AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Lời nhắn
                      Text(
                        notification.message ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: isRead ? AppColors.textTertiary : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Ngày giờ sắp xếp lại xuống dưới cùng có icon đồng hồ
                      if (notification.createdAt != null)
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: AppColors.textTertiary.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('HH:mm - dd/MM/yyyy').format(notification.createdAt!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Nút X (Xóa)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}