import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/staff_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/staff_schedule_list.dart';

class StaffSchedulesTab extends GetView<StaffController> {
  const StaffSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('st_assigned_schedules'.tr),
        actions: [
          Obx(() {
            if (!Get.isRegistered<NotificationController>()) return const SizedBox.shrink();
            final notifController = Get.find<NotificationController>();
            final unread = notifController.unreadCount;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: () => Get.toNamed(AppRoutes.notifications),
                icon: Badge(
                  label: Text(unread > 99 ? '99+' : unread.toString()),
                  isLabelVisible: unread > 0,
                  backgroundColor: AppColors.error,
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            );
          }),
        ],
      ),
      body: const StaffScheduleList(),
    );
  }
}
