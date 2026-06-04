import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class StaffSchedulesTab extends GetView<StaffController> {
  const StaffSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Lịch trình được giao')),
      body: RefreshIndicator(
        onRefresh: controller.fetchAssignedSchedules,
        child: Obx(() {
          if (controller.isLoading.value && controller.schedules.isEmpty) {
            return const LoadingWidget();
          }
          if (controller.schedules.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                EmptyStateWidget(title: 'Chưa có lịch trình được giao'),
              ],
            );
          }

          final selectedId = controller.selectedScheduleId.value;

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16).copyWith(
              bottom: ShellLayout.bottomInset(context),
            ),
            itemCount: controller.schedules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = controller.schedules[index];
              final selected = selectedId == s.scheduleId;
              return IosPickRow(
                key: ValueKey('staff-schedule-${s.scheduleId}'),
                selected: selected,
                onTap: () => controller.selectSchedule(s.scheduleId),
                leading: s.tourImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          s.tourImageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.tour_rounded),
                title: Text(s.tourName ?? 'Tour #${s.tourId}'),
                subtitle: Text(
                  '${DateFormatter.formatDate(s.departureDate)} → ${DateFormatter.formatDate(s.returnDate)}',
                ),
                trailing: Text(s.assignedRole ?? 'Staff'),
              );
            },
          );
        }),
      ),
    );
  }
}
