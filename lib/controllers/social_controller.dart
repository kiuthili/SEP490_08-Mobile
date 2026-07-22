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
// Endpoint đã đối chiếu đúng backend (GatewayAPI / YARP):
//   - GET  /api/locations/friends/live
//   - GET  /api/locations/schedules/{id}/live
//   - POST /api/locations/ping
//   - GET  /api/moments?scheduleId=&$skip=&$top=
//   - GET  /api/moments/my-footprints
//   - GET  /api/tourscheduleitineraries?scheduleId=
//   - Heatmap: backend CHƯA có -> dựng client-side (xem loadHeatmap).

import 'dart:async';

import 'package:flutter/widgets.dart'; // EdgeInsets
import 'package:flutter_map/flutter_map.dart';
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

  /// MapController dùng để fit camera.
  final MapController mapController = MapController();

  int get currentUserId => _storage.user?.id ?? 0;

  // ======================= GLOBAL STATE =======================
  final isLoading = false.obs;
  final RxnInt selectedScheduleId = RxnInt();
  final eligibleSchedules = <EligibleScheduleModel>[].obs;

  // ----- Toggles của các lớp bản đồ -----
  final showLiveLocations = true.obs;
  final showMoments = true.obs;
  final showRoute = true.obs;
  final showFootprints = false.obs;
  final showHeatmap = false.obs;

  // ======================= 1) LIVE LOCATION =======================
  final liveLocations = <LiveLocationModel>[].obs;
  final isSharingLocation = false.obs;
  Timer? _pingTimer;
  static const _pingInterval = Duration(seconds: 15);

  // ======================= 2) MOMENTS ON MAP =======================
  final mapMoments = <MomentModel>[].obs;

  // ======================= 3) TOUR ROUTE (POLYLINE) =======================
  final routeDays = <RouteDayModel>[].obs;
  final RxnInt selectedDay = RxnInt();
  final routePoints = <RoutePointModel>[].obs;
  final isRouteLoading = false.obs;
  final List<RoutePointModel> _allItineraryPoints = [];

  /// Toạ độ Polyline dẫn xuất từ routePoints (chỉ điểm có toạ độ hợp lệ).
  List<LatLng> get routeLatLngs => routePoints
      .where((p) => p.hasCoordinates)
      .map((p) => LatLng(p.lat, p.lng))
      .toList();

  // ======================= 4) FOOTPRINTS =======================
  final footprints = <FootprintDto>[].obs;
  final isFootprintsLoading = false.obs;

  // ======================= 5) HEATMAP =======================
  final heatPoints = <HeatPointModel>[].obs;
  final isHeatmapLoading = false.obs;

  /// Stream để ép HeatMapLayer rebuild khi dữ liệu thay đổi.
  final StreamController<void> heatmapResetController =
  StreamController<void>.broadcast();
  Stream<void> get heatmapResetStream => heatmapResetController.stream;

  // ======================= LIFECYCLE =======================
  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  @override
  void onClose() {
    _pingTimer?.cancel();
    unawaited(_signalR.disconnectTracking());
    heatmapResetController.close();
    super.onClose();
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;
    try {
      await _orderController.fetchEligibleSchedules();
      
      final List<EligibleScheduleModel> rawList = [];
      if (_orderController.eligibleSchedules.isNotEmpty) {
        rawList.add(EligibleScheduleModel(
          scheduleId: 0,
          tourName: 'Tất cả chuyến đi',
          departureDate: DateTime.now(),
          returnDate: DateTime.now(),
          statusContext: 'All',
        ));
      }
      rawList.addAll(_orderController.eligibleSchedules);
      eligibleSchedules.assignAll(rawList);

      if (eligibleSchedules.isNotEmpty) {
        await selectSchedule(0);
      } else {
        await selectSchedule(0);
      }
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Không tải được dữ liệu bản đồ: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ======================= SCHEDULE SELECTION =======================
  Future<void> selectSchedule(int scheduleId) async {
    if (selectedScheduleId.value == scheduleId && liveLocations.isNotEmpty && scheduleId != 0) {
      return;
    }
    selectedScheduleId.value = scheduleId;
    isLoading.value = true;

    routeDays.clear();
    routePoints.clear();
    _allItineraryPoints.clear();
    selectedDay.value = null;

    try {
      if (scheduleId == 0) {
        await Future.wait([
          _loadFriendsLive(),
          loadMapMoments(null),
        ]);
        await _signalR.disconnectTracking();
      } else {
        await Future.wait([
          _loadScheduleLive(scheduleId),
          loadMapMoments(scheduleId),
          _loadItineraries(scheduleId),
        ]);
        await _connectRealtime(scheduleId);
      }
      _fitToLiveLocations();
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Lỗi tải lịch trình: $e');
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
      map[l.userId] = l;
    }
    liveLocations.assignAll(map.values);
  }

  Future<void> _connectRealtime(int scheduleId) async {
    await _signalR.disconnectTracking();
    await _signalR.connectTracking(onLocationUpdate: _onRealtimeLocation);
    await _signalR.joinTourTrackingGroup(scheduleId);
  }

  void _onRealtimeLocation(LiveLocationModel loc) {
    final idx = liveLocations.indexWhere((l) => l.userId == loc.userId);
    if (idx >= 0) {
      liveLocations[idx] = loc;
    } else {
      liveLocations.add(loc);
    }
    liveLocations.refresh();
  }

  /// Bật/tắt chia sẻ vị trí của tôi cho nhóm tour.
  Future<void> toggleShareMyLocation() async {
    final scheduleId = selectedScheduleId.value;
    if (scheduleId == null) {
      SnackbarHelper.error('Hãy chọn một lịch trình trước');
      return;
    }

    if (isSharingLocation.value) {
      await _stopSharing();
      return;
    }

    final granted = await LocationHelper.ensurePermission();
    if (!granted) {
      SnackbarHelper.error('Cần quyền vị trí để chia sẻ');
      return;
    }

    isSharingLocation.value = true;
    await _pingOnce(scheduleId);
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _pingOnce(scheduleId));
    SnackbarHelper.success('Đang chia sẻ vị trí của bạn');
  }

  Future<void> _stopSharing() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    isSharingLocation.value = false;
    try {
      await _service.stopLocationSharing();
    } catch (_) {}
    SnackbarHelper.success('Đã tắt chia sẻ vị trí');
  }

  Future<void> _pingOnce(int scheduleId) async {
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (pos != null) {
        await _service.pingLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          scheduleId: scheduleId,
        );
      }
    } catch (_) {
      // im lặng để tránh spam snackbar mỗi 15s
    }
  }

  // ======================= 2) MOMENTS ON MAP =======================
  Future<void> loadMapMoments(int? scheduleId) async {
    try {
      final data = await _service.getMomentsWithLocation(scheduleId: scheduleId);
      mapMoments.assignAll(
        data.where((m) => m.lat != null && m.lng != null),
      );
    } catch (_) {
      // không chặn luồng chính nếu moment lỗi
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
            title: 'Ngày ${p.dayNumber}',
          ),
        );
      }
      final sorted = byDay.values.toList()
        ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      routeDays.assignAll(sorted);

      if (sorted.isNotEmpty) {
        selectDay(sorted.first.dayNumber);
      }
    } catch (_) {
      // tour chưa có lộ trình -> bỏ qua, không chặn các lớp khác
    } finally {
      isRouteLoading.value = false;
    }
  }

  /// Lọc các điểm của 1 ngày (đồng bộ, không gọi mạng lại).
  void selectDay(int dayNumber) {
    selectedDay.value = dayNumber;
    final pts = _allItineraryPoints
        .where((p) => p.dayNumber == dayNumber)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    routePoints.assignAll(pts);
    _fitToRoute();
  }

  // ======================= 4) FOOTPRINTS ("CÀO MAP") =======================
  Future<void> toggleFootprints() async {
    showFootprints.toggle();
    if (showFootprints.value && footprints.isEmpty) {
      await loadFootprints();
    }
  }

  Future<void> loadFootprints() async {
    isFootprintsLoading.value = true;
    try {
      final data = await _service.getMyFootprints(
        scheduleId: selectedScheduleId.value,
      );
      footprints.assignAll(data);
      if (data.isEmpty) {
        SnackbarHelper.success('Chưa có dấu chân nào được ghi nhận');
      }
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Lỗi tải dấu chân: $e');
    } finally {
      isFootprintsLoading.value = false;
    }
  }

  // ======================= 5) HEATMAP =======================
  Future<void> toggleHeatmap() async {
    showHeatmap.toggle();
    if (showHeatmap.value && heatPoints.isEmpty) {
      await loadHeatmap();
    } else if (showHeatmap.value) {
      heatmapResetController.add(null);
    }
  }

  /// Backend hiện CHƯA có endpoint heatmap.
  /// Ưu tiên gọi service; nếu lỗi (vd 404) thì dựng heatmap client-side từ
  /// dữ liệu sẵn có (moments + footprints + live locations).
  Future<void> loadHeatmap() async {
    isHeatmapLoading.value = true;
    try {
      final data = await _service.getHeatmapData(
        scheduleId: selectedScheduleId.value,
      );
      heatPoints.assignAll(data);
    } catch (_) {
      heatPoints.assignAll(_buildHeatmapFromClientData());
    } finally {
      heatmapResetController.add(null);
      isHeatmapLoading.value = false;
    }
  }

  /// Gộp mọi toạ độ đang có thành điểm heatmap (fallback khi chưa có API).
  List<HeatPointModel> _buildHeatmapFromClientData() {
    final pts = <HeatPointModel>[];
    for (final m in mapMoments) {
      if (m.lat != null && m.lng != null) {
        pts.add(HeatPointModel(lat: m.lat!, lng: m.lng!));
      }
    }
    for (final f in footprints) {
      pts.add(HeatPointModel(lat: f.lat, lng: f.lng));
    }
    for (final l in liveLocations) {
      pts.add(HeatPointModel(lat: l.latitude, lng: l.longitude));
    }
    return pts;
  }

  // ======================= CAMERA HELPERS =======================
  void _fitToLiveLocations() {
    final pts = liveLocations
        .map((l) => LatLng(l.latitude, l.longitude))
        .where((p) => p.latitude != 0 || p.longitude != 0)
        .toList();
    _fitCamera(pts);
  }

  void _fitToRoute() => _fitCamera(routeLatLngs);

  void _fitCamera(List<LatLng> points) {
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        mapController.move(points.first, 13);
        return;
      }
      mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(56),
        ),
      );
    } catch (_) {
      // map có thể chưa mount; bỏ qua an toàn
    }
  }
}
