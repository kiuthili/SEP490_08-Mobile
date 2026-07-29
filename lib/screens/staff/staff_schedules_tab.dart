import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/feature_controllers.dart';
import '../../controllers/staff_controller.dart';
import '../../routes/app_routes.dart';
import '../../widgets/language_bottom_sheet.dart';
import '../../widgets/staff_schedule_list.dart';

class StaffSchedulesTab extends GetView<StaffController> {
  const StaffSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final socialController = Get.find<SocialController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('st_assigned_schedules'.tr),
        actions: [
          Obx(() {
            final unreadChatCount = socialController.unreadChatCount;
            return Badge(
              label: Text(
                unreadChatCount > 99 ? '99+' : unreadChatCount.toString(),
              ),
              isLabelVisible: unreadChatCount > 0,
              child: IconButton(
                tooltip: 'st_inbox'.tr,
                icon: const Icon(Icons.forum_outlined),
                onPressed: () => Get.toNamed(AppRoutes.chatInbox),
              ),
            );
          }),
          IconButton(
            tooltip: 'choose_language'.tr,
            icon: const Icon(Icons.language_rounded),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => LanguageBottomSheet(
                  selected: Get.locale?.languageCode ?? 'vi',
                  onSelect: (lang) {
                    if (lang == 'vi') {
                      Get.updateLocale(const Locale('vi', 'VN'));
                    } else {
                      Get.updateLocale(const Locale('en', 'US'));
                    }
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const StaffScheduleList(),
    );
  }
}
