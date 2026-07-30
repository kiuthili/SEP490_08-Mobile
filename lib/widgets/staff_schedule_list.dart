import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/staff_controller.dart';
import '../models/assigned_schedule_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../theme/shell_layout.dart';
import '../utils/date_formatter.dart';
import 'empty_state_widget.dart';

class StaffScheduleList extends StatelessWidget {
  const StaffScheduleList({
    super.key,
    this.actionBuilder,
    this.onScheduleTap,
  });

  /// Builder for custom action buttons below the schedule info
  final Widget Function(BuildContext, AssignedScheduleModel)? actionBuilder;
  
  /// Callback when the schedule card itself is tapped
  final void Function(AssignedScheduleModel)? onScheduleTap;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffController>();

    return Column(
      children: [
        _FilterBar(controller: controller),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value && controller.schedules.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.schedules.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  EmptyStateWidget(
                    title: 'st_no_assigned_schedules'.tr,
                    subtitle: 'st_schedules_will_appear'.tr,
                  ),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: () => controller.fetchAssignedSchedules(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (!controller.isLoadingMore.value &&
                      scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 200) {
                    controller.loadMore();
                  }
                  return false;
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16).copyWith(
                    bottom: ShellLayout.bottomInset(context) + 32,
                  ),
                  itemCount: controller.schedules.length +
                      (controller.isLoadingMore.value ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == controller.schedules.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                            child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )),
                      );
                    }
                    final schedule = controller.schedules[index];
                    return _ScheduleCard(
                      schedule: schedule,
                      onTap: () => onScheduleTap?.call(schedule),
                      action: actionBuilder != null
                          ? actionBuilder!(context, schedule)
                          : null,
                    );
                  },
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}


class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.controller});
  final StaffController controller;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final _searchController = TextEditingController();
  bool _upcomingOnly = false;

  @override
  void initState() {
    super.initState();
    _upcomingOnly = widget.controller.upcomingOnly.value;
    _searchController.text = widget.controller.searchQuery.value;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) {
              widget.controller.applySearch(v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'st_search_tour_name'.tr,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        widget.controller.applySearch('');
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppColors.brand, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.event_available_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'st_upcoming_only'.tr,
                style: AppTextStyles.textTheme.bodySmall,
              ),
              const Spacer(),
              Switch.adaptive(
                value: _upcomingOnly,
                onChanged: (v) {
                  setState(() => _upcomingOnly = v);
                  widget.controller.setUpcomingOnly(v);
                },
                activeColor: AppColors.brand,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onTap,
    this.action,
  });

  final AssignedScheduleModel schedule;
  final VoidCallback onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _TourThumbnail(imageUrl: schedule.tourImageUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.tourName ?? 'Tour #${schedule.tourId}',
                            style: AppTextStyles.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${DateFormatter.display(schedule.departureDate)}'
                                  ' → ${DateFormatter.display(schedule.returnDate)}',
                                  style: AppTextStyles.textTheme.bodySmall
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: action!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TourThumbnail extends StatelessWidget {
  const _TourThumbnail({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: 52,
        height: 52,
        child: imageUrl != null && imageUrl!.trim().isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.brandLight,
        child: const Center(
          child: Icon(Icons.tour_rounded, color: AppColors.brand, size: 24),
        ),
      );
}

class StaffActionButton extends StatelessWidget {
  const StaffActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.brand
                : AppColors.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(100),
            border: isPrimary
                ? null
                : Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18, color: isPrimary ? Colors.white : AppColors.brand),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
