import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../models/social_models.dart';
import '../models/feature_models.dart';
import '../models/map_models.dart';
import '../services/location_helper.dart';
import '../services/social_service.dart';
import '../utils/marker_generator.dart';
import 'auth_controller.dart';

class StaffMapController extends GetxController {
  final SocialService _service = Get.find<SocialService>();

  mb.MapboxMap? mapboxMap;
  mb.PointAnnotationManager? liveLocManager;

  final isMapReady = false.obs;
  final isLoading = false.obs;
  final isRouteLoading = false.obs;

  final liveLocations = <LiveLocationModel>[].obs;
  
  // Route & Waypoints
  final routeDays = <RouteDayModel>[].obs;
  final selectedDay = Rx<int?>(null);
  final routePoints = <RoutePointModel>[].obs;
  final drivingRouteLatLngs = <LatLng>[].obs;
  final _allItineraryPoints = <RoutePointModel>[];
  final Map<String, Uint8List> _waypointMarkerCache = {};
  
  // Moments
  final mapMoments = <MomentModel>[].obs;
  String _lastMomentSignature = "";
  
  // Visibility Toggles
  final showRoute = true.obs;
  final showMoments = true.obs;

  // Managers
  mb.PointAnnotationManager? waypointManager;
  mb.PolylineAnnotationManager? routeCasingManager;
  mb.PolylineAnnotationManager? routeDashedCoreManager;
  
  int? scheduleId;
  Timer? _pollingTimer;
  StreamSubscription<Position>? _myLocSub;

  bool _isSyncingRoute = false;
  bool _isSyncingWaypoints = false;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args['scheduleId'] != null) {
      initMap(args['scheduleId']);
    }
  }

  void initMap(int schedId) {
    if (scheduleId == schedId) return; // Already initialized
    scheduleId = schedId;
    _loadScheduleLive(scheduleId!);
    _loadItineraries(scheduleId!);
    loadMapMoments(scheduleId!);
    
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (scheduleId != null) {
        _loadScheduleLive(scheduleId!);
      }
    });
    
    ever(showRoute, (_) {
      _syncRoute();
      _syncWaypoints();
    });
    ever(showMoments, (_) => _syncMomentsGeoJson());
    ever(drivingRouteLatLngs, (_) => _syncRoute());
    ever(routePoints, (_) => _syncWaypoints());
    ever(mapMoments, (_) => _syncMomentsGeoJson());
  }

  @override
  void onClose() {
    _pollingTimer?.cancel();
    _myLocSub?.cancel();
    super.onClose();
  }

  Future<void> onMapCreated(mb.MapboxMap map) async {
    mapboxMap = map;
  }

  Future<void> onStyleLoaded(mb.StyleLoadedEventData event) async {
    if (mapboxMap == null) return;
    try {
      if (liveLocManager != null) await mapboxMap!.annotations.removeAnnotationManager(liveLocManager!);
      if (waypointManager != null) await mapboxMap!.annotations.removeAnnotationManager(waypointManager!);
      if (routeCasingManager != null) await mapboxMap!.annotations.removeAnnotationManager(routeCasingManager!);
      if (routeDashedCoreManager != null) await mapboxMap!.annotations.removeAnnotationManager(routeDashedCoreManager!);

      liveLocManager = await mapboxMap!.annotations.createPointAnnotationManager(id: "live_loc");
      waypointManager = await mapboxMap!.annotations.createPointAnnotationManager(id: "waypoint");
      routeCasingManager = await mapboxMap!.annotations.createPolylineAnnotationManager(id: "route_casing");
      routeDashedCoreManager = await mapboxMap!.annotations.createPolylineAnnotationManager(id: "route_core");
      
      await _ensureMomentSourceAndLayers();
      isMapReady.value = true;
      _trackMyCustomLocation();
      _syncLiveLocations();
      _syncRoute();
      _syncWaypoints();
      _syncMomentsGeoJson();
    } catch (e) {
      debugPrint('MAP_RENDER_ERROR: setup failed: $e');
    }
  }

  Future<void> _loadScheduleLive(int schedId) async {
    isLoading.value = true;
    try {
      final data = await _service.getScheduleLiveLocations(schedId);
      liveLocations.assignAll(data);
      if (isMapReady.value) {
        _syncLiveLocations();
      }
    } catch (e) {
      debugPrint('Error loading schedule live locations: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _syncLiveLocations() async {
    if (!isMapReady.value || liveLocManager == null) return;
    try {
      final authController = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
      final currentUserId = authController?.currentUser.value?.id;

      final annotations = <mb.PointAnnotationOptions>[];
      for (final loc in liveLocations) {
        if (loc.latitude == 0 || loc.longitude == 0) continue;
        if (currentUserId != null && loc.userId == currentUserId) continue;

        final markerResult = await MarkerGenerator.createLiveFriendMarker(
          loc.avatarUrl,
          false,
          name: loc.fullName,
        );
        annotations.add(mb.PointAnnotationOptions(
          geometry: mb.Point(coordinates: mb.Position(loc.longitude, loc.latitude)),
          image: markerResult.data,
          iconAnchor: mb.IconAnchor.CENTER,
        ));
      }
      await liveLocManager!.deleteAll();
      if (annotations.isNotEmpty) {
        await liveLocManager!.createMulti(annotations);
      }
    } catch (e) {
      debugPrint('Error syncing live locations: $e');
    }
  }

  Future<void> _trackMyCustomLocation() async {
    try {
      final granted = await LocationHelper.ensurePermission();
      if (!granted) return;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      
      if (mapboxMap != null) {
        // Disable default puck
        await mapboxMap!.location.updateSettings(
          mb.LocationComponentSettings(enabled: false),
        );
      }

      final meManager = await mapboxMap!.annotations.createPointAnnotationManager(id: "me_loc_manager");
      
      // Get user info
      final authController = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
      final user = authController?.currentUser.value;
      
      final markerResult = await MarkerGenerator.createLiveFriendMarker(
        user?.avatarUrl,
        true,
        name: user?.fullName ?? 'Me',
      );
      final markerBytes = markerResult.data;

      _myLocSub?.cancel();
      _myLocSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2),
      ).listen((pos) async {
        await meManager.deleteAll();
        await meManager.create(
          mb.PointAnnotationOptions(
            geometry: mb.Point(coordinates: mb.Position(pos.longitude, pos.latitude)),
            image: markerBytes,
            iconAnchor: mb.IconAnchor.CENTER,
          )
        );
      });
    } catch (e) {
      debugPrint('Error tracking my custom location: $e');
    }
  }

  void fitToLiveLocations() {
    if (!isMapReady.value || mapboxMap == null || liveLocations.isEmpty) return;
    
    final validLocs = liveLocations.where((l) => l.latitude != 0 && l.longitude != 0).toList();
    if (validLocs.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;
    
    for (var loc in validLocs) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLng) minLng = loc.longitude;
      if (loc.longitude > maxLng) maxLng = loc.longitude;
    }
    
    try {
      mapboxMap!.flyTo(
        mb.CameraOptions(
          center: mb.Point(coordinates: mb.Position((minLng + maxLng) / 2, (minLat + maxLat) / 2)),
          zoom: 12.0,
        ),
        mb.MapAnimationOptions(duration: 500)
      );
    } catch (e) {
      debugPrint('Error fitting map bounds: $e');
    }
  }

  void recenter() async {
    if (drivingRouteLatLngs.isNotEmpty) {
      fitToRoute();
    } else {
      fitToLiveLocations();
    }
    
    // Also move to my location if available
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (pos != null && mapboxMap != null) {
        mapboxMap!.flyTo(
          mb.CameraOptions(
            center: mb.Point(coordinates: mb.Position(pos.longitude, pos.latitude)),
            zoom: 15.0,
          ),
          mb.MapAnimationOptions(duration: 500)
        );
      }
    } catch (_) {}
  }

  void fitToRoute() {
    if (!isMapReady.value || mapboxMap == null || drivingRouteLatLngs.isEmpty) return;
    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;
    for (var l in drivingRouteLatLngs) {
      if (l.latitude < minLat) minLat = l.latitude;
      if (l.latitude > maxLat) maxLat = l.latitude;
      if (l.longitude < minLng) minLng = l.longitude;
      if (l.longitude > maxLng) maxLng = l.longitude;
    }
    try {
      mapboxMap!.flyTo(
        mb.CameraOptions(
          center: mb.Point(coordinates: mb.Position((minLng + maxLng) / 2, (minLat + maxLat) / 2)),
          zoom: 11.0,
        ),
        mb.MapAnimationOptions(duration: 500)
      );
    } catch (_) {}
  }

  // ======================= ITINERARIES & ROUTE =======================

  Future<void> _loadItineraries(int scheduleId) async {
    isRouteLoading.value = true;
    try {
      final points = await _service.getScheduleItineraries(scheduleId);
      _allItineraryPoints..clear()..addAll(points);

      final byDay = <int, RouteDayModel>{};
      for (final p in points) {
        byDay.putIfAbsent(
          p.dayNumber,
          () => RouteDayModel(dayNumber: p.dayNumber, title: 'Day ${p.dayNumber}'),
        );
      }
      final sorted = byDay.values.toList()..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      routeDays.assignAll(sorted);

      if (sorted.isNotEmpty) {
        await selectDay(null); // Overview
      }
    } catch (_) {
    } finally {
      isRouteLoading.value = false;
    }
  }

  Future<void> selectDay(int? dayNumber) async {
    selectedDay.value = dayNumber;

    final List<RoutePointModel> pts;
    if (dayNumber == null) {
      pts = List<RoutePointModel>.from(_allItineraryPoints);
    } else {
      pts = _allItineraryPoints.where((p) => p.dayNumber == dayNumber).toList();
    }

    pts.sort((a, b) => a.dayNumber == b.dayNumber
        ? a.order.compareTo(b.order)
        : a.dayNumber.compareTo(b.dayNumber));

    routePoints.assignAll(pts);

    final waypoints = pts.where((p) => _isValidCoordinate(p.lat, p.lng)).map((p) => LatLng(p.lat, p.lng)).toList();
    if (waypoints.isNotEmpty) {
      try {
        isRouteLoading.value = true;
        final actualRoute = await _service.getDrivingRoute(waypoints);
        drivingRouteLatLngs.assignAll(actualRoute.isNotEmpty ? actualRoute : waypoints);
      } catch (e) {
        drivingRouteLatLngs.assignAll(waypoints);
      } finally {
        isRouteLoading.value = false;
      }
    } else {
      drivingRouteLatLngs.clear();
    }
    fitToRoute();
  }

  Future<void> _syncRoute() async {
    if (_isSyncingRoute || !isMapReady.value || routeCasingManager == null || routeDashedCoreManager == null) return;
    _isSyncingRoute = true;
    try {
      await routeCasingManager!.deleteAll();
      await routeDashedCoreManager!.deleteAll();

      if (!showRoute.value || drivingRouteLatLngs.isEmpty || drivingRouteLatLngs.length < 2) return;

      final coords = drivingRouteLatLngs.map((l) => mb.Position(l.longitude, l.latitude)).toList();
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

      await routeDashedCoreManager!.setLineCap(mb.LineCap.ROUND);
      await routeDashedCoreManager!.setLineJoin(mb.LineJoin.ROUND);
      await routeDashedCoreManager!.setLineDasharray([2.0, 2.0]);
      await routeDashedCoreManager!.create(coreOptions);
    } catch (_) {} finally {
      _isSyncingRoute = false;
    }
  }

  Future<void> _syncWaypoints() async {
    if (_isSyncingWaypoints || !isMapReady.value || waypointManager == null) return;
    _isSyncingWaypoints = true;
    try {
      await waypointManager!.deleteAll();

      if (!showRoute.value || _allItineraryPoints.isEmpty) return;

      final allPts = List<RoutePointModel>.from(_allItineraryPoints);
      allPts.sort((a, b) => a.dayNumber == b.dayNumber
          ? a.order.compareTo(b.order)
          : a.dayNumber.compareTo(b.dayNumber));

      final validAllPts = allPts.where((p) => _isValidCoordinate(p.lat, p.lng)).toList();
      final globalAssigned = <RoutePointModel, int>{};
      int seq = 1;
      for (final p in validAllPts) {
        globalAssigned[p] = seq++;
      }

      final visiblePts = validAllPts.where((p) => selectedDay.value == null || p.dayNumber == selectedDay.value).toList();
      final List<mb.PointAnnotationOptions> options = [];

      for (final p in visiblePts) {
        final label = '${globalAssigned[p]!}. ${p.name}';
        final cacheKey = '${scheduleId}|${p.dayNumber}|${p.order}|${p.name}';

        Uint8List? markerData = _waypointMarkerCache[cacheKey];
        if (markerData == null) {
          final marker = await MarkerGenerator.createScheduleStopMarker(label);
          if (marker != null) {
            markerData = marker.data;
            _waypointMarkerCache[cacheKey] = markerData;
          }
        }
        if (markerData != null) {
          options.add(mb.PointAnnotationOptions(
            geometry: mb.Point(coordinates: mb.Position(p.lng, p.lat)),
            image: markerData,
            iconAnchor: mb.IconAnchor.BOTTOM,
          ));
        }
      }

      if (options.isNotEmpty) {
        await waypointManager!.setIconAllowOverlap(true);
        await waypointManager!.setIconIgnorePlacement(true);
        await waypointManager!.createMulti(options);
      }
    } catch (_) {} finally {
      _isSyncingWaypoints = false;
    }
  }

  // ======================= MOMENTS =======================

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
        final clusterFeature = features.firstWhere((f) {
          final p = f?.queriedFeature.feature['properties'] as Map<dynamic, dynamic>?;
          return p != null && p.containsKey('cluster') && p['cluster'] == true;
        }, orElse: () => null);

        if (clusterFeature != null) {
          final state = await mapboxMap!.getCameraState();
          final geom = clusterFeature.queriedFeature.feature['geometry'] as Map<dynamic, dynamic>;
          if (geom['type'] == 'Point') {
            final coords = geom['coordinates'] as List<dynamic>;
            mapboxMap!.flyTo(
              mb.CameraOptions(
                center: mb.Point(coordinates: mb.Position(coords[0], coords[1])),
                zoom: state.zoom + 2,
              ),
              mb.MapAnimationOptions(duration: 300),
            );
          }
        } else {
          final unclusteredProps = features
              .map((f) => f?.queriedFeature.feature['properties'] as Map<dynamic, dynamic>?)
              .where((p) => p != null && p.containsKey('momentId'))
              .toList();

          if (unclusteredProps.isNotEmpty) {
            final momentIds = unclusteredProps.map((p) => int.parse(p!['momentId'].toString())).toSet().toList();
            final overlappingMoments = momentIds
                .map((id) => mapMoments.firstWhereOrNull((m) => m.id == id))
                .whereType<MomentModel>()
                .toList();

            if (overlappingMoments.isEmpty) return;

            if (overlappingMoments.length == 1) {
              Get.toNamed('/moment-detail', arguments: overlappingMoments.first);
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
    } catch (_) {}
  }

  Future<void> loadMapMoments(int scheduleId) async {
    try {
      final data = await _service.getMomentsWithLocation(scheduleId: scheduleId);
      mapMoments.assignAll(data.where((m) => m.lat != null && m.lng != null));
    } catch (_) {}
  }

  Future<void> _ensureMomentSourceAndLayers() async {
    if (mapboxMap == null) return;
    try {
      final style = mapboxMap!.style;

      if (!await style.hasStyleImage("stayhub-moment-icon")) {
        final markerData = await MarkerGenerator.createMomentMarker();
        if (markerData != null) {
          await style.addStyleImage(
            "stayhub-moment-icon", 4.0,
            mb.MbxImage(width: markerData.width, height: markerData.height, data: markerData.data),
            false, [], [], null,
          );
        }
      }

      if (!await style.styleSourceExists("stayhub-moments-source")) {
        await style.addSource(mb.GeoJsonSource(
          id: "stayhub-moments-source",
          data: '{"type":"FeatureCollection","features":[]}',
          cluster: true,
          clusterRadius: 80,
          clusterMaxZoom: 19,
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
          textField: "{point_count_abbreviated}",
          textFont: ["Open Sans Bold", "Arial Unicode MS Bold"],
          textSize: 12.0,
          textColor: 0xFFFFFFFF,
        ));
      }

      if (!await style.styleLayerExists("stayhub-moment-unclustered")) {
        await style.addLayer(mb.SymbolLayer(
          id: "stayhub-moment-unclustered",
          sourceId: "stayhub-moments-source",
          filter: ["!", ["has", "point_count"]],
          iconImage: "{imageId}",
          iconSize: 0.45,
          iconAnchor: mb.IconAnchor.BOTTOM,
          iconAllowOverlap: true,
        ));
      }
    } catch (_) {}
  }

  Future<void> _syncMomentsGeoJson() async {
    if (mapboxMap == null || !isMapReady.value) return;

    if (!showMoments.value || mapMoments.isEmpty) {
      try {
        await mapboxMap!.style.setStyleSourceProperty(
            "stayhub-moments-source", "data", '{"type":"FeatureCollection","features":[]}');
      } catch (_) {}
      return;
    }

    final Map<int, MomentModel> uniqueMoments = {};
    for (final m in mapMoments) {
      if (!uniqueMoments.containsKey(m.id)) {
        uniqueMoments[m.id] = m;
      }
    }

    final sortedIds = uniqueMoments.keys.toList()..sort();
    final StringBuffer sigBuilder = StringBuffer();
    sigBuilder.write(scheduleId?.toString() ?? "null");
    sigBuilder.write("|");
    for (final id in sortedIds) {
      final m = uniqueMoments[id]!;
      sigBuilder.write("${m.id}:${m.lat}:${m.lng},");
    }

    final newSig = sigBuilder.toString();
    if (newSig == _lastMomentSignature) return;
    _lastMomentSignature = newSig;

    final features = <Map<String, dynamic>>[];
    for (final id in sortedIds) {
      final m = uniqueMoments[id]!;
      if (m.lat != null && m.lng != null && _isValidCoordinate(m.lat!, m.lng!)) {
        final imageId = "moment_img_${m.id}";
        try {
          if (!await mapboxMap!.style.hasStyleImage(imageId)) {
            final markerData = await MarkerGenerator.createMomentMarker(m.imageUrl);
            if (markerData != null) {
              await mapboxMap!.style.addStyleImage(
                imageId, 1.0,
                mb.MbxImage(width: markerData.width, height: markerData.height, data: markerData.data),
                false, [], [], null,
              );
            }
          }
        } catch (_) {}

        features.add({
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [m.lng, m.lat]
          },
          "properties": {
            "momentId": m.id,
            "scheduleId": m.scheduleId,
            "imageId": imageId,
          }
        });
      }
    }

    final geoJson = jsonEncode({
      "type": "FeatureCollection",
      "features": features,
    });

    try {
      if (await mapboxMap!.style.styleSourceExists("stayhub-moments-source")) {
        await mapboxMap!.style.setStyleSourceProperty("stayhub-moments-source", "data", geoJson);
      } else {
        await _ensureMomentSourceAndLayers();
        await mapboxMap!.style.setStyleSourceProperty("stayhub-moments-source", "data", geoJson);
      }
    } catch (_) {}
  }

  bool _isValidCoordinate(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

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
}
