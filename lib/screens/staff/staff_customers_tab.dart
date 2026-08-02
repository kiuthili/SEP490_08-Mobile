import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/screens/staff/staff_customer_detail_screen.dart';
import '../../controllers/staff_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/staff_schedule_list.dart';

class StaffCustomersTab extends GetView<StaffController> {
  const StaffCustomersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('nav_customers'.tr),
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
          label: 'st_customer_list'.tr,
          icon: Icons.people_alt_rounded,
          onTap: () {
            Get.to(() =>
                StaffCustomerDetailScreen(scheduleId: schedule.scheduleId));
          },
        ),
      ),
    );
  }
}
