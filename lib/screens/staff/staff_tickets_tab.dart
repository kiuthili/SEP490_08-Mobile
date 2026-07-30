import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/screens/staff/staff_ticket_detail_screen.dart';
import '../../controllers/staff_controller.dart';
import '../../widgets/staff_schedule_list.dart';

class StaffTicketsTab extends GetView<StaffController> {
  const StaffTicketsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('st_schedule_tickets'.tr)),
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
