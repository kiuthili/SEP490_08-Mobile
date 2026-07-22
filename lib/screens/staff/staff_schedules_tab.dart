import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/feature_controllers.dart';
import '../../controllers/social_controller.dart';
import '../../controllers/staff_controller.dart';
import '../../controllers/shell_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_radius.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/loading_widget.dart';

const _kTicketsTabIndex = 1;
const _kCustomersTabIndex = 3;
const _kCheckInTabIndex = 2;

class StaffSchedulesTab extends GetView<StaffController> {
  const StaffSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final socialController = Get.find<SocialController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Lịch trình được giao'),
        actions: [
          Obx(() {
            final unreadChatCount = socialController.unreadChatCount;
            return Badge(
              label: Text(
                unreadChatCount > 99 ? '99+' : unreadChatCount.toString(),
              ),
              isLabelVisible: unreadChatCount > 0,
              child: IconButton(
                tooltip: 'Hộp thư',
                icon: const Icon(Icons.forum_outlined),
                onPressed: () => Get.toNamed(AppRoutes.chatInbox),
              ),
            );
          }),
          const SizedBox(width: 16),
        ],
      ),
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
        color: selected ? AppColors.brandLight.withValues(alpha: 0.3) : AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.border,
          width: selected ? 1.5 : 1.0,
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

                        ],
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 24),
                    ]
                  ],
                ),
              ),

              // ── Action buttons ───
              Divider(
                height: 1,
                color: AppColors.border,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.qr_code_scanner_rounded,
                        isPrimary: true,
                        onTap: () {
                           Get.find<StaffController>().selectSchedule(schedule.scheduleId);
                           Get.find<ShellController>().changeTab(_kCheckInTabIndex);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.confirmation_number_rounded,
                        onTap: () {
                           Get.find<StaffController>().selectSchedule(schedule.scheduleId);
                           Get.find<ShellController>().changeTab(_kTicketsTabIndex);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.people_alt_rounded,
                        onTap: () {
                           Get.find<StaffController>().selectSchedule(schedule.scheduleId);
                           Get.find<ShellController>().changeTab(_kCustomersTabIndex);
                        },
                      ),
                    ),
                  ],
                ),
              ),
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
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

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
            color: isPrimary ? AppColors.brand : AppColors.brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isPrimary ? AppColors.brand : AppColors.brand.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isPrimary ? Colors.white : AppColors.brand),
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
