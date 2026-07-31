// lib/screens/social/social_map_screen.dart
//
// Màn hình Bản đồ Social dùng flutter_map, kết hợp 5 lớp:
//   - TileLayer (nền OSM) + RichAttributionWidget (tuân thủ điều khoản OSM)
//   - HeatMapLayer  (bản đồ nhiệt, plugin flutter_map_heatmap)
//   - CircleLayer   (footprints / "cào map")
//   - PolylineLayer + MarkerLayer (lộ trình tour theo ngày)
//   - MarkerLayer   (moments ảnh + live location bạn bè/người cùng tour)
//
// State được quản lý hoàn toàn ở SocialMapController, bind bằng Obx.
//
// ✦ Bản nâng cấp (UI/UX + hiệu năng):
//   - onMapReady wiring => không còn fitCamera trước khi map mount.
//   - Live marker có hiệu ứng "pulse" mượt, avatar an toàn (fallback).
//   - Panel layer kiểu kính mờ (glassmorphism), nút điều khiển map (recenter/zoom).
//   - RepaintBoundary cho marker để giảm repaint toàn cây.
//   - FAB gradient, micro-interaction tinh tế.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'package:get/get.dart';

import '../../constants/api_constants.dart';
import '../../controllers/social_map_controller.dart';
import '../../models/map_models.dart';
import '../../models/social_models.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/loading_widget.dart';
import 'package:stayhub_mobile/theme/app_colors.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

// Bảng màu thương hiệu (đồng bộ với web: brand #0068E0).
const Color _kBrand = AppColors.brand;
const Color _kBrandDark = Color(0xFF0050B3);

class SocialMapScreen extends StatefulWidget {
  const SocialMapScreen({super.key});

  @override
  State<SocialMapScreen> createState() => _SocialMapScreenState();
}

class _SocialMapScreenState extends State<SocialMapScreen> {
  late SocialMapController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(SocialMapController());
    c.isMapReady.value = false;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Social Map',
      actions: [
        IconButton(
          tooltip: 'Share my location link',
          icon: const Icon(Icons.share_location_rounded),
          onPressed: () => _showShareLinkDialog(c),
        ),
        Obx(
          () => IconButton(
            tooltip: c.isSharingLocation.value
                ? 'Sharing location - tap to stop'
                : 'Share my location',
            icon: Icon(
              c.isSharingLocation.value
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              color: c.isSharingLocation.value ? AppColors.error : null,
            ),
            onPressed: c.toggleShareMyLocation,
          ),
        ),
      ],
      body: Obx(() {
        if (c.isLoading.value && c.liveLocations.isEmpty) {
          return const LoadingWidget(message: 'Loading map...');
        }
        return Stack(
          children: [
            _MapView(c: c),

            // ---- Overlay trên cùng: chọn lịch trình + chọn ngày ----
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  _ScheduleSelectorBar(c: c),
                  _DaySelectorBar(c: c),
                ],
              ),
            ),

            // ---- Overlay phải: control + layer toggle ----
            Obx(() => Positioned(
                  right: 12,
                  bottom: c.showTimeline.value ? 450 : 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MapControls(c: c),
                    ],
                  ),
                )),

            // ---- Overlay trái: chú thích Heatmap ----
            Obx(() => Positioned(
                  left: 12,
                  bottom: c.showTimeline.value ? 450 : 100,
                  child: _HeatmapLegend(c: c),
                )),

            // ---- Nút Chụp & đăng Moment (giữa dưới) ----
            Obx(() => c.showTimeline.value
                ? const SizedBox.shrink()
                : Positioned(
                    left: 0,
                    right: 0,
                    bottom: 104,
                    child: Center(child: _CaptureMomentButton(c: c)),
                  )),

            // ---- Overlay dưới cùng: Dòng thời gian hành trình ----
            Obx(() => c.showTimeline.value
                ? Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 90,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _TimelinePanel(c: c),
                    ),
                  )
                : const SizedBox.shrink()),

            // ---- Thanh tiến trình mảnh khi đang tải nền ----
            Obx(
              () => c.isLoading.value
                  ? const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(_kBrand),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      }),
    );
  }
}

// ============================================================
// SHARE LINK DIALOG
// ============================================================
Future<void> _showShareLinkDialog(SocialMapController c) async {
  final token = await c.generateShareLink();
  if (token == null) return;
  // Đổi domain cho khớp web của bạn.
  final url = '${ApiConstants.webUrl}/track/$token';
  await Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Row(
        children: [
          Icon(Icons.share_location_rounded, color: _kBrand),
          SizedBox(width: 8),
          Expanded(child: Text('Share my location')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send this link to your friends or family to let them track your live location on the map:',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kBrand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: _kBrand.withValues(alpha: 0.25)),
            ),
            child: SelectableText(
              url,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _kBrandDark,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Close')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _kBrand),
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            Get.back();
            HapticFeedback.lightImpact();
          },
        ),
      ],
    ),
  );
}

// ============================================================
// BẢN ĐỒ + CÁC LAYER
// ============================================================
class _MapView extends StatelessWidget {
  const _MapView({required this.c});
  final SocialMapController c;

  @override
  Widget build(BuildContext context) {
    // Dynamic Lighting based on system theme
    final brightness = MediaQuery.of(context).platformBrightness;

    final styleUri = brightness == Brightness.dark
        ? mb.MapboxStyles.DARK
        : mb.MapboxStyles.STANDARD;

    return mb.MapWidget(
      styleUri: styleUri,
      onStyleLoadedListener: c.onStyleLoaded,
      onMapCreated: c.onMapCreated,
      cameraOptions: mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(108.206230, 16.047079)),
        zoom: 6.0,
      ),
      onCameraChangeListener: (event) {
        c.cameraUpdateStream.add(null);
        c.mapboxMap?.getCameraState().then((state) {
          c.updateZoom(state.zoom);
        });
      },
      onTapListener: (context) {
        c.handleMapTap(context);
      },
    );
  }
}

class _MomentMarker extends StatelessWidget {
  const _MomentMarker({required this.moment});
  final MomentModel moment;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Get.toNamed(AppRoutes.momentDetail, arguments: moment);
      },
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kBrand, Color(0xFF34C3FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2.5),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: moment.imageUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, __) => Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.image, size: 20, color: Colors.white),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey.shade400,
              child:
                  const Icon(Icons.broken_image, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marker vị trí realtime của người dùng (avatar + tên) với hiệu ứng pulse.
class _LiveLocationMarker extends StatefulWidget {
  const _LiveLocationMarker({required this.location});
  final dynamic location; // LiveLocationModel

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

  /// Đọc avatarUrl an toàn (model có thể không có field này).
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
              color: AppColors.success, // Emerald 600
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border:
                  Border.all(color: AppColors.success, width: 1), // Emerald 400
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
              // Vòng pulse mở rộng dần.
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final t = _ctrl.value;
                  return Container(
                    width: 24 + 26 * t,
                    height: 24 + 26 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isStaff ? AppColors.success : _kBrand)
                          .withValues(alpha: (1 - t) * 0.35),
                    ),
                  );
                },
              ),
              // Avatar / icon trung tâm.
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStaff ? AppColors.success : _kBrand,
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

/// Pin điểm đến trong lộ trình (có số thứ tự).
class _RoutePin extends StatelessWidget {
  const _RoutePin({required this.point, required this.order});
  final RoutePointModel point;
  final int order;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.place, color: _kBrand, size: 32),
            Positioned(
              top: 3,
              child: Text(
                '$order',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (point.name.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3),
              ],
            ),
            child: Text(
              point.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: _kBrandDark,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// OVERLAY UI WIDGETS
// ============================================================

/// Thanh chọn lịch trình tour (Pill Dropdown).
class _ScheduleSelectorBar extends StatelessWidget {
  const _ScheduleSelectorBar({required this.c});
  final SocialMapController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.eligibleSchedules.isEmpty) return const SizedBox.shrink();

      final selectedSchedule = c.eligibleSchedules
          .firstWhereOrNull((s) => s.scheduleId == c.selectedScheduleId.value);
      final label = c.selectedScheduleId.value == 0
          ? 'All Trips'
          : (selectedSchedule?.tourName ?? 'All Trips');

      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _showTourSelector(context, c);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tour_rounded, size: 18, color: _kBrand),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.5),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: Colors.black54),
            ],
          ),
        ),
      );
    });
  }
}

void _showTourSelector(BuildContext context, SocialMapController c) {
  Get.bottomSheet(
    Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Tour',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // All Trips Option
                Obx(() {
                  final isAllTrips = c.selectedScheduleId.value == 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isAllTrips ? _kBrand : Colors.grey.shade200,
                      child: Icon(Icons.public_rounded,
                          color: isAllTrips ? Colors.white : Colors.black54,
                          size: 20),
                    ),
                    title: Text(
                      'All Trips',
                      style: TextStyle(
                        fontWeight:
                            isAllTrips ? FontWeight.bold : FontWeight.normal,
                        color: isAllTrips ? _kBrand : Colors.black87,
                      ),
                    ),
                    trailing: isAllTrips
                        ? const Icon(Icons.check_circle_rounded, color: _kBrand)
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      c.selectSchedule(0);
                      Get.back();
                    },
                  );
                }),

                // Real Schedules
                ...c.eligibleSchedules.map((s) {
                  return Obx(() {
                    final selected = c.selectedScheduleId.value == s.scheduleId;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            selected ? _kBrand : Colors.grey.shade200,
                        child: Icon(Icons.tour_rounded,
                            color: selected ? Colors.white : Colors.black54,
                            size: 20),
                      ),
                      title: Text(
                        s.tourName,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? _kBrand : Colors.black87,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded,
                              color: _kBrand)
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        c.selectSchedule(s.scheduleId);
                        Get.back();
                      },
                    );
                  });
                }),
              ],
            ),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

/// Thanh chọn ngày của lộ trình (Day 1, Day 2 ...).
class _DaySelectorBar extends StatelessWidget {
  const _DaySelectorBar({required this.c});
  final SocialMapController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!c.showRoute.value || c.routeDays.isEmpty) {
        return const SizedBox.shrink();
      }
      final totalItems = c.routeDays.length + 1; // +1 for Overview (ALL)

      return Container(
        margin: const EdgeInsets.only(top: 8),
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: totalItems,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final bool isOverview = i == 0;
            final bool selected = isOverview
                ? c.selectedDay.value == null
                : c.selectedDay.value == c.routeDays[i - 1].dayNumber;

            final String label =
                isOverview ? 'Overview' : 'Day ${c.routeDays[i - 1].dayNumber}';

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (isOverview) {
                  c.selectDay(null);
                } else {
                  c.selectDay(c.routeDays[i - 1].dayNumber);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color:
                      selected ? _kBrand : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 3),
                  ],
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
      );
    });
  }
}

/// Nút điều khiển bản đồ: về vị trí của tôi, zoom in/out.
class _MapControls extends StatelessWidget {
  const _MapControls({required this.c});
  final SocialMapController c;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      color: Colors.white.withValues(alpha: 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CtrlBtn(
            icon: Icons.my_location_rounded,
            tooltip: 'Recenter',
            onTap: c.recenter,
          ),
          const _CtrlDivider(),
          _CtrlBtn(
            icon: Icons.route_outlined,
            tooltip: 'Fit to Route',
            onTap: c.fitToRoute,
          ),
          const _CtrlDivider(),
          _CtrlBtn(
            icon: Icons.layers_rounded,
            tooltip: 'Map Layers',
            onTap: () => _showLayersSheet(context, c),
          ),
          const _CtrlDivider(),
          Obx(() => _CtrlBtn(
                icon: Icons.history_rounded,
                tooltip: 'Journey Timeline',
                color: c.showTimeline.value ? _kBrand : null,
                onTap: () => c.showTimeline.toggle(),
              )),
          const _CtrlDivider(),
          _CtrlBtn(
            icon: Icons.add_rounded,
            tooltip: 'Zoom In',
            onTap: c.zoomIn,
          ),
          const _CtrlDivider(),
          _CtrlBtn(
            icon: Icons.remove_rounded,
            tooltip: 'Zoom Out',
            onTap: c.zoomOut,
          ),
        ],
      ),
    );
  }
}

class _CtrlDivider extends StatelessWidget {
  const _CtrlDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, width: 28, color: Colors.black12);
}

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: AppRadius.button,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 22, color: color ?? _kBrandDark),
        ),
      ),
    );
  }
}

void _showLayersSheet(BuildContext context, SocialMapController c) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Map Layers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              Obx(() => _LayerButton(
                    icon: Icons.people_alt_rounded,
                    label: 'Friends',
                    active: c.showLiveLocations.value,
                    onTap: c.showLiveLocations.toggle,
                  )),
              Obx(() => _LayerButton(
                    icon: c.showMoments.value
                        ? Icons.photo_library_rounded
                        : Icons.hide_image_rounded,
                    label: 'Moments',
                    active: c.showMoments.value,
                    onTap: c.showMoments.toggle,
                  )),
              Obx(() => _LayerButton(
                    icon: Icons.route_rounded,
                    label: 'Route',
                    active: c.showRoute.value,
                    onTap: c.showRoute.toggle,
                  )),
              Obx(() => _LayerButton(
                    icon: Icons.terrain_rounded,
                    label: 'Footprints',
                    active: c.showFootprints.value,
                    loading: c.isFootprintsLoading.value,
                    onTap: c.toggleFootprints,
                  )),
              Obx(() => _LayerButton(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Heatmap',
                    active: c.showHeatmap.value,
                    loading: c.isHeatmapLoading.value,
                    onTap: () {
                      c.toggleHeatmap();
                      if (c.showHeatmap.value) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Long press the Heatmap button for options'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      _showHeatmapSettings(context, c);
                    },
                  )),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

void _showHeatmapSettings(BuildContext context, SocialMapController c) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Heatmap Settings',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Data Source',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Obx(() => Row(
                  children: [
                    Expanded(child: _buildTypeOption(c, 'online', 'Online')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTypeOption(c, 'moments', 'Moments')),
                  ],
                )),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Radius & Intensity',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Obx(() => Text('${c.heatmapRadius.value.toInt()}',
                    style: const TextStyle(
                        color: _kBrand, fontWeight: FontWeight.bold))),
              ],
            ),
            Obx(() => Slider(
                  value: c.heatmapRadius.value,
                  min: 10,
                  max: 100,
                  activeColor: _kBrand,
                  inactiveColor: _kBrand.withValues(alpha: 0.2),
                  onChanged: (val) {
                    c.heatmapRadius.value = val;
                    c.loadHeatmap();
                  },
                )),
            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}

Widget _buildTypeOption(SocialMapController c, String type, String label) {
  final isSelected = c.heatmapType.value == type;
  return InkWell(
    onTap: () {
      c.heatmapType.value = type;
      c.loadHeatmap();
    },
    borderRadius: AppRadius.button,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color:
            isSelected ? _kBrand.withValues(alpha: 0.1) : Colors.grey.shade100,
        border: Border.all(color: isSelected ? _kBrand : Colors.transparent),
        borderRadius: AppRadius.button,
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
            color: isSelected ? _kBrand : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          )),
    ),
  );
}

class _LayerButton extends StatelessWidget {
  const _LayerButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onLongPress,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = active ? _kBrand : Colors.grey.shade500;
    return InkWell(
      borderRadius: AppRadius.button,
      onTap: loading
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      onLongPress: loading
          ? null
          : () {
              if (onLongPress != null) {
                HapticFeedback.heavyImpact();
                onLongPress!();
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 7),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: active ? _kBrand.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: AppRadius.button,
        ),
        child: Column(
          children: [
            loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_kBrand),
                    ),
                  )
                : Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chú thích thang màu cho Heatmap (hiển thị khi bật).
class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend({required this.c});
  final SocialMapController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!c.showHeatmap.value) return const SizedBox.shrink();
      return _Glass(
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: Colors.white.withValues(alpha: 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Density',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              width: 100,
              height: 8,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                gradient: LinearGradient(
                  colors: [
                    Colors.blue,
                    AppColors.success,
                    Colors.yellow,
                    AppColors.error
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Low', style: TextStyle(fontSize: 9)),
                Text('High', style: TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Nút nổi: mở camera để CHỤP & ĐĂNG moment ngay tại vị trí hiện tại,
/// sau khi đăng xong tự reload các moment trên bản đồ.
class _CaptureMomentButton extends StatelessWidget {
  const _CaptureMomentButton({required this.c});
  final SocialMapController c;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.button,
        onTap: () async {
          HapticFeedback.mediumImpact();
          await Get.toNamed(AppRoutes.shareMoment);
          await c.loadMapMoments(c.selectedScheduleId.value);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kBrand,
            boxShadow: [
              BoxShadow(
                color: _kBrand.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.camera_alt_rounded,
              color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Marker vị trí HIỆN TẠI của chính mình (chấm xanh lá, pulse) — đầu vệt cào map.
class _MeMarker extends StatefulWidget {
  const _MeMarker();

  @override
  State<_MeMarker> createState() => _MeMarkerState();
}

class _MeMarkerState extends State<_MeMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22C55E);
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            return Container(
              width: 22 + 34 * t,
              height: 22 + 34 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: green.withValues(alpha: (1 - t) * 0.35),
              ),
            );
          },
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: green,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SHARED: hộp kính mờ tái sử dụng
// ============================================================
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(8),
    this.color,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Panel Dòng thời gian hành trình (Timeline Panel) lật ảnh kiểu Polaroid giống Web
class _TimelinePanel extends StatefulWidget {
  const _TimelinePanel({required this.c});
  final SocialMapController c;

  @override
  State<_TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<_TimelinePanel> {
  int _currentIndex = 0;
  Timer? _timer;
  bool _isPlaying = false;

  // Smooth dragging physics states
  double _dragOffset = 0.0;
  double _targetOffset = 0.0;
  bool _isDragging = false;

  // Autoplay speed states (1x = 3.0s, 2x = 1.5s, 3x = 1.0s)
  int _playbackSpeed = 1;

  @override
  void initState() {
    super.initState();
    _moveCameraToCurrent();
  }

  void _moveCameraToCurrent() {
    final moments = widget.c.timelineMoments;
    if (moments.isNotEmpty && _currentIndex < moments.length) {
      final m = moments[_currentIndex];
      if (m.lat != null && m.lng != null) {
        if (widget.c.mapboxMap != null) {
          widget.c.mapboxMap!.flyTo(
            mb.CameraOptions(
              center: mb.Point(coordinates: mb.Position(m.lng!, m.lat!)),
              zoom: 15.0,
            ),
            mb.MapAnimationOptions(duration: 500),
          );
        }
      }
    }
  }

  void _nextCard({bool manual = false}) {
    if (manual) _stopPlayback();
    final moments = widget.c.timelineMoments;
    if (moments.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % moments.length;
    });
    _moveCameraToCurrent();
    HapticFeedback.lightImpact();
  }

  void _prevCard({bool manual = false}) {
    if (manual) _stopPlayback();
    final moments = widget.c.timelineMoments;
    if (moments.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + moments.length) % moments.length;
    });
    _moveCameraToCurrent();
    HapticFeedback.lightImpact();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      _startPlayback();
    }
    HapticFeedback.mediumImpact();
  }

  void _startPlayback() {
    setState(() {
      _isPlaying = true;
    });
    _timer?.cancel();

    final double intervalSeconds =
        _playbackSpeed == 1 ? 3.0 : (_playbackSpeed == 2 ? 1.5 : 1.0);
    _timer = Timer.periodic(
        Duration(milliseconds: (intervalSeconds * 1000).toInt()), (timer) {
      _nextCard();
    });
  }

  void _stopPlayback() {
    if (!_isPlaying) return;
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _toggleSpeed() {
    setState(() {
      if (_playbackSpeed == 1) {
        _playbackSpeed = 2;
      } else if (_playbackSpeed == 2) {
        _playbackSpeed = 3;
      } else {
        _playbackSpeed = 1;
      }
    });
    if (_isPlaying) {
      _startPlayback(); // Reset timer with the new speed setting
    }
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moments = widget.c.timelineMoments;

    if (moments.isEmpty) {
      return Container(
        height: 120,
        width: 320,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Text(
          'No moments yet in this journey.',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
      );
    }

    final total = moments.length;
    final m2 = moments[(_currentIndex + 2) % total];
    final m1 = moments[(_currentIndex + 1) % total];
    final mActive = moments[_currentIndex];

    final timeStr =
        '${mActive.createdAt.hour.toString().padLeft(2, '0')}:${mActive.createdAt.minute.toString().padLeft(2, '0')}';
    final dateStr = '${mActive.createdAt.day}/${mActive.createdAt.month}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Polaroid Stack Container
          SizedBox(
            width: 300,
            height: 360,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Bottom Card Layer 2 (rotated -6 degrees)
                if (total > 2)
                  Positioned.fill(
                    child: Transform.rotate(
                      angle: -6 * 3.1415926535 / 180,
                      child: Transform.translate(
                        offset: const Offset(4, 8),
                        child: Opacity(
                          opacity: 0.4,
                          child: _PolaroidCard(m: m2, isBackground: true),
                        ),
                      ),
                    ),
                  ),

                // 2. Middle Card Layer 1 (rotated 4 degrees)
                if (total > 1)
                  Positioned.fill(
                    child: Transform.rotate(
                      angle: 4 * 3.1415926535 / 180,
                      child: Transform.translate(
                        offset: const Offset(2, 4),
                        child: Opacity(
                          opacity: 0.75,
                          child: _PolaroidCard(m: m1, isBackground: true),
                        ),
                      ),
                    ),
                  ),

                // 3. Top Active Polaroid Card (with Swipe Gestures and Smooth Snapping Transition)
                Positioned.fill(
                  child: GestureDetector(
                    onHorizontalDragStart: (_) {
                      setState(() {
                        _isDragging = true;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _dragOffset += details.delta.dx;
                        _targetOffset = _dragOffset;
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      setState(() {
                        _isDragging = false;
                        if (_dragOffset < -80) {
                          _nextCard(manual: true); // Swiped Left -> Next
                        } else if (_dragOffset > 80) {
                          _prevCard(manual: true); // Swiped Right -> Prev
                        }
                        _dragOffset = 0.0;
                        _targetOffset = 0.0;
                      });
                    },
                    child: TweenAnimationBuilder<double>(
                      duration: _isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      tween:
                          Tween<double>(begin: _dragOffset, end: _targetOffset),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(value, 0),
                          child: Transform.rotate(
                            angle: (value / 300) *
                                (12 *
                                    3.1415926535 /
                                    180), // Rotate slightly on drag
                            child: child,
                          ),
                        );
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(
                                  0.2, 0.0), // Slide in from right slightly
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.9, end: 1.0)
                                    .animate(animation),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _PolaroidCard(
                          key: ValueKey<int>(
                              _currentIndex), // Trigger switch animation on change
                          m: mActive,
                          timeStr: timeStr,
                          dateStr: dateStr,
                          onClose: () => widget.c.showTimeline.value = false,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Replay Control Panel with Play / Pause & Speed
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => _prevCard(manual: true),
              ),
              const SizedBox(width: 8),

              // Play/Pause button
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: const Color(0xFF00E5FF),
                  size: 40,
                ),
                onPressed: _togglePlay,
              ),
              const SizedBox(width: 8),

              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => _nextCard(manual: true),
              ),
              const SizedBox(width: 12),

              // Speed control badge
              InkWell(
                onTap: _toggleSpeed,
                borderRadius: AppRadius.button,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.button,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: Colors.black.withValues(alpha: 0.6),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  '${_currentIndex + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thẻ Polaroid lật ảnh (RepaintBoundary Optimized)
class _PolaroidCard extends StatelessWidget {
  const _PolaroidCard({
    super.key,
    required this.m,
    this.isBackground = false,
    this.timeStr,
    this.dateStr,
    this.onClose,
  });

  final MomentModel m;
  final bool isBackground;
  final String? timeStr;
  final String? dateStr;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    // Isolate the card repaint boundary to boost UI rendering performance
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Image Container
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Isolate network image rendering layer
                    RepaintBoundary(
                      child: CachedNetworkImage(
                        imageUrl: m.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.broken_image_rounded,
                              size: 24, color: Colors.black38),
                        ),
                      ),
                    ),
                    if (!isBackground && onClose != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onClose,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (!isBackground) ...[
              const SizedBox(height: 12),
              // Caption (Handwritten feel)
              Text(
                m.caption ?? 'No caption',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 8),
              // Footer Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${timeStr ?? ""} - ${dateStr ?? ""}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    m.fullName ?? 'User',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _kBrand,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
