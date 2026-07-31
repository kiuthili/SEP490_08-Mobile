import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/staff_controller.dart';
import '../../widgets/staff_schedule_list.dart';

class StaffSchedulesTab extends GetView<StaffController> {
  const StaffSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('st_assigned_schedules'.tr),
      ),
      body: const StaffScheduleList(),
    );
  }
}
