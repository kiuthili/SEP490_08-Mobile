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
      title: 'Bản đồ Social',
      actions: [
        IconButton(
          tooltip: 'Chia sẻ link vị trí của tôi',
          icon: const Icon(Icons.share_location_rounded),
          onPressed: () => _showShareLinkDialog(c),
        ),
        Obx(
              () => IconButton(
            tooltip: c.isSharingLocation.value
                ? 'Đang chia sẻ vị trí — chạm để tắt'
                : 'Chia sẻ vị trí của tôi',
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
          return const LoadingWidget(message: 'Đang tải bản đồ...');
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

            // ---- Nút điều khiển bản đồ (phải, trên panel layer) ----
            Positioned(
              right: 12,
              bottom: 150,
              child: _MapControls(c: c),
            ),

            // ---- Overlay phải: bảng bật/tắt các lớp ----
            Positioned(
              right: 12,
              bottom: 24,
              child: _LayerTogglePanel(c: c),
            ),

            // ---- Overlay trái: chú thích Heatmap ----
            Positioned(
              left: 12,
              bottom: 24,
              child: _HeatmapLegend(c: c),
            ),

            // ---- Nút Chụp & đăng Moment (giữa dưới) ----
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(child: _CaptureMomentButton(c: c)),
            ),

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
      title: Row(
        children: const [
          Icon(Icons.share_location_rounded, color: _kBrand),
          SizedBox(width: 8),
          Expanded(child: Text('Chia sẻ vị trí của tôi')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gửi đường dẫn này cho bạn bè / người thân để họ theo dõi trực tiếp '
                'vị trí của bạn trên bản đồ:',
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
        TextButton(onPressed: Get.back, child: const Text('Đóng')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _kBrand),
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Sao chép'),
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
              gradient: HeatMapOptions.defaultGradient,
              minOpacity: 0.1,
              radius: 60,
            ),
            reset: c.heatmapResetStream,
          );
        }),

        // --- 4) FOOTPRINTS ("cào map") ---
        Obx(() {
          if (!c.showFootprints.value || c.footprints.isEmpty) {
            return const SizedBox.shrink();
          }
          return CircleLayer(
            circles: c.footprints
                .map(
                  (f) => CircleMarker(
                point: LatLng(f.lat, f.lng),
                radius: 400, // mét (useRadiusInMeter)
                useRadiusInMeter: true,
                color: Colors.orange.withValues(alpha: 0.22),
                borderColor: Colors.orange.withValues(alpha: 0.6),
                borderStrokeWidth: 1.2,
              ),
            )
                .toList(),
          );
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
          if (!c.showRoute.value || c.routeLatLngs.length < 2) {
            return const SizedBox.shrink();
          }
          return PolylineLayer(
            polylines: [
              Polyline(
                points: c.routeLatLngs,
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
          return MarkerLayer(
            markers: [
              for (final m in c.mapMoments)
                Marker(
                  point: LatLng(m.lat!, m.lng!),
                  width: 66,
                  height: 66,
                  child: RepaintBoundary(child: _MomentMarker(moment: m)),
                ),
            ],
          );
        }),

        // --- 1) LIVE LOCATION bạn bè / người cùng tour ---
        Obx(() {
          if (!c.showLiveLocations.value || c.liveLocations.isEmpty) {
            return const SizedBox.shrink();
          }
          return MarkerLayer(
            markers: [
              for (final loc in c.liveLocations)
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kBrand, Color(0xFF34C3FF)],
          ),
          boxShadow: const [
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

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                      color: _kBrand.withValues(alpha: (1 - t) * 0.35),
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
                  color: _kBrand,
                  border: Border.all(color: Colors.white, width: 2.5),
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

/// Thanh chọn lịch trình tour (ngang).
class _ScheduleSelectorBar extends StatelessWidget {
  const _ScheduleSelectorBar({required this.c});
  final SocialMapController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.eligibleSchedules.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: c.eligibleSchedules.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final s = c.eligibleSchedules[i];
            final selected = c.selectedScheduleId.value == s.scheduleId;
            return _Glass(
              borderRadius: 22,
              padding: EdgeInsets.zero,
              color: selected
                  ? _kBrand.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.85),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => c.selectSchedule(s.scheduleId),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tour_rounded,
                        size: 15,
                        color: selected ? Colors.white : _kBrand,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          s.tourName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
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
                  'Ngày ${d.dayNumber}',
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
            tooltip: 'Về vị trí của tôi',
            onTap: c.recenter,
          ),
          const _CtrlDivider(),
          _CtrlBtn(
            icon: Icons.add_rounded,
            tooltip: 'Phóng to',
            onTap: c.zoomIn,
          ),
          const _CtrlDivider(),
          _CtrlBtn(
            icon: Icons.remove_rounded,
            tooltip: 'Thu nhỏ',
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
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

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
          child: Icon(icon, size: 22, color: _kBrandDark),
        ),
      ),
    );
  }
}

/// Bảng bật/tắt các lớp bản đồ (glassmorphism).
class _LayerTogglePanel extends StatelessWidget {
  const _LayerTogglePanel({required this.c});
  final SocialMapController c;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      color: Colors.white.withValues(alpha: 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() => _LayerButton(
            icon: Icons.people_alt_rounded,
            label: 'Bạn bè',
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
            label: 'Lộ trình',
            active: c.showRoute.value,
            onTap: c.showRoute.toggle,
          )),
          Obx(() => _LayerButton(
            icon: Icons.terrain_rounded,
            label: 'Cào map',
            active: c.showFootprints.value,
            loading: c.isFootprintsLoading.value,
            onTap: c.toggleFootprints,
          )),
          Obx(() => _LayerButton(
            icon: Icons.local_fire_department_rounded,
            label: 'Heatmap',
            active: c.showHeatmap.value,
            loading: c.isHeatmapLoading.value,
            onTap: c.toggleHeatmap,
          )),
        ],
      ),
    );
  }
}

class _LayerButton extends StatelessWidget {
  const _LayerButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool loading;
  final VoidCallback onTap;

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
            const Text('Mật độ',
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
                Text('Ít', style: TextStyle(fontSize: 9)),
                Text('Đông', style: TextStyle(fontSize: 9)),
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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kBrand, Color(0xFF34C3FF)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _kBrand.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Chụp & đăng',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
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
