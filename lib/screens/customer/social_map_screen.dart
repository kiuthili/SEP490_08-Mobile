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

import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/social_map_controller.dart';
import '../../models/map_models.dart';
import '../../models/social_models.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/loading_widget.dart';

// Bảng màu thương hiệu (đồng bộ với web: brand #0068E0).
const Color _kBrand = Color(0xFF0068E0);
const Color _kBrandDark = Color(0xFF0050B3);



class SocialMapScreen extends StatelessWidget {
  const SocialMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SocialMapController());

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
              color: c.isSharingLocation.value ? Colors.redAccent : null,
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
              bottom: c.showTimeline.value ? 260 : 24,
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
              bottom: c.showTimeline.value ? 260 : 24,
              child: _HeatmapLegend(c: c),
            )),

            // ---- Nút Chụp & đăng Moment (giữa dưới) ----
            Obx(() => c.showTimeline.value
                ? const SizedBox.shrink()
                : Positioned(
                    left: 0,
                    right: 0,
                    bottom: 28,
                    child: Center(child: _CaptureMomentButton(c: c)),
                  )),

            // ---- Overlay dưới cùng: Dòng thời gian hành trình ----
            Obx(() => c.showTimeline.value
                ? Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _TimelinePanel(c: c),
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
  final url = 'https://stayhub.com/track/$token';
  await Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              borderRadius: BorderRadius.circular(12),
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
    return FlutterMap(
      mapController: c.mapController,
      options: MapOptions(
        initialCenter: SocialMapController.defaultCenter,
        initialZoom: SocialMapController.defaultZoom,
        onMapReady: c.onMapReady,
        onPositionChanged: (camera, hasGesture) {
          c.updateZoom(camera.zoom);
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.stayhub.mobile',
          maxZoom: 19,
          // OSM không hỗ trợ @2x ({r}) -> KHÔNG bật retinaMode để tránh
          // emulation (tải 4 tile/level => tốn băng thông, giảm max zoom).
          tileProvider: NetworkTileProvider(),
        ),

        // --- 5) HEATMAP (đặt thấp nhất để marker nằm trên) ---
        Obx(() {
          if (!c.showHeatmap.value || c.heatPoints.isEmpty) {
            return const SizedBox.shrink();
          }
          return HeatMapLayer(
            heatMapDataSource: InMemoryHeatMapDataSource(
              data: c.heatPoints
                  .map(
                    (p) => WeightedLatLng(LatLng(p.lat, p.lng), p.weight),
              )
                  .toList(),
            ),
            heatMapOptions: HeatMapOptions(
              gradient: {
                0.4: Colors.teal,
                0.6: Colors.purple,
                0.8: Colors.pink,
                1.0: Colors.orange,
              },
              minOpacity: 0.2,
              radius: c.heatmapRadius.value,
            ),
            reset: c.heatmapResetStream,
          );
        }),

        // --- 4) FOOTPRINTS ("cào map" - Smooth Bump Effect) ---
        Obx(() {
          if (!c.showFootprints.value) {
            return const SizedBox.shrink();
          }

          final List<LatLng> activeFootprints = [
            ...c.footprints.map((f) => LatLng(f.lat, f.lng)),
            const LatLng(20.2536, 105.9754), // Dummy point 1 (Ninh Binh)
            const LatLng(20.2650, 105.9800), // Dummy point 2 (Ninh Binh)
          ];

          return FogOfWarLayer(footprints: activeFootprints);
        }),

        // --- 4b) VỆT DI CHUYỂN REALTIME của tôi ("cào map liên tục") ---
        Obx(() {
          if (!c.showFootprints.value || c.liveTrail.length < 2) {
            return const SizedBox.shrink();
          }
          return PolylineLayer(
            polylines: [
              Polyline(
                points: c.liveTrail.toList(),
                strokeWidth: 5,
                gradientColors: const [Color(0xFF34C3FF), _kBrand],
                borderColor: Colors.white,
                borderStrokeWidth: 1.5,
              ),
            ],
          );
        }),

        // --- 3) LỘ TRÌNH TOUR (Polyline) ---
        Obx(() {
          if (!c.showRoute.value || c.drivingRouteLatLngs.isEmpty) {
            return const SizedBox.shrink();
          }
          return PolylineLayer(
            polylines: [
              // Underglow (thicker, semi-transparent)
              Polyline(
                points: c.drivingRouteLatLngs,
                strokeWidth: 8,
                color: _kBrandDark.withValues(alpha: 0.4),
                borderStrokeWidth: 0,
              ),
              // Main solid line
              Polyline(
                points: c.drivingRouteLatLngs,
                strokeWidth: 4.5,
                color: _kBrand,
                borderColor: Colors.white,
                borderStrokeWidth: 1.5,
              ),
            ],
          );
        }),

        // --- 3b) MARKER các điểm đến của lộ trình ---
        Obx(() {
          if (!c.showRoute.value || c.routePoints.isEmpty) {
            return const SizedBox.shrink();
          }
          return MarkerLayer(
            markers: [
              for (var i = 0; i < c.routePoints.length; i++)
                if (c.routePoints[i].hasCoordinates)
                  Marker(
                    point: LatLng(c.routePoints[i].lat, c.routePoints[i].lng),
                    width: 140,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(
                      child: _RoutePin(point: c.routePoints[i], order: i + 1),
                    ),
                  ),
            ],
          );
        }),

        // --- 2) MOMENTS trên map (Photo Map) ---
        Obx(() {
          if (!c.showMoments.value || c.mapMoments.isEmpty) {
            return const SizedBox.shrink();
          }
          return MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 45,
              size: const Size(40, 40),
              markers: [
                for (final m in c.mapMoments)
                  Marker(
                    point: LatLng(m.lat!, m.lng!),
                    width: 66,
                    height: 66,
                    child: RepaintBoundary(child: _MomentMarker(moment: m)),
                  ),
              ],
              builder: (context, markers) {
                return Container(
                  decoration: BoxDecoration(
                    color: _kBrand,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${markers.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          );
        }),

        // --- 1) LIVE LOCATION bạn bè / người cùng tour ---
        Obx(() {
          if (!c.showLiveLocations.value || c.liveLocations.isEmpty) {
            return const SizedBox.shrink();
          }
          return MarkerLayer(
            markers: [
              for (final loc in c.visualLiveLocations)
                Marker(
                  point: LatLng(loc.latitude, loc.longitude),
                  width: 130,
                  height: 78,
                  alignment: Alignment.topCenter,
                  child: RepaintBoundary(
                    child: _LiveLocationMarker(location: loc),
                  ),
                ),
            ],
          );
        }),

        // --- Marker "Tôi" ở đầu vệt di chuyển realtime ---
        Obx(() {
          if (!c.isSharingLocation.value || c.liveTrail.isEmpty) {
            return const SizedBox.shrink();
          }
          return MarkerLayer(
            markers: [
              Marker(
                point: c.liveTrail.last,
                width: 60,
                height: 60,
                child: const RepaintBoundary(child: _MeMarker()),
              ),
            ],
          );
        }),

        // --- Attribution (bắt buộc theo điều khoản OSM) ---
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// MARKER WIDGETS
// ============================================================

/// Marker ảnh thumbnail của Moment (giống Snap/Zalo map). Chạm -> chi tiết.
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
              child: const Icon(Icons.broken_image,
                  size: 20, color: Colors.white),
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
              color: const Color(0xFF059669), // Emerald 600
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF34D399), width: 1), // Emerald 400
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
                      color: (isStaff ? const Color(0xFF10B981) : _kBrand)
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
                  color: isStaff ? const Color(0xFF10B981) : _kBrand,
                  border: Border.all(
                    color: isStaff ? const Color(0xFF10B981) : Colors.white,
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
            borderRadius: BorderRadius.circular(8),
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
      
      final selectedSchedule = c.eligibleSchedules.firstWhereOrNull(
        (s) => s.scheduleId == c.selectedScheduleId.value
      );
      final label = c.selectedScheduleId.value == 0 ? 'All Trips' : (selectedSchedule?.tourName ?? 'All Trips');

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
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
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
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.black54),
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
                      backgroundColor: isAllTrips ? _kBrand : Colors.grey.shade200,
                      child: Icon(Icons.public_rounded,
                          color: isAllTrips ? Colors.white : Colors.black54, size: 20),
                    ),
                    title: Text(
                      'All Trips',
                      style: TextStyle(
                        fontWeight: isAllTrips ? FontWeight.bold : FontWeight.normal,
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
                        backgroundColor: selected ? _kBrand : Colors.grey.shade200,
                        child: Icon(Icons.tour_rounded,
                            color: selected ? Colors.white : Colors.black54, size: 20),
                      ),
                      title: Text(
                        s.tourName,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? _kBrand : Colors.black87,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded, color: _kBrand)
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
      return Container(
        margin: const EdgeInsets.only(top: 8),
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: c.routeDays.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final d = c.routeDays[i];
            final selected = c.selectedDay.value == d.dayNumber;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                c.selectDay(d.dayNumber);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? _kBrand
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 3),
                  ],
                ),
                child: Text(
                  'Day ${d.dayNumber}',
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
        borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(24),
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
                        content: Text('Long press the Heatmap button for options'),
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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Heatmap Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Data Source', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Obx(() => Row(
              children: [
                Expanded(child: _buildTypeOption(c, 'all', 'All Data')),
                const SizedBox(width: 8),
                Expanded(child: _buildTypeOption(c, 'online', 'Online')),
                const SizedBox(width: 8),
                Expanded(child: _buildTypeOption(c, 'moments', 'Moments')),
              ],
            )),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Radius & Intensity', style: TextStyle(fontWeight: FontWeight.bold)),
                Obx(() => Text('${c.heatmapRadius.value.toInt()}', style: const TextStyle(color: _kBrand, fontWeight: FontWeight.bold))),
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
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? _kBrand.withValues(alpha: 0.1) : Colors.grey.shade100,
        border: Border.all(color: isSelected ? _kBrand : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(
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
      borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(12),
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
                  colors: [Colors.blue, Colors.green, Colors.yellow, Colors.red],
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
        borderRadius: BorderRadius.circular(30),
        onTap: () async {
          HapticFeedback.mediumImpact();
          await Get.toNamed(AppRoutes.shareMoment);
          await c.loadMapMoments(c.selectedScheduleId.value);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_kBrand, Color(0xFF34C3FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: _kBrand.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
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

/// Panel Dòng thời gian hành trình (Timeline Panel) vuốt hiển thị danh sách các bài viết/ảnh
class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.c});
  final SocialMapController c;

  @override
  Widget build(BuildContext context) {
    final moments = c.timelineMoments;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Column(
        children: [
          // Tiêu đề
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: _kBrand, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Journey Timeline (${moments.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black54, size: 22),
                      onPressed: () => c.showTimeline.value = false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),

          // Danh sách Moment cuộn dọc (cột ảnh)
          Expanded(
            child: moments.isEmpty
                ? const Center(
                    child: Text(
                      'No moments yet in this journey.',
                      style: TextStyle(color: Colors.black45, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: moments.length,
                    itemBuilder: (context, index) {
                      final m = moments[index];
                      final timeStr = '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
                      final dateStr = '${m.createdAt.day}/${m.createdAt.month}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: GesturefulMomentCard(c: c, m: m, timeStr: timeStr, dateStr: dateStr),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ hiển thị khoảnh khắc trong Timeline và tự di chuyển camera khi chạm vào
class GesturefulMomentCard extends StatelessWidget {
  const GesturefulMomentCard({
    super.key,
    required this.c,
    required this.m,
    required this.timeStr,
    required this.dateStr,
  });

  final SocialMapController c;
  final MomentModel m;
  final String timeStr;
  final String dateStr;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (m.lat != null && m.lng != null) {
          c.mapController.move(LatLng(m.lat!, m.lng!), 15);
        }
      },
      child: Container(
        width: double.infinity,
        height: 380, // Chiều cao cố định để tạo thành cột ảnh lớn
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: m.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_rounded, size: 20, color: Colors.black38),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              m.caption ?? 'No caption',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$timeStr - $dateStr',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
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
        ),
      ),
    );
  }
}

class FogOfWarLayer extends StatelessWidget {
  final List<LatLng> footprints;
  const FogOfWarLayer({super.key, required this.footprints});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size(camera.size.x, camera.size.y),
        painter: _FogOfWarPainter(camera, footprints),
      ),
    );
  }
}

class _FogOfWarPainter extends CustomPainter {
  final MapCamera camera;
  final List<LatLng> footprints;

  _FogOfWarPainter(this.camera, this.footprints);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    
    // 1. Gen Z Aesthetic Holographic Gradient Fog
    final fogPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xDD1E1B4B), // Deep Indigo
          Color(0xDD4C1D95), // Vibrant Purple
          Color(0xDD9D174D), // Deep Pink
        ],
      ).createShader(rect)
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(rect, fogPaint);

    // 2. Playful Floating Icons (Sparser & Minimalist)
    final bounds = camera.visibleBounds;
    
    // INCREASED STEP SIZES for a wider grid
    double step = 0.025; 
    if (camera.zoom < 10) step = 0.25;
    if (camera.zoom < 13) step = 0.1;
    if (camera.zoom > 16) step = 0.008;

    final startLat = (bounds.south / step).floor() * step;
    final endLat = (bounds.north / step).ceil() * step;
    final startLng = (bounds.west / step).floor() * step;
    final endLng = (bounds.east / step).ceil() * step;

    final icons = ['☁️', '✨', '☁️', '🌙'];

    for (double lat = startLat; lat <= endLat; lat += step) {
      for (double lng = startLng; lng <= endLng; lng += step) {
        int hash = (lat * 10000).toInt() ^ (lng * 10000).toInt();
        
        // STRICTER FILTER: Only show an icon roughly 1 out of every 6 points
        if (hash % 6 != 0) continue;

        String icon = icons[hash.abs() % icons.length];
        
        double latOffset = ((hash % 100) - 50) / 100 * (step * 0.5);
        double lngOffset = (((hash ~/ 100) % 100) - 50) / 100 * (step * 0.5);

        final targetPoint = LatLng(lat + latOffset, lng + lngOffset);
        final pos = camera.project(targetPoint);
        
        final dx = pos.x - camera.pixelOrigin.x;
        final dy = pos.y - camera.pixelOrigin.y;

        final span = TextSpan(
          text: icon,
          style: TextStyle(
            fontSize: (hash % 2 == 0) ? 24 : 16, // Slightly reduced max size
            color: Colors.white.withValues(alpha: 0.5), // Softer opacity
          ),
        );
        final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
        tp.layout();
        
        tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
      }
    }

    // 3. The Neon Glow Aura Paint (Vibrant Cyan)
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    // 4. The Soft Eraser Paint
    final erasePaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    for (final fp in footprints) {
      final pos = camera.project(fp);
      final offset = Offset(pos.x - camera.pixelOrigin.x, pos.y - camera.pixelOrigin.y);

      if (offset.dx < -100 || offset.dx > size.width + 100 ||
          offset.dy < -100 || offset.dy > size.height + 100) {
        continue;
      }
      
      canvas.drawCircle(offset, 45, glowPaint);
      canvas.drawCircle(offset, 45, erasePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FogOfWarPainter oldDelegate) {
    return oldDelegate.camera.zoom != camera.zoom ||
        oldDelegate.camera.center != camera.center ||
        oldDelegate.footprints != footprints;
  }
}

