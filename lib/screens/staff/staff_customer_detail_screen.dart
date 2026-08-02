import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/staff_controller.dart';
import '../../controllers/staff_map_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../constants/api_constants.dart';
import '../../widgets/empty_state_widget.dart';

class StaffCustomerDetailScreen extends StatefulWidget {
  const StaffCustomerDetailScreen({super.key, required this.scheduleId});
  final int scheduleId;

  @override
  State<StaffCustomerDetailScreen> createState() =>
      _StaffCustomerDetailScreenState();
}

class _StaffCustomerDetailScreenState extends State<StaffCustomerDetailScreen> {
  late final StaffController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<StaffController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchCustomers(widget.scheduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('st_customers_and_location'.tr),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Get.back(),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: 'st_customer_list'.tr),
              Tab(text: 'st_location_map'.tr),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _CustomersTab(
                controller: controller, scheduleId: widget.scheduleId),
            _MapTab(scheduleId: widget.scheduleId),
          ],
        ),
      ),
    );
  }
}

// ── Customers tab ─────────────────────────────────────────────────────────────

class _CustomersTab extends StatefulWidget {
  const _CustomersTab({required this.controller, required this.scheduleId});
  final StaffController controller;
  final int scheduleId;

  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search bar ────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) {
              widget.controller.applyCustomerFilter(widget.scheduleId, v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'st_search_passenger_name'.tr,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        widget.controller
                            .applyCustomerFilter(widget.scheduleId, '');
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
        ),

        // ── List ──────────────────────────────────────────────
        Expanded(
          child: Obx(() {
            if (widget.controller.customers.isEmpty) {
              return EmptyStateWidget(
                title: 'st_no_customers'.tr,
                subtitle: 'st_select_schedule_in_calendar'.tr,
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: widget.controller.customers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _CustomerCard(
                  customer: widget.controller.customers[index],
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

// ── Customer card ─────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});
  final dynamic customer;

  @override
  Widget build(BuildContext context) {
    final name = (customer.displayName as String?)?.trim() ?? 'Khách';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final phone = customer.phoneNumber as String?;
    final gender = customer.genderLabel as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.brandLight,
            child: Text(
              initial,
              style: AppTextStyles.textTheme.titleMedium?.copyWith(
                color: AppColors.brandDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            name,
            style: AppTextStyles.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _SmallPill(
                  icon: Icons.confirmation_number_rounded,
                  label: '#${customer.ticketId}',
                  color: AppColors.brand,
                  bgColor: AppColors.brandLight,
                ),
                if (gender != null && gender.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _SmallPill(
                    icon: Icons.person_rounded,
                    label: gender,
                    color: AppColors.textSecondary,
                    bgColor: AppColors.surfaceGrouped,
                  ),
                ]
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceGrouped,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                children: [
                  if (phone != null && phone.isNotEmpty)
                    _InfoRow(
                        icon: Icons.phone_rounded,
                        label: 'st_phone'.tr,
                        value: phone),
                  _InfoRow(
                      icon: Icons.badge_rounded,
                      label: 'st_id_passport'.tr,
                      value: (customer.idCard as String?)?.isNotEmpty == true
                          ? customer.idCard!
                          : '—'),
                  if (customer.dateOfBirth != null &&
                      (customer.dateOfBirth as String).isNotEmpty)
                    _InfoRow(
                        icon: Icons.cake_rounded,
                        label: 'st_dob'.tr,
                        value: customer.dateOfBirth as String),
                  if (customer.nationality != null &&
                      (customer.nationality as String).isNotEmpty)
                    _InfoRow(
                        icon: Icons.flag_rounded,
                        label: 'st_nationality'.tr,
                        value: customer.nationality as String,
                        isLast: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: AppTextStyles.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map tab ───────────────────────────────────────────────────────────────────

class _MapTab extends StatefulWidget {
  const _MapTab({required this.scheduleId});
  final int scheduleId;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  late StaffMapController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(StaffMapController(), tag: 'staff_map_${widget.scheduleId}');
    c.initMap(widget.scheduleId);
  }

  @override
  void dispose() {
    Get.delete<StaffMapController>(tag: 'staff_map_${widget.scheduleId}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value && c.liveLocations.isEmpty && c.routeDays.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return Stack(
        children: [
          mb.MapWidget(
            key: ValueKey("staffMapWidget_${widget.scheduleId}"),
            onMapCreated: c.onMapCreated,
            onStyleLoadedListener: c.onStyleLoaded,
            onTapListener: c.handleMapTap,
            styleUri: mb.MapboxStyles.MAPBOX_STREETS,
          ),
          
          // Day Selector Overlay
          if (c.showRoute.value && c.routeDays.isNotEmpty)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Container(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: c.routeDays.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final bool isOverview = i == 0;
                    final bool selected = isOverview
                        ? c.selectedDay.value == null
                        : c.selectedDay.value == c.routeDays[i - 1].dayNumber;
                    final String label = isOverview ? 'Overview' : 'Day ${c.routeDays[i - 1].dayNumber}';

                    return GestureDetector(
                      onTap: () {
                        if (isOverview) {
                          c.selectDay(null);
                        } else {
                          c.selectDay(c.routeDays[i - 1].dayNumber);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.brand : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          
          // Map controls overlay
          Positioned(
            right: 12,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'staff_recenter_${widget.scheduleId}',
                  backgroundColor: Colors.white,
                  onPressed: c.recenter,
                  child: const Icon(Icons.my_location_rounded, color: AppColors.brand),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: AppColors.brand),
                        onPressed: c.zoomIn,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      Container(height: 1, width: 24, color: Colors.grey.shade200),
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, color: AppColors.brand),
                        onPressed: c.zoomOut,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      Container(height: 1, width: 24, color: Colors.grey.shade200),
                      IconButton(
                        icon: Icon(
                          c.showRoute.value ? Icons.route_rounded : Icons.route_outlined,
                          color: c.showRoute.value ? AppColors.brand : Colors.black54,
                        ),
                        onPressed: () => c.showRoute.toggle(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      Container(height: 1, width: 24, color: Colors.grey.shade200),
                      IconButton(
                        icon: Icon(
                          c.showMoments.value ? Icons.photo_library_rounded : Icons.photo_library_outlined,
                          color: c.showMoments.value ? AppColors.brand : Colors.black54,
                        ),
                        onPressed: () => c.showMoments.toggle(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

