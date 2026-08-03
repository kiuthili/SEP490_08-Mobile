// lib/controllers/social_map_controller.dart
//
// Controller chuyên trách cho màn hình Bản đồ Social (flutter_map).
// Quản lý 5 nhóm tính năng:
//   1) Live Location (SignalR realtime) — bạn bè + người cùng tour
//   2) Moments trên Map (Photo Map)
//   3) Lộ trình Tour theo ngày (Polyline)
//   4) "Cào Map" / Footprints (CircleLayer)
//   5) Heatmap (lớp bản đồ nhiệt)
//
// Toàn bộ state là Rx => binding bằng Obx ở View. Tuân thủ Null Safety.
//
// ✦ Bản nâng cấp (UI/UX + hiệu năng):
//   - Map-ready guard: chỉ fit camera sau khi map đã mount (hết exception thầm lặng).
//   - Debounce heatmap rebuild + chống nháy layer.
//   - recenter() / zoomIn() / zoomOut() phục vụ nút điều khiển bản đồ.
//   - Dọn dẹp đầy đủ ở onClose (timer, signalR, mapController, stream).
//   - Polling bạn bè được "lệch pha" với ping để giảm tải đột biến.
//
// Endpoint đã đối chiếu đúng backend (GatewayAPI / YARP):
//   - GET  /api/locations/friends/live
//   - GET  /api/locations/schedules/{id}/live
//   - POST /api/locations/ping
//   - GET  /api/moments?scheduleId=&$skip=&$top=
//   - GET  /api/moments/my-footprints
//   - GET  /api/tourscheduleitineraries?scheduleId=
//   - Heatmap: backend CÓ thể chưa có -> dựng client-side (xem loadHeatmap).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/feature_controllers.dart'; // OrderController
import '../models/api_response.dart';
import '../models/feature_models.dart';
import '../models/map_models.dart';
import '../models/social_models.dart';
import '../services/location_helper.dart';
import '../services/signalr_service.dart';
import '../services/social_service.dart';
import '../services/storage_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/marker_generator.dart';
import '../utils/fog_mask_geojson_builder.dart';

class SocialMapController extends GetxController {
  SocialMapController({
    SocialService? service,
    SignalRService? signalR,
    StorageService? storage,
    OrderController? orderController,
  })  : _service = service ?? Get.find<SocialService>(),
        _signalR = signalR ?? Get.find<SignalRService>(),
        _storage = storage ?? Get.find<StorageService>(),
        _orderController = orderController ?? Get.find<OrderController>();

  final SocialService _service;
  final SignalRService _signalR;
  final StorageService _storage;
  final OrderController _orderController;

  /// MapController dùng để fit camera / điều khiển zoom.

  mb.MapboxMap? mapboxMap;
  mb.PointAnnotationManager? liveLocManager;
  mb.PointAnnotationManager? momentManager;
  mb.PointAnnotationManager? scheduleManager;
  mb.PointAnnotationManager? waypointManager;
  mb.PolylineAnnotationManager? routeCasingManager;
  mb.PolylineAnnotationManager? routeDashedCoreManager;
  mb.PolygonAnnotationManager? footprintManager;

  Future<void> onMapCreated(mb.MapboxMap map) async {
    mapboxMap = map;
    try {
      await mapboxMap!.scaleBar.updateSettings(mb.ScaleBarSettings(enabled: false));
      await mapboxMap!.compass.updateSettings(mb.CompassSettings(enabled: false));
    } catch (_) {}
    debugPrint('MAP_CREATED');
  }

  bool _isSyncing = false;

  /// Mutex riêng cho _syncMomentsGeoJson — độc lập với _isSyncing của onStyleLoaded.
  /// Ngăn 2 lần gọi concurrent (từ ever(mapMoments) và ever(showMoments)) cùng
  /// gọi Mapbox native API → crash.
  bool _isSyncingMoments = false;

  /// Cờ để tránh gọi Mapbox API sau khi controller bị dispose.
  bool _isDisposed = false;

  /// Cache các imageId đã upload vào Mapbox style để skip re-download.
  /// Được reset khi style reload (onStyleLoaded).
  final Set<String> _uploadedImageIds = {};

  /// Image load generation: tăng mỗi lần schedule thay đổi — hủy background load cũ.
  int _imageLoadGeneration = 0;

  Future<void> onStyleLoaded(mb.StyleLoadedEventData event) async {
    debugPrint('STYLE_LOADED');
    debugPrint('STYLE_INITIALIZATION_START');
    if (_isSyncing) return;
    _isSyncing = true;
    isMapReady.value = false;
    _waypointMarkerCache.clear();
    // Reset image cache khi style reload — các imageId cũ không còn hợp lệ.
    _uploadedImageIds.clear();
    _lastMomentSignature = "";
    // Hủy background image load cũ trước khi style reload.
    _imageLoadGeneration++;

    try {
      if (mapboxMap == null) return;

      // Cleanup Managers
      try {
        if (liveLocManager != null) {
          await mapboxMap!.annotations.removeAnnotationManager(liveLocManager!);
        }
        if (momentManager != null) {
          await mapboxMap!.annotations.removeAnnotationManager(momentManager!);
        }
        if (scheduleManager != null) {
          await mapboxMap!.annotations
              .removeAnnotationManager(scheduleManager!);
        }
        if (waypointManager != null) {
          await mapboxMap!.annotations
              .removeAnnotationManager(waypointManager!);
        }
        if (routeCasingManager != null) {
          await mapboxMap!.annotations
              .removeAnnotationManager(routeCasingManager!);
        }
        if (routeDashedCoreManager != null) {
          await mapboxMap!.annotations
              .removeAnnotationManager(routeDashedCoreManager!);
        }
        // Remove legacy footprintManager if it exists
        if (footprintManager != null) {
          await mapboxMap!.annotations
              .removeAnnotationManager(footprintManager!);
        }
      } catch (e, stack) {
        debugPrint('MAP_RENDER_ERROR: Error cleaning up managers: $e\n$stack');
      }

      // Deprecate Moment PointAnnotationManager but keep the variable
      liveLocManager = null;
      // momentManager = null; // Do not use PointAnnotationManager for moments anymore
      scheduleManager = null;
      waypointManager = null;
      routeCasingManager = null;
      routeDashedCoreManager = null;
      footprintManager = null;

      // 1. Heatmap
      try {
        if (await mapboxMap!.style.styleLayerExists("stayhub-heatmap-layer")) {
          await mapboxMap!.style.removeStyleLayer("stayhub-heatmap-layer");
        }
        if (await mapboxMap!.style
            .styleSourceExists("stayhub-heatmap-source")) {
          await mapboxMap!.style.removeStyleSource("stayhub-heatmap-source");
        }

        await mapboxMap!.style.addSource(mb.GeoJsonSource(
            id: "stayhub-heatmap-source",
            data: '{"type":"FeatureCollection","features":[]}'));
        await mapboxMap!.style.addLayer(mb.HeatmapLayer(
          id: "stayhub-heatmap-layer",
          sourceId: "stayhub-heatmap-source",
          heatmapWeightExpression: ["get", "weight"],
          heatmapIntensityExpression: [
            "interpolate",
            ["linear"],
            ["zoom"],
            0,
            1,
            15,
            3
          ],
          heatmapRadiusExpression: [
            "interpolate",
            ["linear"],
            ["zoom"],
            0,
            2,
            9,
            20,
            15,
            40
          ],
          heatmapOpacity: 0.45,
          heatmapColorExpression: [
            "interpolate",
            ["linear"],
            ["heatmap-density"],
            0,
            "rgba(255, 255, 255, 0)",
            0.2,
            "#E9D5FF",
            0.5,
            "#C084FC",
            0.8,
            "#8B5CF6",
            1,
            "#5B21B6"
          ],
        ));
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: Heatmap setup failed: $e');
      }

      // 2. Footprints (Legacy Cleanup)
      try {
        if (await mapboxMap!.style
            .styleLayerExists("stayhub-footprint-point-layer")) {
          await mapboxMap!.style
              .removeStyleLayer("stayhub-footprint-point-layer");
        }
        if (await mapboxMap!.style
            .styleLayerExists("stayhub-footprint-point-halo-layer")) {
          await mapboxMap!.style
              .removeStyleLayer("stayhub-footprint-point-halo-layer");
        }
        if (await mapboxMap!.style
            .styleSourceExists("stayhub-footprint-source")) {
          await mapboxMap!.style.removeStyleSource("stayhub-footprint-source");
        }
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: Footprint cleanup failed: $e');
      }

      // 3. Clouds (Legacy Cleanup)
      try {
        if (await mapboxMap!.style
            .styleLayerExists("stayhub-footprint-cloud-layer")) {
          await mapboxMap!.style
              .removeStyleLayer("stayhub-footprint-cloud-layer");
        }
        if (await mapboxMap!.style
            .styleSourceExists("stayhub-footprint-cloud-source")) {
          await mapboxMap!.style
              .removeStyleSource("stayhub-footprint-cloud-source");
        }
        if (await mapboxMap!.style
            .hasStyleImage("stayhub-footprint-cloud-image")) {
          await mapboxMap!.style
              .removeStyleImage("stayhub-footprint-cloud-image");
        }
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: Cloud cleanup failed: $e');
      }

      // 3.5. NEW Fog Layer
      try {
        await _ensureFogSourceAndLayer();
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: Fog layer setup failed: $e');
      }

      // 3.6 NEW Moment Clusters
      try {
        await _ensureMomentSourceAndLayers();
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: Moment cluster layer setup failed: $e');
      }

      // 4. Managers
      try {
        routeDashedCoreManager = await mapboxMap!.annotations
            .createPolylineAnnotationManager(id: "route_core");
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: route_core manager failed: $e');
      }

      try {
        routeCasingManager = await mapboxMap!.annotations
            .createPolylineAnnotationManager(
                id: "route_casing", below: "route_core");
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: route_casing manager failed: $e');
        try {
          // Fallback without 'below' if the layer 'route_core' isn't ready
          routeCasingManager = await mapboxMap!.annotations
              .createPolylineAnnotationManager(id: "route_casing");
        } catch (e2) {
          debugPrint('MAP_RENDER_ERROR: route_casing manager fallback failed: $e2');
        }
      }

      try {
        liveLocManager = await mapboxMap!.annotations
            .createPointAnnotationManager(id: "live_loc");
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: live_loc manager failed: $e');
      }
      // Keep momentManager for cleanup but don't recreate it
      // momentManager = await mapboxMap!.annotations
      //     .createPointAnnotationManager(id: "moment");
      try {
        scheduleManager = await mapboxMap!.annotations
            .createPointAnnotationManager(id: "schedule");
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: schedule manager failed: $e');
      }

      try {
        waypointManager = await mapboxMap!.annotations
            .createPointAnnotationManager(id: "waypoint");
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: waypoint manager failed: $e');
      }

      try {
        final currentStyleUri = await mapboxMap!.style.getStyleURI();
        debugPrint('MAP_STYLE_URI: $currentStyleUri');
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: getStyleURI failed: $e');
      }

      try {
        final layers = await mapboxMap!.style.getStyleLayers();
        final idsList = <String>[];
        for (final layer in layers) {
          final id = layer?.id ?? "";
          idsList.add(id);
        }

        final cloudIdx = idsList.indexOf("stayhub-footprint-cloud-layer");
        final casingIdx = idsList.indexOf("route_casing");
        final coreIdx = idsList.indexOf("route_core");
        final waypointIdx = idsList.indexOf("waypoint");
        final scheduleIdx = idsList.indexOf("schedule");
        final momentIdx = idsList.indexOf("moment");
        final liveLocIdx = idsList.indexOf("live_loc");

        debugPrint(
            'CLOUD_LAYER_INDEX: ${cloudIdx >= 0 ? cloudIdx : 'unverified'}');
        debugPrint(
            'ROUTE_CASING_LAYER_INDEX: ${casingIdx >= 0 ? casingIdx : 'unverified'}');
        debugPrint(
            'ROUTE_CORE_LAYER_INDEX: ${coreIdx >= 0 ? coreIdx : 'unverified'}');
        debugPrint(
            'WAYPOINT_LAYER_INDEX: ${waypointIdx >= 0 ? waypointIdx : 'unverified'}');
        debugPrint(
            'SCHEDULE_LAYER_INDEX: ${scheduleIdx >= 0 ? scheduleIdx : 'unverified'}');
        debugPrint(
            'MOMENT_LAYER_INDEX: ${momentIdx >= 0 ? momentIdx : 'unverified'}');
        debugPrint(
            'LIVE_LOCATION_LAYER_INDEX: ${liveLocIdx >= 0 ? liveLocIdx : 'unverified'}');

        String aboveStatus = "unverified";
        if (cloudIdx >= 0 &&
            casingIdx >= 0 &&
            coreIdx >= 0 &&
            waypointIdx >= 0 &&
            scheduleIdx >= 0 &&
            momentIdx >= 0 &&
            liveLocIdx >= 0) {
          if (casingIdx > cloudIdx &&
              coreIdx > cloudIdx &&
              waypointIdx > cloudIdx &&
              scheduleIdx > cloudIdx &&
              momentIdx > cloudIdx &&
              liveLocIdx > cloudIdx) {
            aboveStatus = "true";
          } else {
            aboveStatus = "false";
          }
        }
        debugPrint('SYSTEM_LAYERS_ABOVE_CLOUDS: $aboveStatus');
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: Could not verify layer order: $e');
      }

      debugPrint('MANAGERS_CREATED');
      isMapReady.value = true;
      debugPrint('STYLE_INITIALIZATION_COMPLETE');
    } catch (e, stack) {
      debugPrint('MAP_RENDER_ERROR: Error during style load: $e\n$stack');
    } finally {
      _isSyncing = false;
    }

    if (isMapReady.value) {
      await _syncRoute();
      await _syncMomentsGeoJson();
      await _syncWaypoints();
      _scheduleFogMaskBuild();
      await _syncHeatmap();
      await _configureCurrentUserLocationPuck();
    }
  }

  void updateMapStylePreset(String preset) {
    if (mapboxMap != null) {
      mapboxMap!.loadStyleURI(
          preset == 'dark' ? mb.MapboxStyles.DARK : mb.MapboxStyles.STANDARD);
    }
  }




  int get currentUserId => _storage.user?.id ?? 0;

  /// Tâm bản đồ mặc định (Việt Nam) — dùng cho recenter khi chưa có dữ liệu.
  static const LatLng defaultCenter = LatLng(16.047079, 108.206230);
  static const double defaultZoom = 6;

  // ======================= GLOBAL STATE =======================
  final isLoading = false.obs;
  int _footprintRequestGeneration = 0;
  final RxnInt selectedScheduleId = RxnInt();
  final eligibleSchedules = <EligibleScheduleModel>[].obs;

  /// Map đã mount xong chưa (tránh fitCamera trước khi sẵn sàng).
  final isMapReady = false.obs;

  /// Stream to notify camera changes for Fog of War overlay
  final cameraUpdateStream = StreamController<void>.broadcast();

  // Yêu cầu fit camera đang chờ map mount xong.
  List<LatLng>? _pendingFit;

  /// Generation ID for Isolate computation to prevent race conditions
  int _fogGenerationId = 0;
  String? _lastFogGeoJson;

  Future<void> _ensureFogSourceAndLayer() async {
    if (mapboxMap == null) return;
    try {
      final style = mapboxMap!.style;
      if (!await style.styleSourceExists("stayhub-fog-source")) {
        // Create initial empty mask (Outer bounds only)
        final initialMask = await FogMaskGeoJsonBuilder.buildMaskIsolate({
          'generationId': 0,
          'footprints': [],
          'currentLocation': null,
          'radius': 300.0,
          'steps': 24,
          'precision': 6,
        });
        _lastFogGeoJson = initialMask['geojson'];
        await style.addSource(
            mb.GeoJsonSource(id: "stayhub-fog-source", data: _lastFogGeoJson));
      } else if (_lastFogGeoJson != null) {
        // Reloaded style -> reapply last known data
        await style.setStyleSourceProperty(
            "stayhub-fog-source", "data", _lastFogGeoJson!);
      }

      if (!await style.styleLayerExists("stayhub-fog-layer")) {
        await style.addLayer(mb.FillLayer(
          id: "stayhub-fog-layer",
          sourceId: "stayhub-fog-source",
          fillColor: 0xFF673AB7,
          fillOpacity: showFootprints.value ? 0.50 : 0.0,
          fillAntialias: true,
        ));
        await style.addLayer(mb.LineLayer(
          id: "stayhub-fog-edge-layer",
          sourceId: "stayhub-fog-source",
          lineColor: 0xFF673AB7,
          lineWidth: 10.0,
          lineBlur: 8.0,
          lineOpacity: showFootprints.value ? 0.22 : 0.0,
        ));
      } else {
        // Sync visibility
        await _setFogVisibility();
      }
    } catch (e) {
      debugPrint('MAP_RENDER_ERROR: _ensureFogSourceAndLayer failed: $e');
    }
  }

  void _scheduleFogMaskBuild() {
    if (mapboxMap == null || !isMapReady.value) return;

    _lastFogBuildPosition = _latestPosition;

    _fogGenerationId++;
    final currentGen = _fogGenerationId;

    // Tạo immutable snapshot
    final List<List<double>> fpSnapshot = footprints
        .where((f) => _isValidCoordinate(f.lat, f.lng))
        .map((f) => [f.lng, f.lat])
        .toList();

    List<double>? currentLoc;
    if (_latestPosition != null) {
      final currentLat = _latestPosition!.latitude;
      final currentLng = _latestPosition!.longitude;
      if (_isValidCoordinate(currentLat, currentLng)) {
        currentLoc = [currentLng, currentLat];
      }
    }

    compute(FogMaskGeoJsonBuilder.buildMaskIsolate, {
      'generationId': currentGen,
      'footprints': fpSnapshot,
      'currentLocation': currentLoc,
      'radius': 300.0,
      'steps': 24,
      'precision': 6,
    }).then((result) {
      if (_fogGenerationId != result['generationId']) {
        return; // Stale result
      }
      _syncFogGeoJson(result['geojson']);
    }).catchError((e) {
      debugPrint('MAP_RENDER_ERROR: Fog Isolate failed: $e');
    });
  }

  Future<void> _syncFogGeoJson(String geoJsonStr) async {
    if (_isSyncing || mapboxMap == null || !isMapReady.value) return;
    try {
      _lastFogGeoJson = geoJsonStr;
      if (await mapboxMap!.style.styleSourceExists("stayhub-fog-source")) {
        await mapboxMap!.style
            .setStyleSourceProperty("stayhub-fog-source", "data", geoJsonStr);
      } else {
        await _ensureFogSourceAndLayer();
      }
    } catch (e) {
      debugPrint('MAP_RENDER_ERROR: _syncFogGeoJson failed: $e');
    }
  }

  Future<void> _setFogVisibility() async {
    if (mapboxMap == null) return;
    try {
      if (await mapboxMap!.style.styleLayerExists("stayhub-fog-layer")) {
        await mapboxMap!.style.setStyleLayerProperty("stayhub-fog-layer",
            "fill-opacity", showFootprints.value ? 0.50 : 0.0);
      }
      if (await mapboxMap!.style.styleLayerExists("stayhub-fog-edge-layer")) {
        await mapboxMap!.style.setStyleLayerProperty("stayhub-fog-edge-layer",
            "line-opacity", showFootprints.value ? 0.22 : 0.0);
      }
    } catch (_) {}
  }

  // ----- Toggles của các lớp bản đồ -----
  final showLiveLocations = true.obs;
  final showMoments = true.obs;
  final showRoute = true.obs;
  final showFootprints = false.obs;
  final showHeatmap = false.obs;

  final heatmapType = 'moments'.obs; // 'online', 'moments'
  final heatmapRadius = 30.0.obs; // Similar to web radius

  // ======================= 1) LIVE LOCATION =======================
  final liveLocations = <LiveLocationModel>[].obs;
  final currentZoom = defaultZoom.obs;

  void updateZoom(double zoom) {
    currentZoom.value = zoom;
    // Trigger debounced viewport load when zoomed in enough
    if (zoom >= _viewportLoadZoomThreshold && mapboxMap != null) {
      _viewportMomentDebounce?.cancel();
      _viewportMomentDebounce = Timer(const Duration(milliseconds: 800), () {
        _loadMomentsInViewport();
      });
    }
  }

  bool _isLocationVisible(LiveLocationModel loc) {
    if (loc.userId == currentUserId) return true; // Always see myself

    final currentUser = _storage.user;
    if (currentUser == null) return false;

    // Admin has no map viewing rights
    if (currentUser.roles.any((r) => r.toLowerCase() == 'admin')) {
      return false;
    }

    final locRoleLower = loc.role.toLowerCase();

    // 1. Manager (Creator): Only sees Staff.
    if (currentUser.roles.any((r) => r.toLowerCase() == 'manager')) {
      return locRoleLower == 'staff';
    }

    // 2. Staff (Assigned): Sees Customer and other Staff.
    if (currentUser.roles.any((r) => r.toLowerCase() == 'staff')) {
      return locRoleLower == 'customer' || locRoleLower == 'staff';
    }

    // 3. Customer (Buyer): Sees Staff, other Customers, and friends.
    if (currentUser.roles.any((r) => r.toLowerCase() == 'customer')) {
      return locRoleLower == 'staff' || locRoleLower == 'customer';
    }

    return false;
  }

  List<LiveLocationModel> get visualLiveLocations {
    final zoom = currentZoom.value;
    // Offset increases visually as zoom decreases
    final double threshold = 0.0003 * math.pow(2, 15 - zoom);
    final double radius = 0.0004 * math.pow(2, 15 - zoom);

    final placed = <LatLng>[];
    final result = <LiveLocationModel>[];

    for (final loc in liveLocations) {
      if (loc.userId == currentUserId) {
        continue;
      }

      final fLat = loc.latitude;
      final fLng = loc.longitude;
      if (fLat == 0 && fLng == 0) continue;

      final overlaps = placed
          .where((p) =>
              (p.latitude - fLat).abs() < threshold &&
              (p.longitude - fLng).abs() < threshold)
          .toList();

      if (overlaps.isNotEmpty) {
        final count = overlaps.length;
        final angle = (count * 137.5) * (math.pi / 180.0);
        final pushRadius = radius + ((count ~/ 4) * radius * 0.3);

        final offsetLat = fLat + pushRadius * math.cos(angle);
        final offsetLng = fLng + pushRadius * math.sin(angle);

        placed.add(LatLng(offsetLat, offsetLng));
        result.add(LiveLocationModel(
          userId: loc.userId,
          fullName: loc.fullName,
          avatarUrl: loc.avatarUrl,
          latitude: offsetLat,
          longitude: offsetLng,
          updatedAt: loc.updatedAt,
          role: loc.role,
        ));
      } else {
        placed.add(LatLng(fLat, fLng));
        result.add(loc);
      }
    }

    return result;
  }

  /// Bật/tắt chia sẻ + ghi log di chuyển realtime của BẢN THÂN.
  final isSharingLocation = false.obs;
  Timer? _pingTimer;
  Timer? _friendsTimer;
  Timer? _footprintsTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _latestPosition;
  // Ping vị trí của tôi: 5s/lần để tracking liên tục thời gian thực.
  static const _pingInterval = Duration(seconds: 5);
  // Poll vị trí bạn bè: 10s/lần (đồng bộ tốc độ với bản web).
  static const _friendsRefreshInterval = Duration(seconds: 10);
  // Tự refresh footprints từ server khi lớp "Cào map" đang bật.
  static const _footprintsRefreshInterval = Duration(seconds: 30);

  /// "CÀO MAP LIÊN TỤC": vệt di chuyển realtime của bản thân, tích luỹ ngay tại
  /// client mỗi lần ping (không cần chờ server) => người dùng thấy đường đi lớn dần.
  final liveTrail = <LatLng>[].obs;
  LatLng? _lastTrailPoint;
  // Chỉ thêm điểm mới khi đã đi đủ xa (mét) để vệt mượt & nhẹ bộ nhớ.
  static const double _minTrailMeters = 12;
  static const int _maxTrailPoints = 2000;
  final Distance _distance = const Distance();

  // ======================= 2) MOMENTS ON MAP =======================
  final mapMoments = <MomentModel>[].obs;
  final showTimeline = false.obs;

  List<MomentModel> get timelineMoments {
    final list = List<MomentModel>.from(mapMoments);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  // ======================= 3) TOUR ROUTE (POLYLINE) =======================
  final routeDays = <RouteDayModel>[].obs;
  final RxnInt selectedDay = RxnInt();
  final routePoints = <RoutePointModel>[].obs;
  final drivingRouteLatLngs = <LatLng>[].obs;
  final isRouteLoading = false.obs;
  final List<RoutePointModel> _allItineraryPoints = [];
  List<RoutePointModel> get allItineraryPoints =>
      List<RoutePointModel>.unmodifiable(_allItineraryPoints);

  /// Toạ độ Polyline dẫn xuất từ routePoints (chỉ điểm có toạ độ hợp lệ).
  List<LatLng> get routeLatLngs => routePoints
      .where((p) => p.hasCoordinates)
      .map((p) => LatLng(p.lat, p.lng))
      .toList();

  // ======================= 4) FOOTPRINTS =======================
  final footprints = <FootprintDto>[].obs;

  List<LatLng> get revealPoints {
    final pts = <LatLng>[];
    for (final f in footprints) {
      if (_isValidCoordinate(f.lat, f.lng)) {
        pts.add(LatLng(f.lat, f.lng));
      }
    }
    for (final m in mapMoments) {
      if (m.userId == currentUserId &&
          m.lat != null &&
          m.lng != null &&
          _isValidCoordinate(m.lat!, m.lng!)) {
        pts.add(LatLng(m.lat!, m.lng!));
      }
    }
    return pts;
  }

  final isFootprintsLoading = false.obs;

  // ======================= 5) HEATMAP =======================
  final heatPoints = <HeatPointModel>[].obs;
  final isHeatmapLoading = false.obs;

  /// Stream để ép HeatMapLayer rebuild khi dữ liệu thay đổi.
  final StreamController<void> heatmapResetController =
      StreamController<void>.broadcast();
  Stream<void> get heatmapResetStream => heatmapResetController.stream;
  Timer? _heatmapDebounce;

  final Map<String, Uint8List> _waypointMarkerCache = {};

  // ======================= LIFECYCLE =======================
  @override
  void onInit() {
    super.onInit();
    _bootstrap();

    // Sync to Mapbox Native
    ever(liveLocations, (_) {
      _syncLiveLocations();
      if (heatmapType.value == 'online' && showHeatmap.value) loadHeatmap();
    });
    ever(mapMoments, (_) {
      _syncMomentsGeoJson();
      if (heatmapType.value == 'moments' && showHeatmap.value) loadHeatmap();
    });
    ever(showMoments, (_) {
      _syncMomentsGeoJson();
    });
    ever(drivingRouteLatLngs, (_) {
      _syncRoute();
    });
    ever(showRoute, (_) {
      _syncRoute();
      _syncWaypoints();
    });
    ever(routePoints, (_) {
      _syncWaypoints();
    });
    ever(selectedScheduleId, (_) {
      _syncWaypoints();
      // Handle Schedule Change for Fog:
      // 1. Invalidate current build immediately
      _fogGenerationId++;
      _lastFogGeoJson = null;
      // 2. Revert to solid Fog while new data loads ONLY if no current position
      if (_latestPosition == null || !showFootprints.value) {
        _syncFogGeoJson(jsonEncode({
          "type": "Polygon",
          "coordinates": [
            [
              [-180.0, -85.051129],
              [180.0, -85.051129],
              [180.0, 85.051129],
              [-180.0, 85.051129],
              [-180.0, -85.051129]
            ]
          ]
        }));
      }
      // Footprint data will be updated by loadFootprints(), triggering ever(footprints)
    });
    ever(footprints, (_) => _scheduleFogMaskBuild());
    ever(showFootprints, (_) => _setFogVisibility());
    ever(heatPoints, (_) => _syncHeatmap());
    ever(showHeatmap, (_) => _syncHeatmap());
  }

  @override
  void onClose() {
    _isDisposed = true;
    _pingTimer?.cancel();
    _friendsTimer?.cancel();
    _footprintsTimer?.cancel();
    _heatmapDebounce?.cancel();
    _fogDebounceTimer?.cancel();
    _viewportMomentDebounce?.cancel();
    _positionStreamSubscription?.cancel();
    unawaited(_signalR.disconnectTracking());
    if (!heatmapResetController.isClosed) heatmapResetController.close();
    if (!cameraUpdateStream.isClosed) cameraUpdateStream.close();
    try {} catch (_) {/* đã dispose hoặc chưa mount */}
    super.onClose();
  }

  /// Được gọi từ FlutterMap.onMapReady ở View.
  void onMapReady() {
    isMapReady.value = true;
    if (_pendingFit != null) {
      final pts = _pendingFit!;
      _pendingFit = null;
      _fitCamera(pts);
    }
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;
    try {
      await _orderController.fetchEligibleSchedules();
      eligibleSchedules.assignAll(_orderController.eligibleSchedules);
      if (eligibleSchedules.isNotEmpty) {
        await selectSchedule(eligibleSchedules.first.scheduleId);
      } else {
        // Không có tour: vẫn hiện bạn bè đang chia sẻ vị trí và tải heatmap/timeline toàn cầu.
        await Future.wait([
          _loadFriendsLive(),
          loadMapMoments(null),
        ]);
        _fitToLiveLocations();
      }
      _startFriendsPolling();
      // Khôi phục trạng thái chia sẻ vị trí theo cài đặt đã lưu của người dùng
      if (_storage.shareMyLocation) {
        unawaited(_startAutoTracking());
      }
      // Tự động di chuyển camera về vị trí bản thân khi mở bản đồ
      unawaited(recenter());
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Failed to load map data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Poll vị trí bạn bè định kỳ để mô phỏng real-time (fallback cạnh SignalR).
  void _startFriendsPolling() {
    _friendsTimer?.cancel();
    _friendsTimer = Timer.periodic(
      _friendsRefreshInterval,
      (_) => _loadFriendsLive(),
    );
  }

  /// Tạo link chia sẻ vị trí cá nhân (gửi cho bạn bè / người thân theo dõi web).
  Future<String?> generateShareLink() async {
    try {
      final myLoc = await LocationHelper.getCurrentPosition();
      if (myLoc != null) {
        await _service.pingLocation(
          lat: myLoc.latitude, 
          lng: myLoc.longitude
        );
      }
      
      final token = await _service.generateTrackingToken();
      if (token.isEmpty) return null;
      return token;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Error generating tracking link: $e');
    }
    return null;
  }

  // ======================= SCHEDULE SELECTION =======================
  Future<void> selectSchedule(int scheduleId) async {
    if (selectedScheduleId.value == scheduleId && liveLocations.isNotEmpty) {
      return;
    }
    // Hủy background image load cũ trước khi đổi schedule
    _imageLoadGeneration++;
    _uploadedImageIds.clear();
    _lastMomentSignature = "";

    selectedScheduleId.value = scheduleId;
    isLoading.value = true;

    routeDays.clear();
    routePoints.clear();
    _allItineraryPoints.clear();
    _waypointMarkerCache.clear();
    selectedDay.value = null;
    drivingRouteLatLngs.clear();

    try {
      if (scheduleId > 0) {
        await Future.wait([
          _loadScheduleLive(scheduleId),
          _loadFriendsLive(),
          loadMapMoments(scheduleId),
          _loadItineraries(scheduleId),
        ]);
        await _connectRealtime(scheduleId);
      } else {
        // All Trips: Clear schedule-specific live locations, load friends and all moments
        liveLocations.clear();
        await Future.wait([
          _loadFriendsLive(),
          loadMapMoments(null),
        ]);
        await _signalR.disconnectTracking();
      }
      _fitToLiveLocations();

      _footprintRequestGeneration++;

      isHeatmapLoading.value = false;
      isFootprintsLoading.value = false;

      // Clear stale heatmap/footprint data unconditionally when schedule changes
      heatPoints.clear();
      footprints.clear();

      if (showHeatmap.value) {
        unawaited(loadHeatmap());
      }
      if (showFootprints.value) {
        unawaited(loadFootprints());
      }
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Error loading schedule: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ======================= 1) LIVE LOCATION LOGIC =======================
  Future<void> _loadScheduleLive(int scheduleId) async {
    final data = await _service.getScheduleLiveLocations(scheduleId);
    _mergeLiveLocations(data);
  }

  Future<void> _loadFriendsLive() async {
    try {
      final data = await _service.getLiveFriendsLocations();
      _mergeLiveLocations(data);
    } catch (_) {}
  }

  void _mergeLiveLocations(List<LiveLocationModel> incoming) {
    final map = {for (final l in liveLocations) l.userId: l};
    for (final l in incoming) {
      if (_isLocationVisible(l)) {
        map[l.userId] = l;
      }
    }
    liveLocations.assignAll(map.values);
  }

  Future<void> _connectRealtime(int scheduleId) async {
    await _signalR.disconnectTracking();
    await _signalR.connectTracking(onLocationUpdate: _onRealtimeLocation);
    await _signalR.joinTourTrackingGroup(scheduleId);
  }

  void _onRealtimeLocation(LiveLocationModel loc) {
    if (!_isLocationVisible(loc)) return;
    final idx = liveLocations.indexWhere((l) => l.userId == loc.userId);
    if (idx >= 0) {
      liveLocations[idx] = loc;
    } else {
      liveLocations.add(loc);
    }
    liveLocations.refresh();
  }

  /// Bật/tắt chia sẻ vị trí của tôi cho nhóm tour.
  /// Bật/tắt ghi log di chuyển realtime + chia sẻ vị trí của tôi.
  Future<void> toggleShareMyLocation() async {
    if (isSharingLocation.value) {
      _stopSharing();
      await _storage.setShareMyLocation(false);
      SnackbarHelper.success('Location sharing and tracking turned off');
      return;
    }
    final ok = await _startAutoTracking(notify: true);
    if (ok) {
      await _storage.setShareMyLocation(true);
      SnackbarHelper.success('Sharing and tracking your journey live');
    }
  }

  Position? _lastFogBuildPosition;

  void _evaluateLocationStream() async {
    final needsStream = isSharingLocation.value || showFootprints.value;
    if (needsStream) {
      if (_positionStreamSubscription == null) {
        final granted = await LocationHelper.ensurePermission();
        if (!granted) return;

        try {
          final initialPos = await Geolocator.getLastKnownPosition();
          if (initialPos != null) {
            _latestPosition = initialPos;
            _onLocationUpdated(initialPos);
          }
        } catch (_) {}

        LocationSettings locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );

        if (defaultTargetPlatform == TargetPlatform.android) {
          locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            forceLocationManager: true,
            intervalDuration: const Duration(seconds: 10),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationText: "StayHub is tracking your location in background.",
              notificationTitle: "StayHub Location Tracking",
              enableWakeLock: true,
            ),
          );
        }

        _positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position pos) {
          _latestPosition = pos;
          _onLocationUpdated(pos);
        }, onError: (_) {});
      }
    } else {
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
    }
  }

  Timer? _fogDebounceTimer;
  void _debounceFogBuild() {
    _fogDebounceTimer?.cancel();
    _fogDebounceTimer = Timer(const Duration(milliseconds: 750), () {
      _scheduleFogMaskBuild();
    });
  }

  void _onLocationUpdated(Position pos) {
    if (isSharingLocation.value) {
      final here = LatLng(pos.latitude, pos.longitude);
      _appendTrail(here);
      _updateMyLiveMarker(here);
    }
    if (showFootprints.value) {
      if (_lastFogBuildPosition == null) {
        _debounceFogBuild();
      } else {
        final dist = Geolocator.distanceBetween(
          _lastFogBuildPosition!.latitude,
          _lastFogBuildPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (dist >= 75) {
          _debounceFogBuild();
        }
      }
    }
  }

  /// Bắt đầu ghi log di chuyển realtime (cào map liên tục). Trả về true nếu
  /// được cấp quyền và đã khởi động vòng ping.
  Future<bool> _startAutoTracking({bool notify = false}) async {
    if (isSharingLocation.value) return true;
    final granted = await LocationHelper.ensurePermission();
    if (!granted) {
      if (notify) {
        SnackbarHelper.error(
            'Location permission is required for tracking and sharing');
      }
      return false;
    }
    isSharingLocation.value = true;

    _evaluateLocationStream();

    // Gửi vị trí lên server định kỳ 12s/lần nhưng chỉ gửi khi có toạ độ mới
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _pingLatestToServer());

    return true;
  }

  void _stopSharing() {
    _pingTimer?.cancel();
    _pingTimer = null;
    isSharingLocation.value = false;
    _evaluateLocationStream();
  }

  /// Gửi vị trí lên server định kỳ 5s/lần để tracking liên tục thời gian thực
  Future<void> _pingLatestToServer() async {
    final pos = _latestPosition;
    if (pos == null) return;

    try {
      await _service.pingLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        scheduleId: selectedScheduleId.value,
      );
    } catch (_) {}
  }

  /// Thêm điểm vào vệt nếu đã đi đủ xa; tự giới hạn số điểm để nhẹ bộ nhớ.
  void _appendTrail(LatLng p) {
    if (_lastTrailPoint != null) {
      final meters = _distance.as(LengthUnit.Meter, _lastTrailPoint!, p);
      if (meters < _minTrailMeters) return;
    }
    _lastTrailPoint = p;
    liveTrail.add(p);
    if (liveTrail.length > _maxTrailPoints) {
      liveTrail.removeRange(0, liveTrail.length - _maxTrailPoints);
    }
    // Nếu heatmap đang bật và đang dùng dữ liệu client, làm tươi nhẹ nhàng.
    if (showHeatmap.value) _scheduleHeatmapReset();
  }

  /// Phản chiếu vị trí của chính mình vào danh sách marker live (nếu model hỗ trợ).
  void _updateMyLiveMarker(LatLng here) {
    try {
      final idx = liveLocations.indexWhere((l) => l.userId == currentUserId);
      if (idx >= 0) {
        // Một số model là immutable -> bỏ qua nếu không cập nhật được.
        liveLocations.refresh();
      }
    } catch (_) {}
  }

  // ======================= 2) MOMENTS ON MAP =======================
  int _momentRequestGeneration = 0;
  /// Debounce timer for viewport-based moment loading (fires after camera stops moving)
  Timer? _viewportMomentDebounce;
  /// Tracks the last bounding box fetched to avoid redundant requests
  String _lastViewportSignature = '';
  /// Zoom threshold above which viewport loading kicks in
  static const double _viewportLoadZoomThreshold = 8.0;
  Future<void> loadMapMoments(int? scheduleId) async {
    final requestGeneration = ++_momentRequestGeneration;
    final requestedScheduleId = selectedScheduleId.value;
    _lastViewportSignature = ''; // reset viewport cache on full reload

    try {
      if (scheduleId != null && scheduleId > 0) {
        // === Specific tour: single request — backend already filters by scheduleId ===
        final data = await _service.getMomentsWithLocation(scheduleId: scheduleId, top: 200);
        if (requestGeneration != _momentRequestGeneration ||
            selectedScheduleId.value != requestedScheduleId) return;
        mapMoments.assignAll(data);
      } else {
        // === All Trips: Two-Track Priority Loading ===
        // Track A: User's OWN moments (always guaranteed, not sharing pool with social)
        // Track B: Social moments from others (capped at 100 to avoid drowning out Track A)
        final results = await Future.wait([
          _service.getUserMoments(currentUserId!),           // Track A
          _service.getMomentsWithLocation(top: 100),         // Track B
        ]);

        if (requestGeneration != _momentRequestGeneration ||
            selectedScheduleId.value != requestedScheduleId) return;

        // Merge: A ∪ B, deduplicate by id, filter for map-ready (has lat/lng)
        final mine = results[0].where((m) => m.lat != null && m.lng != null);
        final social = results[1]; // already filtered by getMomentsWithLocation
        final seenIds = <int>{};
        final merged = <MomentModel>[];
        // My moments first (priority)
        for (final m in mine) {
          if (seenIds.add(m.id)) merged.add(m);
        }
        // Then social fill
        for (final m in social) {
          if (seenIds.add(m.id)) merged.add(m);
        }
        mapMoments.assignAll(merged);
      }
    } catch (e) {
      if (kDebugMode || kProfileMode) {
        debugPrint('MAP_RENDER_ERROR: loadMapMoments failed: $e');
      }
    }
  }

  /// Viewport-based progressive loading — called when camera stops at zoom >= 8.
  /// Loads additional moments in the current visible bounding box and merges
  /// them into mapMoments without replacing existing data.
  Future<void> _loadMomentsInViewport() async {
    if (_isDisposed || mapboxMap == null) return;
    try {
      final bounds = await mapboxMap!.coordinateBoundsForCamera(
        await mapboxMap!.getCameraState().then(
          (s) => mb.CameraOptions(
            center: s.center,
            zoom: s.zoom,
            bearing: s.bearing,
            pitch: s.pitch,
          ),
        ),
      );
      final minLat = bounds.southwest.coordinates.lat.toDouble();
      final maxLat = bounds.northeast.coordinates.lat.toDouble();
      final minLng = bounds.southwest.coordinates.lng.toDouble();
      final maxLng = bounds.northeast.coordinates.lng.toDouble();

      // Skip if viewport hasn't changed significantly (0.05° ≈ 5km tolerance)
      final sig = '${minLat.toStringAsFixed(2)},${maxLat.toStringAsFixed(2)},'
          '${minLng.toStringAsFixed(2)},${maxLng.toStringAsFixed(2)}'
          '|${selectedScheduleId.value}';
      if (sig == _lastViewportSignature) return;
      _lastViewportSignature = sig;

      final incoming = await _service.getMomentsInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        scheduleId: selectedScheduleId.value,
        top: 100,
      );

      if (_isDisposed) return;

      // Merge into existing moments (don't replace — progressive add)
      final existingIds = mapMoments.map((m) => m.id).toSet();
      final newOnes = incoming.where((m) => !existingIds.contains(m.id)).toList();
      if (newOnes.isNotEmpty) {
        mapMoments.addAll(newOnes);
        debugPrint('VIEWPORT_LOAD: +${newOnes.length} moments in bbox [$sig]');
      }
    } catch (e) {
      if (kDebugMode || kProfileMode) {
        debugPrint('MAP_RENDER_ERROR: _loadMomentsInViewport failed: $e');
      }
    }
  }

  // ======================= 3) TOUR ROUTE (POLYLINE) =======================
  Future<void> _loadItineraries(int scheduleId) async {
    isRouteLoading.value = true;
    try {
      final points = await _service.getScheduleItineraries(scheduleId);
      _allItineraryPoints
        ..clear()
        ..addAll(points);

      // Gom thành danh sách các Ngày (distinct theo dayNumber).
      final byDay = <int, RouteDayModel>{};
      for (final p in points) {
        byDay.putIfAbsent(
          p.dayNumber,
          () => RouteDayModel(
            dayNumber: p.dayNumber,
            title: 'Day ${p.dayNumber}',
          ),
        );
      }
      final sorted = byDay.values.toList()
        ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      routeDays.assignAll(sorted);

      if (sorted.isNotEmpty) {
        await selectDay(null); // Default to Overview (all days route)
      }
    } catch (_) {
      // tour chưa có lộ trình -> bỏ qua, không chặn các lớp khác
    } finally {
      isRouteLoading.value = false;
    }
  }

  /// Lọc các điểm của 1 ngày hoặc toàn bộ lộ trình nếu dayNumber là null (Overview).
  Future<void> selectDay(int? dayNumber) async {
    selectedDay.value = dayNumber;

    final List<RoutePointModel> pts;
    if (dayNumber == null) {
      // Overview mode: Show all itineraries
      pts = List<RoutePointModel>.from(_allItineraryPoints);
    } else {
      pts = _allItineraryPoints.where((p) => p.dayNumber == dayNumber).toList();
    }

    // Sort chronologically: by day number first, then order sequence
    pts.sort((a, b) => a.dayNumber == b.dayNumber
        ? a.order.compareTo(b.order)
        : a.dayNumber.compareTo(b.dayNumber));

    routePoints.assignAll(pts);

    // Fetch actual Mapbox driving route
    final waypoints = routeLatLngs;
    if (waypoints.isNotEmpty) {
      try {
        isRouteLoading.value = true;
        final actualRoute = await _service.getDrivingRoute(waypoints);
        drivingRouteLatLngs
            .assignAll(actualRoute.isNotEmpty ? actualRoute : waypoints);
      } catch (e) {
        drivingRouteLatLngs.assignAll(waypoints); // Fallback to straight lines
      } finally {
        isRouteLoading.value = false;
      }
    } else {
      drivingRouteLatLngs.clear();
    }

    fitToRoute();
  }

  // ======================= 4) FOOTPRINTS ("CÀO MAP") =======================
  Future<void> toggleFootprints() async {
    showFootprints.toggle();
    _evaluateLocationStream();
    if (showFootprints.value) {
      if (footprints.isEmpty) await loadFootprints();
      _footprintsTimer?.cancel();
      _footprintsTimer = Timer.periodic(
        _footprintsRefreshInterval,
        (_) => loadFootprints(silent: true),
      );
      if (mapboxMap != null) {
        try {
          await mapboxMap!.gestures.updateSettings(
            mb.GesturesSettings(pitchEnabled: false),
          );
          final camera = await mapboxMap!.getCameraState();
          if (camera.pitch != 0.0) {
            await mapboxMap!.setCamera(mb.CameraOptions(pitch: 0.0));
          }
        } catch (_) {}
      }
      _scheduleFogMaskBuild();
    } else {
      _footprintsTimer?.cancel();
      _footprintsTimer = null;
      if (mapboxMap != null) {
        try {
          await mapboxMap!.gestures.updateSettings(
            mb.GesturesSettings(pitchEnabled: true),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> loadFootprints({bool silent = false}) async {
    final requestGeneration = ++_footprintRequestGeneration;
    final requestedScheduleId = selectedScheduleId.value;

    if (!silent) isFootprintsLoading.value = true;
    try {
      final apiScheduleId =
          (requestedScheduleId != null && requestedScheduleId > 0)
              ? requestedScheduleId
              : null;
      final data = await _service.getMyFootprints(
        scheduleId: apiScheduleId,
      );

      if (requestGeneration != _footprintRequestGeneration ||
          selectedScheduleId.value != requestedScheduleId) {
        debugPrint(
            'FOOTPRINT_STALE_RESPONSE_IGNORED: schedule=$requestedScheduleId');
        return;
      }

      footprints.assignAll(data);
      if (data.isEmpty && !silent && liveTrail.isEmpty) {
        SnackbarHelper.success(
            'No footprints recorded yet — start moving to map your path');
      }
    } on ApiError catch (e) {
      if (requestGeneration != _footprintRequestGeneration ||
          selectedScheduleId.value != requestedScheduleId) {
        debugPrint(
            'FOOTPRINT_STALE_ERROR_IGNORED: schedule=$requestedScheduleId');
        return;
      }
      if (!silent) SnackbarHelper.error(e.message);
    } catch (e) {
      if (requestGeneration != _footprintRequestGeneration ||
          selectedScheduleId.value != requestedScheduleId) {
        debugPrint(
            'FOOTPRINT_STALE_ERROR_IGNORED: schedule=$requestedScheduleId');
        return;
      }
      if (!silent) SnackbarHelper.error('Error loading footprints: $e');
    } finally {
      if (requestGeneration == _footprintRequestGeneration &&
          selectedScheduleId.value == requestedScheduleId) {
        isFootprintsLoading.value = false;
      }
    }
  }

  List<dynamic> get bumpHexPolygons {
    return const [];
  }

  // ======================= 5) HEATMAP =======================
  Future<void> toggleHeatmap() async {
    showHeatmap.toggle();
    if (showHeatmap.value && heatPoints.isEmpty) {
      await loadHeatmap();
    } else if (showHeatmap.value) {
      _scheduleHeatmapReset();
    }
  }

  /// Ưu tiên gọi service; nếu lỗi (vd 404) thì dựng heatmap client-side từ
  /// dữ liệu sẵn có (moments + footprints + live locations).
  Future<void> loadHeatmap() async {
    if (_isSyncing) return;
    isHeatmapLoading.value = true;
    try {
      final scheduleId = selectedScheduleId.value;
      final apiScheduleId =
          (scheduleId != null && scheduleId > 0) ? scheduleId : null;
      final data = await _service.getHeatmapData(
        scheduleId: apiScheduleId,
        type: heatmapType.value,
      );
      heatPoints.assignAll(data);
    } catch (e) {
      // Fallback: Client-side generation since backend might not have this endpoint
      final clientPoints = <HeatPointModel>[];
      
      if (heatmapType.value == 'moments') {
        for (final m in mapMoments) {
          if (m.lat != null && m.lng != null && _isValidCoordinate(m.lat!, m.lng!)) {
            clientPoints.add(HeatPointModel(lat: m.lat!, lng: m.lng!, weight: 1.0));
          }
        }
      } else if (heatmapType.value == 'online') {
        for (final loc in liveLocations) {
          if (_isValidCoordinate(loc.latitude, loc.longitude)) {
             clientPoints.add(HeatPointModel(lat: loc.latitude, lng: loc.longitude, weight: 2.0));
          }
        }
      }
      
      heatPoints.assignAll(clientPoints);
      debugPrint('Fallback to client-side heatmap with ${clientPoints.length} points due to: $e');
    } finally {
      _scheduleHeatmapReset();
      isHeatmapLoading.value = false;
    }
  }

  /// Debounce việc reset heatmap để tránh rebuild liên tục gây giật.
  void _scheduleHeatmapReset() {
    _heatmapDebounce?.cancel();
    _heatmapDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!heatmapResetController.isClosed) heatmapResetController.add(null);
    });
  }

  Future<void> _syncLiveLocations() async {
    if (_isSyncing) return;
    try {
      if (liveLocManager == null) return;
      await liveLocManager!.deleteAll();

      // Placeholder for now
    } catch (e, stack) {
      debugPrint('MAP_RENDER_ERROR: Error in _syncLiveLocations: $e\n$stack');
    }
  }

  String _lastMomentSignature = "";

  Future<void> _ensureMomentSourceAndLayers() async {
    if (mapboxMap == null) return;
    try {
      final style = mapboxMap!.style;

      // Load Moment Camera Icon to Style
      if (!await style.hasStyleImage("stayhub-moment-icon")) {
        final markerData = await MarkerGenerator.createMomentMarker();
        if (markerData != null) {
          await style.addStyleImage(
            "stayhub-moment-icon",
            4.0,
            mb.MbxImage(
              width: markerData.width,
              height: markerData.height,
              data: markerData.data,
            ),
            false,
            [],
            [],
            null,
          );
        }
      }

      if (!await style.styleSourceExists("stayhub-moments-source")) {
        await style.addSource(mb.GeoJsonSource(
          id: "stayhub-moments-source",
          data: '{"type":"FeatureCollection","features":[]}',
          cluster: true,
          clusterRadius: 80,
          // SDK 2.27.0 clusterMaxZoom indicates up to what zoom level to cluster.
          // Set to 19 to match Web's maxZoom: 19
          clusterMaxZoom: 19,
          // maxzoom: Ensure points don't disappear at high zoom levels
          maxzoom: 24.0,
        ));
      }

      if (!await style.styleLayerExists("stayhub-moment-clusters")) {
        await style.addLayer(mb.CircleLayer(
          id: "stayhub-moment-clusters",
          sourceId: "stayhub-moments-source",
          filter: ["has", "point_count"],
          circleColor: 0xFF2196F3,
          circleRadius: 20.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: 0xFFFFFFFF,
        ));
      }

      if (!await style.styleLayerExists("stayhub-moment-cluster-count")) {
        await style.addLayer(mb.SymbolLayer(
          id: "stayhub-moment-cluster-count",
          sourceId: "stayhub-moments-source",
          filter: ["has", "point_count"],
          textField: "{point_count}",
          textFont: ["Open Sans Bold", "Arial Unicode MS Bold"],
          textSize: 12.0,
          textColor: 0xFFFFFFFF,
        ));
        // Override text-field with a smart expression via raw JSON:
        // shows "100+" for ≥100, "10+" for ≥10, exact digit for <10
        await style.setStyleLayerProperty(
          "stayhub-moment-cluster-count",
          "text-field",
          jsonEncode([
            "case",
            [">=", ["get", "point_count"], 100], "100+",
            [">=", ["get", "point_count"], 10], "10+",
            ["to-string", ["get", "point_count"]]
          ]),
        );
      }

      if (!await style.styleLayerExists("stayhub-moment-unclustered")) {
        await style.addLayer(mb.SymbolLayer(
          id: "stayhub-moment-unclustered",
          sourceId: "stayhub-moments-source",
          filter: [
            "!",
            ["has", "point_count"]
          ],
          iconImage: "{imageId}",
          iconSize: 0.45,
          iconAnchor: mb.IconAnchor.BOTTOM,
          iconAllowOverlap: true,
        ));
      }
    } catch (e) {
      debugPrint('MAP_RENDER_ERROR: _ensureMomentSourceAndLayers failed: $e');
    }
  }

  Future<void> _syncMomentsGeoJson() async {
    // Guard 1: onStyleLoaded đang chạy → skip
    if (_isSyncing || mapboxMap == null || !isMapReady.value) return;
    // Guard 2: Mutex riêng, ngăn concurrent calls từ ever(mapMoments) + ever(showMoments)
    if (_isSyncingMoments) return;
    _isSyncingMoments = true;

    try {
      if (!showMoments.value || mapMoments.isEmpty) {
        try {
          if (mapboxMap == null) return;
          await mapboxMap!.style.setStyleSourceProperty(
              "stayhub-moments-source",
              "data",
              '{"type":"FeatureCollection","features":[]}');
        } catch (_) {}
        return;
      }

      // Deduplicate by momentId (CPU only — không có async)
      final Map<int, MomentModel> uniqueMoments = {};
      for (final m in mapMoments) {
        if (!uniqueMoments.containsKey(m.id)) uniqueMoments[m.id] = m;
      }
      final sortedIds = uniqueMoments.keys.toList()..sort();

      // Signature check — bỏ qua nếu data không đổi
      final StringBuffer sigBuilder = StringBuffer();
      sigBuilder.write(selectedScheduleId.value?.toString() ?? "null");
      sigBuilder.write("|");
      for (final id in sortedIds) {
        final m = uniqueMoments[id]!;
        sigBuilder.write("${m.id}:${m.lat}:${m.lng},");
      }
      final newSig = sigBuilder.toString();
      if (newSig == _lastMomentSignature) return;
      _lastMomentSignature = newSig;

      // ── PHASE 1 (NGAY LẬP TỨC): Build và push GeoJSON không chờ ảnh ───────────
      // Mội feature dùng imageId riêng (đã upload thì hiện ảnh, chưa upload thì
      // Mapbox tự fallback về stayhub-moment-icon — hiện camera pin ngay).
      final features = <Map<String, dynamic>>[];
      for (final id in sortedIds) {
        final m = uniqueMoments[id]!;
        if (m.lat == null ||
            m.lng == null ||
            !_isValidCoordinate(m.lat!, m.lng!)) {
          continue;
        }
        final imageId = "moment_img_${m.id}";
        features.add({
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [m.lng, m.lat]
          },
          "properties": {
            "momentId": m.id,
            "scheduleId": m.scheduleId,
            // Nếu ảnh chưa upload: sử dụng shared camera icon làm fallback
            "imageId":
                _uploadedImageIds.contains(imageId) ? imageId : "stayhub-moment-icon",
          }
        });
      }

      final geoJson = jsonEncode({
        "type": "FeatureCollection",
        "features": features,
      });

      if (mapboxMap == null) return; // Safety check trước native call
      try {
        if (await mapboxMap!.style
            .styleSourceExists("stayhub-moments-source")) {
          await mapboxMap!.style
              .setStyleSourceProperty("stayhub-moments-source", "data", geoJson);
        } else {
          await _ensureMomentSourceAndLayers();
          if (mapboxMap == null) return;
          await mapboxMap!.style
              .setStyleSourceProperty("stayhub-moments-source", "data", geoJson);
        }
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: _syncMomentsGeoJson push failed: $e');
        return;
      }

      // ── PHASE 2 (NỀN): Tải ảnh bất đồng bộ, không block UI ─────────────────
      // Chỉ tải những moment chưa có ảnh trong cache.
      final needsPhoto = sortedIds
          .map((id) => uniqueMoments[id]!)
          .where((m) =>
              m.lat != null &&
              m.lng != null &&
              _isValidCoordinate(m.lat!, m.lng!) &&
              !_uploadedImageIds.contains("moment_img_${m.id}"))
          .toList();

      if (needsPhoto.isNotEmpty) {
        // Fire-and-forget: không await, chạy nền sau khi GeoJSON đã hiện
        unawaited(_loadMomentImagesInBackground(
          needsPhoto,
          uniqueMoments: uniqueMoments,
          sortedIds: sortedIds,
          generation: _imageLoadGeneration,
        ));
      }
    } finally {
      // Luôn release mutex dù có exception — tránh deadlock
      _isSyncingMoments = false;
    }
  }

  /// Tải ảnh moment bất đồng bộ và cập nhật GeoJSON khi mỗi ảnh sẵn sàng.
  ///
  /// - Mỗi ảnh tải xong → upload vào Mapbox style → push GeoJSON mới (có ảnh)
  /// - Kiểm tra [generation] — nếu schedule đã thay đổi thì dừng lại ngay.
  /// - Kiểm tra [_isDisposed] sau mỗi await — tránh gọi Mapbox sau dispose.
  Future<void> _loadMomentImagesInBackground(
    List<MomentModel> moments, {
    required Map<int, MomentModel> uniqueMoments,
    required List<int> sortedIds,
    required int generation,
  }) async {
    for (final m in moments) {
      // Dừng nếu schedule đã thay đổi hoặc controller đã dispose
      if (generation != _imageLoadGeneration || _isDisposed) return;

      final imageId = "moment_img_${m.id}";
      if (_uploadedImageIds.contains(imageId)) continue;

      // Download + render marker (có thể mất 200-800ms mỗi ảnh)
      ({Uint8List data, int width, int height})? markerData;
      try {
        markerData = await MarkerGenerator.createMomentMarker(m.imageUrl);
      } catch (_) {}

      // Kiểm tra sau await (controller có thể đã dispose trong lúc chờ)
      if (generation != _imageLoadGeneration || _isDisposed || mapboxMap == null) return;

      if (markerData == null) continue;

      // Upload ảnh vào Mapbox style (tuần tự — an toàn)
      try {
        if (!await mapboxMap!.style.hasStyleImage(imageId)) {
          await mapboxMap!.style.addStyleImage(
            imageId, 1.0,
            mb.MbxImage(
              width: markerData.width,
              height: markerData.height,
              data: markerData.data,
            ),
            false, [], [], null,
          );
        }
        _uploadedImageIds.add(imageId);
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: bg addStyleImage failed: $e');
        continue;
      }

      // Kiểm tra lần nữa trước push GeoJSON
      if (generation != _imageLoadGeneration || _isDisposed || mapboxMap == null) return;

      // Push GeoJSON cập nhật: thay ảnh của riêng moment này từ fallback → ảnh thật
      try {
        final updatedFeatures = <Map<String, dynamic>>[];
        for (final id in sortedIds) {
          final mo = uniqueMoments[id]!;
          if (mo.lat == null || mo.lng == null || !_isValidCoordinate(mo.lat!, mo.lng!)) continue;
          final fImageId = "moment_img_${mo.id}";
          updatedFeatures.add({
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [mo.lng, mo.lat]
            },
            "properties": {
              "momentId": mo.id,
              "scheduleId": mo.scheduleId,
              "imageId": _uploadedImageIds.contains(fImageId)
                  ? fImageId
                  : "stayhub-moment-icon",
            }
          });
        }
        final updatedGeoJson = jsonEncode({
          "type": "FeatureCollection",
          "features": updatedFeatures,
        });
        if (await mapboxMap!.style.styleSourceExists("stayhub-moments-source")) {
          await mapboxMap!.style.setStyleSourceProperty(
              "stayhub-moments-source", "data", updatedGeoJson);
        }
      } catch (e) {
        debugPrint('MAP_RENDER_ERROR: bg GeoJSON push failed: $e');
      }
    }
  }

  void handleMapTap(mb.MapContentGestureContext context) async {
    if (mapboxMap == null) return;
    try {
      final touchPos = context.touchPosition;
      final queryBox = mb.ScreenBox(
        min: mb.ScreenCoordinate(x: touchPos.x - 20, y: touchPos.y - 20),
        max: mb.ScreenCoordinate(x: touchPos.x + 20, y: touchPos.y + 20),
      );
      final features = await mapboxMap!.queryRenderedFeatures(
        mb.RenderedQueryGeometry.fromScreenBox(queryBox),
        mb.RenderedQueryOptions(
          layerIds: ['stayhub-moment-clusters', 'stayhub-moment-unclustered'],
          filter: null,
        ),
      );

      if (features.isNotEmpty) {
        // Priority 1: Check if any tapped feature is a cluster
        final clusterFeature = features.firstWhere((f) {
          final p =
              f?.queriedFeature.feature['properties'] as Map<dynamic, dynamic>?;
          return p != null && p.containsKey('cluster') && p['cluster'] == true;
        }, orElse: () => null);

        if (clusterFeature != null) {
          // Tap on cluster
          final props = clusterFeature!.queriedFeature.feature['properties']
              as Map<dynamic, dynamic>;
          final clusterId = props['cluster_id'];
          if (clusterId != null) {
            // SDK 2.27.0 does not natively expose getGeoJsonClusterExpansionZoom
            // Fallback: simply zoom in by +2
            final state = await mapboxMap!.getCameraState();
            final geom = clusterFeature.queriedFeature.feature['geometry']
                as Map<dynamic, dynamic>;
            if (geom['type'] == 'Point') {
              final coords = geom['coordinates'] as List<dynamic>;
              mapboxMap!.flyTo(
                mb.CameraOptions(
                  center:
                      mb.Point(coordinates: mb.Position(coords[0], coords[1])),
                  zoom: state.zoom + 2,
                ),
                mb.MapAnimationOptions(duration: 300),
              );
            }
          }
        } else {
          // Tap on unclustered moment(s)
          final unclusteredProps = features
              .map((f) => f?.queriedFeature.feature['properties']
                  as Map<dynamic, dynamic>?)
              .where((p) => p != null && p.containsKey('momentId'))
              .toList();

          if (unclusteredProps.isNotEmpty) {
            final momentIds = unclusteredProps
                .map((p) => int.parse(p!['momentId'].toString()))
                .toSet()
                .toList();
            final overlappingMoments = momentIds
                .map((id) => mapMoments.firstWhereOrNull((m) => m.id == id))
                .whereType<MomentModel>()
                .toList();

            if (overlappingMoments.isEmpty) return;

            HapticFeedback.selectionClick();
            if (overlappingMoments.length == 1) {
              Get.toNamed('/moment-detail',
                  arguments: overlappingMoments.first);
            } else {
              // Multiple overlapping moments, show a selection sheet
              Get.bottomSheet(
                Container(
                  color: Colors.white,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: overlappingMoments.length,
                    itemBuilder: (context, index) {
                      final m = overlappingMoments[index];
                      return ListTile(
                        leading: m.imageUrl.isNotEmpty
                            ? Image.network(m.imageUrl,
                                width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.camera_alt),
                        title: Text(m.caption?.isNotEmpty == true
                            ? m.caption!
                            : 'Moment ${m.id}'),
                        subtitle: const Text('Click to view details'),
                        onTap: () {
                          Get.back();
                          Get.toNamed('/moment-detail', arguments: m);
                        },
                      );
                    },
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('MAP_RENDER_ERROR: Tap handling failed: $e');
    }
  }

  void handleMapLongTap(mb.MapContentGestureContext context) async {
    if (mapboxMap == null) return;
    try {
      final touchPos = context.touchPosition;
      final queryBox = mb.ScreenBox(
        min: mb.ScreenCoordinate(x: touchPos.x - 20, y: touchPos.y - 20),
        max: mb.ScreenCoordinate(x: touchPos.x + 20, y: touchPos.y + 20),
      );
      final features = await mapboxMap!.queryRenderedFeatures(
        mb.RenderedQueryGeometry.fromScreenBox(queryBox),
        mb.RenderedQueryOptions(
          layerIds: ['stayhub-moment-clusters', 'stayhub-moment-unclustered'],
          filter: null,
        ),
      );

      if (features.isNotEmpty) {
        final unclusteredProps = features
            .map((f) => f?.queriedFeature.feature['properties'] as Map<String, dynamic>?)
            .where((p) => p != null && p.containsKey('momentId'))
            .toList();

        if (unclusteredProps.isNotEmpty) {
          final momentIds = unclusteredProps
              .map((p) => int.parse(p!['momentId'].toString()))
              .toSet()
              .toList();
          
          final overlappingMoments = momentIds
              .map((id) => mapMoments.firstWhereOrNull((m) => m.id == id))
              .whereType<MomentModel>()
              .toList();

          if (overlappingMoments.isEmpty) return;
          HapticFeedback.heavyImpact();

          final selectedMoment = overlappingMoments.first;
          
          List<MomentModel> scopedMoments = [];
          if (selectedMoment.scheduleId != null) {
            scopedMoments = mapMoments.where((m) => m.scheduleId == selectedMoment.scheduleId).toList();
            scopedMoments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          } else {
            scopedMoments = [selectedMoment];
          }

          int initialIndex = scopedMoments.indexWhere((m) => m.id == selectedMoment.id);
          if (initialIndex < 0) initialIndex = 0;

          if (overlappingMoments.length == 1) {
            Get.toNamed(
              '/scoped-moment-feed',
              arguments: {
                'moments': scopedMoments,
                'initialIndex': initialIndex,
              },
            );
          } else {
            Get.bottomSheet(
              Container(
                color: Colors.white,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: overlappingMoments.length,
                  itemBuilder: (context, index) {
                    final m = overlappingMoments[index];
                    return ListTile(
                      leading: m.imageUrl.isNotEmpty
                          ? Image.network(m.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.camera_alt),
                      title: Text(m.caption?.isNotEmpty == true ? m.caption! : 'Moment ${m.id}'),
                      subtitle: const Text('Long press to open feed'),
                      onTap: () {
                        Get.back();
                        List<MomentModel> sm = [];
                        if (m.scheduleId != null) {
                          sm = mapMoments.where((x) => x.scheduleId == m.scheduleId).toList();
                          sm.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                        } else {
                          sm = [m];
                        }
                        int idx = sm.indexWhere((x) => x.id == m.id);
                        Get.toNamed(
                          '/scoped-moment-feed',
                          arguments: {
                            'moments': sm,
                            'initialIndex': idx < 0 ? 0 : idx,
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('MAP_RENDER_ERROR: Long tap handling failed: $e');
    }
  }

  bool _isSyncingRoute = false;

  Future<void> _syncRoute() async {
    if (_isSyncing || _isSyncingRoute) return;
    _isSyncingRoute = true;
    debugPrint('ROUTE_SYNC_START');

    try {
      if (routeCasingManager == null || routeDashedCoreManager == null) return;
      await routeCasingManager!.deleteAll();
      await routeDashedCoreManager!.deleteAll();

      if (!showRoute.value || drivingRouteLatLngs.isEmpty) return;
      if (drivingRouteLatLngs.length < 2) return;

      final coords = drivingRouteLatLngs
          .map((l) => mb.Position(l.longitude, l.latitude))
          .toList();
      debugPrint('ROUTE_COORDINATE_COUNT: ${coords.length}');
      final geometry = mb.LineString(coordinates: coords);

      final casingOptions = mb.PolylineAnnotationOptions(
        geometry: geometry,
        lineColor: 0xFF2196F3,
        lineWidth: 6.0,
        lineJoin: mb.LineJoin.ROUND,
      );

      final coreOptions = mb.PolylineAnnotationOptions(
        geometry: geometry,
        lineColor: 0xFFFFFFFF,
        lineWidth: 2.5,
        lineJoin: mb.LineJoin.ROUND,
      );

      await routeCasingManager!.setLineCap(mb.LineCap.ROUND);
      await routeCasingManager!.setLineJoin(mb.LineJoin.ROUND);
      await routeCasingManager!.create(casingOptions);
      debugPrint('ROUTE_CASING_CREATED');

      await routeDashedCoreManager!.setLineCap(mb.LineCap.ROUND);
      await routeDashedCoreManager!.setLineJoin(mb.LineJoin.ROUND);
      await routeDashedCoreManager!.setLineDasharray([2.0, 2.0]);
      await routeDashedCoreManager!.create(coreOptions);
      debugPrint('ROUTE_CORE_CREATED');

      final dashArray = await routeDashedCoreManager!.getLineDasharray();
      debugPrint('ROUTE_DASH_VALUE: $dashArray');
    } catch (e, stack) {
      debugPrint('MAP_RENDER_ERROR: Route sync failed: $e\n$stack');
    } finally {
      _isSyncingRoute = false;
    }
  }

// ======================= CAMERA HELPERS =======================

  Future<void> recenter() async {
    debugPrint('RECENTER_LOCATION');
    final pos = await LocationHelper.getCurrentPosition();
    if (pos != null) {
      _latestPosition = pos;
      _safeMove(LatLng(pos.latitude, pos.longitude), 15);
      await _configureCurrentUserLocationPuck();
    } else {
      SnackbarHelper.error('Unable to access current location');
    }
  }

  Future<void> _configureCurrentUserLocationPuck() async {
    try {
      final granted = await LocationHelper.ensurePermission();
      debugPrint('LOCATION_PERMISSION_STATUS: $granted');
      if (!granted) return;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('LOCATION_SERVICE_STATUS: $serviceEnabled');

      if (mapboxMap != null) {
        await mapboxMap!.location.updateSettings(
          mb.LocationComponentSettings(
            enabled: true,
            pulsingEnabled: true,
            showAccuracyRing: true,
            puckBearingEnabled: true,
            puckBearing: mb.PuckBearing.HEADING,
          ),
        );
        debugPrint('LOCATION_PUCK_ENABLED: true');
        debugPrint('LOCATION_PUCK_HEADING_ENABLED: true');
      }
    } catch (e, stack) {
      debugPrint(
          'MAP_RENDER_ERROR: Error configuring location puck: $e\n$stack');
    }
  }

  bool _isSyncingWaypoints = false;

  Future<void> _syncWaypoints() async {
    if (_isSyncing || _isSyncingWaypoints) return;
    _isSyncingWaypoints = true;
    debugPrint('WAYPOINT_SYNC_START');

    try {
      if (waypointManager == null) return;
      await waypointManager!.deleteAll();

      if (!showRoute.value || _allItineraryPoints.isEmpty) return;

      final allPts = List<RoutePointModel>.from(_allItineraryPoints);
      allPts.sort((a, b) => a.dayNumber == b.dayNumber
          ? a.order.compareTo(b.order)
          : a.dayNumber.compareTo(b.dayNumber));

      final validAllPts =
          allPts.where((p) => _isValidCoordinate(p.lat, p.lng)).toList();

      int globalSeq = 1;
      final globalAssigned = <RoutePointModel, int>{};
      for (final p in validAllPts) {
        globalAssigned[p] = globalSeq++;
      }
      debugPrint('WAYPOINT_INPUT_COUNT: ${validAllPts.length}');

      final visiblePts = validAllPts.where((p) {
        if (selectedDay.value == null) return true;
        return p.dayNumber == selectedDay.value;
      }).toList();

      debugPrint('WAYPOINT_VISIBLE_COUNT: ${visiblePts.length}');

      final List<mb.PointAnnotationOptions> options = [];
      final List<String> labels = [];
      int preparedCount = 0;
      int skippedCount = 0;
      int failedCount = 0;

      for (final p in visiblePts) {
        if (!p.hasCoordinates || !_isValidCoordinate(p.lat, p.lng)) {
          skippedCount++;
          continue;
        }

        final seq = globalAssigned[p]!;
        final label = '$seq. ${p.name}';

        if (kDebugMode || kProfileMode) {
          debugPrint('WAYPOINT_LABEL: $label');
          debugPrint('WAYPOINT_COORDINATE_VALID: true');
        }

        final cacheKey =
            '${selectedScheduleId.value}|${p.dayNumber}|${p.order}|${p.name}';

        Uint8List? markerData = _waypointMarkerCache[cacheKey];
        final bool cacheHit = markerData != null;

        if (kDebugMode || kProfileMode) {
          debugPrint('WAYPOINT_CACHE_HIT: $cacheHit');
        }

        if (!cacheHit) {
          try {
            final marker =
                await MarkerGenerator.createScheduleStopMarker(label);
            if (marker != null) {
              markerData = marker.data;
              _waypointMarkerCache[cacheKey] = markerData;
            }
          } catch (e, stack) {
            if (kDebugMode || kProfileMode) {
              debugPrint(
                  'MAP_RENDER_ERROR: Failed to generate waypoint "$label": $e\n$stack');
            }
          }
        }

        if (markerData == null) {
          failedCount++;
          if (kDebugMode || kProfileMode) {
            debugPrint('WAYPOINT_OPTION_PREPARED: false');
          }
          continue;
        }

        if (kDebugMode || kProfileMode) {
          debugPrint('WAYPOINT_PNG_BYTE_LENGTH: ${markerData.length}');
          debugPrint('WAYPOINT_OPTION_PREPARED: label=$label');
        }

        options.add(mb.PointAnnotationOptions(
          geometry: mb.Point(coordinates: mb.Position(p.lng, p.lat)),
          image: markerData,
          iconAnchor: mb.IconAnchor.BOTTOM,
        ));
        labels.add(label);
        preparedCount++;
      }

      int createdCount = 0;
      if (options.isNotEmpty) {
        await waypointManager!.setIconAllowOverlap(true);
        await waypointManager!.setIconIgnorePlacement(true);

        try {
          final results = await waypointManager!.createMulti(options);
          for (int i = 0; i < options.length; i++) {
            final bool resultReturned = i < results.length;
            final bool success = resultReturned && results[i] != null;

            if (success) {
              createdCount++;
            } else {
              failedCount++;
            }

            if (kDebugMode || kProfileMode) {
              debugPrint(
                'WAYPOINT_MAPBOX_CREATED: '
                'label=${labels[i]}, '
                'resultReturned=$resultReturned, '
                'success=$success',
              );
            }
          }

          if ((kDebugMode || kProfileMode) &&
              results.length != options.length) {
            debugPrint(
              'MAP_RENDER_ERROR: WAYPOINT_RESULT_COUNT_MISMATCH '
              'prepared=${options.length}, returned=${results.length}',
            );
          }
        } catch (e, stack) {
          failedCount += options.length;
          if (kDebugMode || kProfileMode) {
            debugPrint('MAP_RENDER_ERROR: createMulti failed: $e\n$stack');
          }
        }
      }
      debugPrint('WAYPOINT_PREPARED_COUNT: $preparedCount');
      debugPrint('WAYPOINT_CREATED_COUNT: $createdCount');
      debugPrint('WAYPOINT_SKIPPED_COUNT: $skippedCount');
      debugPrint('WAYPOINT_FAILED_COUNT: $failedCount');
    } catch (e, stack) {
      debugPrint('MAP_RENDER_ERROR: Waypoint sync failed: $e\n$stack');
    } finally {
      _isSyncingWaypoints = false;
    }
  }

  bool _isValidCoordinate(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  Future<void> _syncHeatmap() async {
    if (_isSyncing || mapboxMap == null) return;
    try {
      if (!showHeatmap.value || heatPoints.isEmpty) {
        await mapboxMap!.style.setStyleSourceProperty("stayhub-heatmap-source",
            "data", '{"type":"FeatureCollection","features":[]}');
        debugPrint('HEATMAP_VISIBLE: false (or empty)');
        return;
      }

      final features = <Map<String, dynamic>>[];
      int validCount = 0;
      int invalidCount = 0;
      for (final p in heatPoints) {
        if (_isValidCoordinate(p.lat, p.lng)) {
          double weight = p.weight;
          if (weight < 0 || weight.isNaN || weight.isInfinite) weight = 0;

          features.add({
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [p.lng, p.lat]
            },
            "properties": {"weight": weight}
          });
          validCount++;
        } else {
          invalidCount++;
        }
      }

      debugPrint('HEATMAP_INPUT_COUNT: ${heatPoints.length}');
      debugPrint('HEATMAP_VALID_COUNT: $validCount');
      debugPrint('HEATMAP_INVALID_COUNT: $invalidCount');

      final geoJson =
          jsonEncode({"type": "FeatureCollection", "features": features});
      await mapboxMap!.style
          .setStyleSourceProperty("stayhub-heatmap-source", "data", geoJson);
          
      try {
        await mapboxMap!.style.setStyleLayerProperty(
          "stayhub-heatmap-layer",
          "heatmap-radius",
          jsonEncode([
            "interpolate",
            ["linear"],
            ["zoom"],
            0,
            2,
            9,
            heatmapRadius.value / 2,
            15,
            heatmapRadius.value
          ]),
        );
      } catch (e) {
        debugPrint('Failed to update heatmap radius: $e');
      }
      
      debugPrint('HEATMAP_SOURCE_UPDATED');
      debugPrint('HEATMAP_VISIBLE: true');
    } catch (e) {
      debugPrint('MAP_RENDER_ERROR: Heatmap sync failed: $e');
    }
  }

  // Legacy footprint mapbox synchronization removed.
  // The fog overlay now listens to fogDataRevision directly.

  void zoomIn() async {
    if (mapboxMap == null) return;
    final state = await mapboxMap!.getCameraState();
    mapboxMap!.flyTo(mb.CameraOptions(zoom: state.zoom + 1),
        mb.MapAnimationOptions(duration: 300));
  }

  void zoomOut() async {
    if (mapboxMap == null) return;
    final state = await mapboxMap!.getCameraState();
    mapboxMap!.flyTo(mb.CameraOptions(zoom: state.zoom - 1),
        mb.MapAnimationOptions(duration: 300));
  }

  void _fitToLiveLocations() {
    final pts = liveLocations
        .map((l) => LatLng(l.latitude, l.longitude))
        .where((p) => p.latitude != 0 || p.longitude != 0)
        .toList();
    _fitCamera(pts);
  }

  void fitToRoute() => _fitCamera(routeLatLngs);

  void _safeMove(LatLng center, double zoom) {
    if (mapboxMap == null) return;
    mapboxMap!.flyTo(
        mb.CameraOptions(
            center: mb.Point(
                coordinates: mb.Position(center.longitude, center.latitude)),
            zoom: zoom),
        mb.MapAnimationOptions(duration: 300));
  }

  void _fitCamera(List<LatLng> points) {
    if (points.isEmpty || mapboxMap == null) return;
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    mapboxMap!.flyTo(
        mb.CameraOptions(
            center: mb.Point(
                coordinates:
                    mb.Position((minLng + maxLng) / 2, (minLat + maxLat) / 2)),
            zoom: 12.0),
        mb.MapAnimationOptions(duration: 500));
  }
}
