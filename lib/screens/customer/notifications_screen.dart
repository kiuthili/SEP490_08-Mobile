import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class NotificationsScreen extends GetView<NotificationController> {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Thông báo',
      body: RefreshIndicator(
        onRefresh: controller.fetchNotifications,
        child: Obx(() {
          if (controller.isLoading.value &&
              controller.notifications.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                LoadingWidget(message: 'Đang tải thông báo...'),
              ],
            );
          }
          if (controller.notifications.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                EmptyStateWidget(title: 'Không có thông báo'),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: controller.notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final n = controller.notifications[index];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => controller.deleteNotification(n.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                child: IosSurfaceCard(
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(
                      n.isRead
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                      color: n.isRead ? AppColors.textSecondary : AppColors.brand,
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight:
                            n.isRead ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                    subtitle: n.message != null ? Text(n.message!) : null,
                    onTap: () {
                      if (!n.isRead) controller.markRead(n.id);
                    },
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
