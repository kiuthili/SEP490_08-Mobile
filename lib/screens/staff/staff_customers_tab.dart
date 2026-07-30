import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/screens/staff/staff_customer_detail_screen.dart';
import '../../controllers/staff_controller.dart';
import '../../widgets/staff_schedule_list.dart';

class StaffCustomersTab extends GetView<StaffController> {
  const StaffCustomersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('st_customers_and_location'.tr)),
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
