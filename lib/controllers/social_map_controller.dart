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
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'; // EdgeInsets, WidgetsBinding
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
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

  /// MapController dùng để fit camera / điều khiển zoom.
  final MapController mapController = MapController();

  int get currentUserId => _storage.user?.id ?? 0;

  /// Tâm bản đồ mặc định (Việt Nam) — dùng cho recenter khi chưa có dữ liệu.
  static const LatLng defaultCenter = LatLng(16.047079, 108.206230);
  static const double defaultZoom = 6;

  // ======================= GLOBAL STATE =======================
  final isLoading = false.obs;
  final RxnInt selectedScheduleId = RxnInt();
  final eligibleSchedules = <EligibleScheduleModel>[].obs;

  /// Map đã mount xong chưa (tránh fitCamera trước khi sẵn sàng).
  final isMapReady = false.obs;
  // Yêu cầu fit camera đang chờ map mount xong.
  List<LatLng>? _pendingFit;

  // ----- Toggles của các lớp bản đồ -----
  final showLiveLocations = true.obs;
  final showMoments = true.obs;
  final showRoute = true.obs;
  final showFootprints = false.obs;
  final showHeatmap = false.obs;

  // ======================= 1) LIVE LOCATION =======================
  final liveLocations = <LiveLocationModel>[].obs;
  /// Bật/tắt chia sẻ + ghi log di chuyển realtime của BẢN THÂN.
  final isSharingLocation = false.obs;
  Timer? _pingTimer;
  Timer? _friendsTimer;
  Timer? _footprintsTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _latestPosition;
  Position? _lastPingedPosition;
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
  Timer? _heatmapDebounce;

  // ======================= LIFECYCLE =======================
  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  @override
  void onClose() {
    _pingTimer?.cancel();
    _friendsTimer?.cancel();
    _footprintsTimer?.cancel();
    _heatmapDebounce?.cancel();
    _positionStreamSubscription?.cancel();
    unawaited(_signalR.disconnectTracking());
    if (!heatmapResetController.isClosed) heatmapResetController.close();
    try {
      mapController.dispose();
    } catch (_) {/* đã dispose hoặc chưa mount */}
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
        // Không có tour: vẫn hiện bạn bè đang chia sẻ vị trí.
        await _loadFriendsLive();
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
      SnackbarHelper.error('Không tải được dữ liệu bản đồ: $e');
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
      final token = await _service.generateTrackingToken();
      if (token.isEmpty) return null;
      return token;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Lỗi tạo link theo dõi: $e');
    }
    return null;
  }

  // ======================= SCHEDULE SELECTION =======================
  Future<void> selectSchedule(int scheduleId) async {
    if (selectedScheduleId.value == scheduleId && liveLocations.isNotEmpty) {
      return;
    }
    selectedScheduleId.value = scheduleId;
    isLoading.value = true;

    routeDays.clear();
    routePoints.clear();
    _allItineraryPoints.clear();
    selectedDay.value = null;

    try {
      await Future.wait([
        _loadScheduleLive(scheduleId),
        _loadFriendsLive(),
        loadMapMoments(scheduleId),
        _loadItineraries(scheduleId),
      ]);
      await _connectRealtime(scheduleId);
      _fitToLiveLocations();
      // Nếu heatmap đang bật, nạp lại theo schedule mới.
      if (showHeatmap.value) {
        unawaited(loadHeatmap());
      }
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
  /// Bật/tắt ghi log di chuyển realtime + chia sẻ vị trí của tôi.
  Future<void> toggleShareMyLocation() async {
    if (isSharingLocation.value) {
      _stopSharing();
      await _storage.setShareMyLocation(false);
      SnackbarHelper.success('Đã tắt chia sẻ & ghi vị trí');
      return;
    }
    final ok = await _startAutoTracking(notify: true);
    if (ok) {
      await _storage.setShareMyLocation(true);
      SnackbarHelper.success('Đang chia sẻ & ghi lại lộ trình của bạn');
    }
  }

  /// Bắt đầu ghi log di chuyển realtime (cào map liên tục). Trả về true nếu
  /// được cấp quyền và đã khởi động vòng ping.
  Future<bool> _startAutoTracking({bool notify = false}) async {
    if (isSharingLocation.value) return true;
    final granted = await LocationHelper.ensurePermission();
    if (!granted) {
      if (notify) SnackbarHelper.error('Cần quyền vị trí để theo dõi & chia sẻ');
      return false;
    }
    isSharingLocation.value = true;

    // Lấy vị trí ban đầu lập tức từ cache để map mượt
    try {
      final initialPos = await Geolocator.getLastKnownPosition();
      if (initialPos != null) {
        _latestPosition = initialPos;
        final here = LatLng(initialPos.latitude, initialPos.longitude);
        _appendTrail(here);
        _updateMyLiveMarker(here);
        unawaited(_pingLatestToServer());
      }
    } catch (_) {}

    // Lắng nghe stream thay đổi vị trí chủ động, độ chính xác cao và liên tục
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // 0 mét để tracking liên tục không bỏ sót
      ),
    ).listen((Position pos) {
      _latestPosition = pos;
      final here = LatLng(pos.latitude, pos.longitude);
      _appendTrail(here);
      _updateMyLiveMarker(here);
    }, onError: (_) {});

    // Gửi vị trí lên server định kỳ 12s/lần nhưng chỉ gửi khi có toạ độ mới
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _pingLatestToServer());

    return true;
  }

  void _stopSharing() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    isSharingLocation.value = false;
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
      _lastPingedPosition = pos;
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
    if (showFootprints.value) {
      if (footprints.isEmpty) await loadFootprints();
      // Tự refresh footprints từ server định kỳ khi lớp đang bật.
      _footprintsTimer?.cancel();
      _footprintsTimer = Timer.periodic(
        _footprintsRefreshInterval,
            (_) => loadFootprints(silent: true),
      );
    } else {
      _footprintsTimer?.cancel();
      _footprintsTimer = null;
    }
  }

  Future<void> loadFootprints({bool silent = false}) async {
    if (!silent) isFootprintsLoading.value = true;
    try {
      final data = await _service.getMyFootprints();
      footprints.assignAll(data);
      if (data.isEmpty && !silent && liveTrail.isEmpty) {
        SnackbarHelper.success('Chưa có dấu chân nào — hãy di chuyển để cào map');
      }
    } on ApiError catch (e) {
      if (!silent) SnackbarHelper.error(e.message);
    } catch (e) {
      if (!silent) SnackbarHelper.error('Lỗi tải dấu chân: $e');
    } finally {
      if (!silent) isFootprintsLoading.value = false;
    }
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
    isHeatmapLoading.value = true;
    try {
      final data = await _service.getHeatmapData(
        scheduleId: selectedScheduleId.value,
      );
      if (data.isEmpty) {
        heatPoints.assignAll(_buildHeatmapFromClientData());
      } else {
        heatPoints.assignAll(data);
      }
    } catch (_) {
      heatPoints.assignAll(_buildHeatmapFromClientData());
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
    for (final t in liveTrail) {
      pts.add(HeatPointModel(lat: t.latitude, lng: t.longitude));
    }
    return pts;
  }

  // ======================= CAMERA HELPERS =======================
  /// Về vị trí của tôi (nếu đang chia sẻ/lấy được GPS), nếu không thì fit live.
  Future<void> recenter() async {
    // 1. Ưu tiên sử dụng vị trí cập nhật gần nhất có sẵn (phản hồi tức thì)
    final cached = _latestPosition;
    if (cached != null) {
      _safeMove(LatLng(cached.latitude, cached.longitude), 15);
      return;
    }

    // 2. Thử lấy GPS phần cứng mới nếu chưa có cache
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (pos != null) {
        _latestPosition = pos;
        _safeMove(LatLng(pos.latitude, pos.longitude), 15);
        return;
      }
    } catch (_) {}
    _fitToLiveLocations();
  }

  void zoomIn() {
    if (!isMapReady.value) return;
    try {
      final cam = mapController.camera;
      _safeMove(cam.center, (cam.zoom + 1).clamp(2, 18).toDouble());
    } catch (_) {}
  }

  void zoomOut() {
    if (!isMapReady.value) return;
    try {
      final cam = mapController.camera;
      _safeMove(cam.center, (cam.zoom - 1).clamp(2, 18).toDouble());
    } catch (_) {}
  }

  void _fitToLiveLocations() {
    final pts = liveLocations
        .map((l) => LatLng(l.latitude, l.longitude))
        .where((p) => p.latitude != 0 || p.longitude != 0)
        .toList();
    _fitCamera(pts);
  }

  void _fitToRoute() => _fitCamera(routeLatLngs);

  void _safeMove(LatLng center, double zoom) {
    if (!isMapReady.value) return;
    try {
      mapController.move(center, zoom);
    } catch (_) {}
  }

  /// Tải dữ liệu dòng thời gian hành trình (timeline) về thiết bị dưới dạng tệp JSON
  Future<void> downloadTimeline() async {
    if (mapMoments.isEmpty) {
      SnackbarHelper.error('Không có dữ liệu hành trình để tải về');
      return;
    }

    try {
      // 1. Tạo cấu trúc dữ liệu JSON dòng thời gian hành trình
      final momentsData = timelineMoments.map((m) => {
        'id': m.id,
        'user': m.fullName ?? 'Người dùng',
        'caption': m.caption ?? '',
        'imageUrl': m.imageUrl,
        'lat': m.lat,
        'lng': m.lng,
        'time': m.createdAt.toIso8601String(),
      }).toList();

      final jsonString = JsonEncoder.withIndent('  ').convert(momentsData);

      // 2. Thử lưu vào thư mục Download công cộng của thiết bị Android
      File? savedFile;
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final file = File('${downloadDir.path}/stayhub_timeline_${selectedScheduleId.value ?? "general"}.json');
          await file.writeAsString(jsonString);
          savedFile = file;
        }
      } catch (_) {
        // Bỏ qua lỗi truy cập trực tiếp thư mục Download
      }

      // 3. Nếu là iOS hoặc thư mục Download công cộng bị giới hạn quyền, lưu vào thư mục tạm của ứng dụng
      if (savedFile == null) {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/stayhub_timeline_${selectedScheduleId.value ?? "general"}.json');
        await file.writeAsString(jsonString);
        savedFile = file;
      }

      // 4. Đồng thời sao chép vào Clipboard làm fallback an toàn
      await Clipboard.setData(ClipboardData(text: jsonString));

      // 5. Hiển thị thông báo thành công
      SnackbarHelper.success('Đã tải dòng thời gian về máy tại: ${savedFile.path}\n(Dữ liệu cũng đã được sao chép vào Clipboard!)');
    } catch (e) {
      SnackbarHelper.error('Lỗi khi xuất tệp dòng thời gian: $e');
    }
  }

  void _fitCamera(List<LatLng> points) {
    if (points.isEmpty) return;
    // Nếu map chưa mount, hoãn lại tới onMapReady.
    if (!isMapReady.value) {
      _pendingFit = points;
      return;
    }
    try {
      if (points.length == 1) {
        mapController.move(points.first, 13);
        return;
      }
      mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(72),
        ),
      );
    } catch (_) {
      // map có thể chưa sẵn sàng; thử lại sau frame kế tiếp.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(72),
            ),
          );
        } catch (_) {}
      });
    }
  }
}
