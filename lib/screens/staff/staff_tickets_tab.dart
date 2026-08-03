import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/screens/staff/staff_ticket_detail_screen.dart';
import '../../controllers/staff_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/staff_schedule_list.dart';

class StaffTicketsTab extends GetView<StaffController> {
  const StaffTicketsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('st_schedule_tickets'.tr),
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
      body: StaffScheduleList(
        actionBuilder: (context, schedule) => StaffActionButton(
          label: 'st_view_ticket'.tr,
          icon: Icons.confirmation_number_rounded,
          onTap: () {
            Get.to(
                () => StaffTicketDetailScreen(scheduleId: schedule.scheduleId));
          },
        ),
      ),
    );
  }
}
