import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/staff_controller.dart';
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
          children: [
            _CustomersTab(
                controller: controller, scheduleId: widget.scheduleId),
            _MapTab(controller: controller),
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
  const _MapTab({required this.controller});
  final StaffController controller;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  mb.MapboxMap? _mapboxMap;
  mb.PointAnnotationManager? _pointAnnotationManager;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final locs = widget.controller.liveLocations;
      final centerLng = locs.isNotEmpty ? locs.first.longitude : 108.206230;
      final centerLat = locs.isNotEmpty ? locs.first.latitude : 16.047079;

      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 1 || constraints.maxWidth < 1) {
            return const SizedBox.shrink();
          }
          return mb.MapWidget(
            cameraOptions: mb.CameraOptions(
              center: mb.Point(coordinates: mb.Position(centerLng, centerLat)),
              zoom: 14,
            ),
            styleUri: mb.MapboxStyles.STANDARD,
            onMapCreated: (map) async {
              _mapboxMap = map;
              _pointAnnotationManager = await map.annotations.createPointAnnotationManager();
            },
          );
        },
      );
    });
  }
}

class _LiveLocationMarker extends StatefulWidget {
  const _LiveLocationMarker({required this.location});
  final dynamic location;

  @override
  State<_LiveLocationMarker> createState() => _LiveLocationMarkerState();
}

class _LiveLocationMarkerState extends State<_LiveLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? get _avatar {
    try {
      final v = widget.location.avatarUrl;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  String get _name {
    final n = widget.location.fullName as String?;
    if (n != null && n.isNotEmpty) return n;
    return '#${widget.location.userId}';
  }

  bool get _isStaff {
    try {
      return widget.location.role.toLowerCase() == 'staff';
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar;
    final isStaff = _isStaff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isStaff)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.success, width: 1),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 2),
              ],
            ),
            child: const Text(
              'STAFF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final t = _ctrl.value;
                  return Container(
                    width: 24 + 26 * t,
                    height: 24 + 26 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isStaff ? AppColors.success : AppColors.brand)
                          .withValues(alpha: (1 - t) * 0.35),
                    ),
                  );
                },
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStaff ? AppColors.success : AppColors.brand,
                  border: Border.all(
                    color: isStaff ? AppColors.success : Colors.white,
                    width: 2.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: avatar != null
                    ? CachedNetworkImage(
                        imageUrl: avatar,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person, size: 18, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            _name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
