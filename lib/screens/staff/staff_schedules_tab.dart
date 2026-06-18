import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/staff_controller.dart';
import '../../controllers/shell_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_radius.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/loading_widget.dart';

const _kTicketsTabIndex = 2;
const _kCustomersTabIndex = 3;

class StaffSchedulesTab extends GetView<StaffController> {
  const StaffSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Lịch trình được giao')),
      body: Column(
        children: [
          _FilterBar(controller: controller),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.fetchAssignedSchedules,
              child: Obx(() {
                if (controller.isLoading.value &&
                    controller.schedules.isEmpty) {
                  return const LoadingWidget();
                }
                if (controller.schedules.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(
                        title: 'Chưa có lịch trình được giao',
                        subtitle:
                        'Các lịch trình sẽ hiển thị khi được phân công',
                      ),
                    ],
                  );
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification &&
                        notification.metrics.extentAfter < 200) {
                      controller.loadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16).copyWith(
                      bottom: ShellLayout.bottomInset(context),
                    ),
                    itemCount: controller.schedules.length +
                        (controller.isLoadingMore.value ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == controller.schedules.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final s = controller.schedules[index];

                      // ── Mỗi card tự reactive với selectedScheduleId ──
                      return Obx(() {
                        final selected =
                            controller.selectedScheduleId.value == s.scheduleId;
                        return _ScheduleCard(
                          key: ValueKey(s.scheduleId),
                          schedule: s,
                          selected: selected,
                          onTap: () => controller.selectSchedule(s.scheduleId),
                        );
                      });
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ───────────────────────────────────────────────────────────────

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
              hintText: 'Tìm theo tên tour...',
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
              contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.border),
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
                'Chỉ hiện lịch sắp tới',
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

// ── Schedule card ─────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    super.key,
    required this.schedule,
    required this.selected,
    required this.onTap,
  });

  final dynamic schedule;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandLight : AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.border,
          width: selected ? 1.5 : 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Main info ─────────────────────────────────
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
                              Icon(Icons.calendar_today_rounded,
                                  size: 13,
                                  color: AppColors.textSecondary),
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
                          if (schedule.assignedRole != null) ...[
                            const SizedBox(height: 6),
                            _RoleBadge(role: schedule.assignedRole!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Selected indicator
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? AppColors.brand
                              : AppColors.border,
                          size: 22,
                        ),
                        if (!selected) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Chọn',
                            style: AppTextStyles.textTheme.labelSmall
                                ?.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Action buttons (chỉ hiện khi selected) ───
              if (selected) ...[
                Divider(
                  height: 1,
                  color: AppColors.brand.withValues(alpha: 0.2),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Xem vé',
                          onTap: () => Get.find<ShellController>()
                              .changeTab(_kTicketsTabIndex),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.people_alt_rounded,
                          label: 'Xem khách',
                          onTap: () => Get.find<ShellController>()
                              .changeTab(_kCustomersTabIndex),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.textTheme.labelMedium?.copyWith(
                  color: AppColors.brand,
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

// ── Tour thumbnail ────────────────────────────────────────────────────────────

class _TourThumbnail extends StatelessWidget {
  const _TourThumbnail({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
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

// ── Role badge ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_rounded, size: 12, color: AppColors.brand),
          const SizedBox(width: 4),
          Text(
            role,
            style: AppTextStyles.textTheme.labelSmall?.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}