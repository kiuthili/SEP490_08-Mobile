import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:get/get.dart';
import '../../models/ai_models.dart';
import '../../services/signalr_service.dart';
import '../../services/social_service.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/loading_widget.dart';
import '../../constants/api_constants.dart';
import 'package:stayhub_mobile/theme/app_colors.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';
import '../../utils/marker_generator.dart';
import '../../services/location_helper.dart';
import '../../utils/snackbar_helper.dart';

/// Theo dõi vị trí công khai qua token (giống web) dùng Mapbox.
class PublicTrackingScreen extends StatefulWidget {
  const PublicTrackingScreen({super.key});

  @override
  State<PublicTrackingScreen> createState() => _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends State<PublicTrackingScreen> {
  final _social = Get.find<SocialService>();
  final _signalR = Get.find<SignalRService>();

  mb.MapboxMap? _mapboxMap;
  mb.PointAnnotationManager? _pointAnnotationManager;
  mb.PointAnnotation? _marker;

  late final String _token;
  PublicLocationModel? _location;
  var _loading = true;
  var _error = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _token = Get.parameters['token'] ?? '';
    mb.MapboxOptions.setAccessToken(ApiConstants.mapboxAccessToken);

    if (_token.isEmpty) {
      _error = true;
      _errorMessage = 'Token is empty';
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final loc = await _social.getPublicLocation(_token);
      if (!mounted) return;
      setState(() {
        _location = loc;
        _loading = false;
      });
      _moveCamera(loc.lat, loc.lng, 15);

      try {
        await _signalR.connectPublicTracking(
          token: _token,
          onLocationUpdate: (lat, lng) {
            if (!mounted) return;
            setState(() {
              _location = PublicLocationModel(
                lat: lat,
                lng: lng,
                fullName: _location?.fullName ?? 'sc_pts_guest'.tr,
              );
            });

            if (_mapboxMap != null) {
              _mapboxMap!.getCameraState().then((state) {
                _moveCamera(lat, lng, state.zoom);
              });
            }
          },
        );
      } catch (e) {
        debugPrint('SignalR public tracking connection error: $e');
        // Do not fail the whole screen if SignalR fails
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    
    try {
      await mapboxMap.location.updateSettings(
        mb.LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
        ),
      );
    } catch (_) {}
  }

  void _onStyleLoadedListener(mb.StyleLoadedEventData data) async {
    while (_mapboxMap == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    final markerImageId = 'user_marker_${_location?.fullName ?? 'loc'}';
    try {
      if (await _mapboxMap!.style.hasStyleImage(markerImageId)) {
        await _mapboxMap!.style.removeStyleImage(markerImageId);
      }
      final markerData = await MarkerGenerator.createLiveFriendMarker(_location?.avatarUrl, false, name: _location?.fullName);
      await _mapboxMap!.style.addStyleImage(
        markerImageId,
        1.0, // scale
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
    } catch (e) {
      debugPrint('Error loading marker image: $e');
    }

    _mapboxMap!.annotations.createPointAnnotationManager().then((manager) async {
      _pointAnnotationManager = manager;
      await _pointAnnotationManager?.setIconAllowOverlap(true);
      await _pointAnnotationManager?.setIconIgnorePlacement(true);
      _updateMarker();
    });
  }

  Future<void> _updateMarker() async {
    if (_pointAnnotationManager == null || _location == null) return;

    try {
      if (_marker != null) {
        await _pointAnnotationManager?.delete(_marker!);
        _marker = null;
      }

      final markerImageId = 'user_marker_${_location?.fullName ?? 'loc'}';
      _marker = await _pointAnnotationManager?.create(mb.PointAnnotationOptions(
        geometry:
            mb.Point(coordinates: mb.Position(_location!.lng, _location!.lat)),
        iconImage: markerImageId,
        iconSize: 1.0,
      ));
    } catch (e) {
      debugPrint('Error updating marker: $e');
    }
  }

  void _moveCamera(double lat, double lng, double? zoom) {
    try {
      _mapboxMap?.flyTo(
          mb.CameraOptions(
            center: mb.Point(coordinates: mb.Position(lng, lat)),
            zoom: zoom ?? 15,
          ),
          mb.MapAnimationOptions(duration: 500));
      _updateMarker();
    } catch (_) {}
  }

  void _zoomToTrackedUser() {
    if (_location != null) {
      _moveCamera(_location!.lat, _location!.lng, 15);
    }
  }

  Future<void> _zoomToMyLocation() async {
    try {
      final myLoc = await LocationHelper.getCurrentPosition();
      if (myLoc != null) {
        _moveCamera(myLoc.latitude, myLoc.longitude, 15);
      } else {
        SnackbarHelper.error('sc_pts_get_location_error'.tr);
      }
    } catch (e) {
      SnackbarHelper.error('${'sc_pts_get_location_error'.tr}: $e');
    }
  }

  @override
  void dispose() {
    _signalR.disconnectPublicTracking();
    try {
      if (_pointAnnotationManager != null) {
        _pointAnnotationManager?.deleteAll();
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: LoadingWidget(message: 'sc_pts_loading_location'.tr),
      );
    }

    if (_error || _location == null) {
      return Scaffold(
        appBar: AppBar(title: Text('sc_pts_tracking'.tr)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'sc_pts_link_invalid'.tr,
                  style: AppTextStyles.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'sc_pts_ask_resend'.tr,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final loc = _location!;

    return Scaffold(
      body: Stack(
        children: [
          mb.MapWidget(
            key: const ValueKey('public_tracking_map'),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoadedListener,
            cameraOptions: mb.CameraOptions(
              center: mb.Point(coordinates: mb.Position(loc.lng, loc.lat)),
              zoom: 15.0,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.black.withValues(alpha: 0.65),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'sc_pts_tracking_user'.trParams({'name': loc.fullName}),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, size: 8, color: AppColors.error),
                            const SizedBox(width: 4),
                            Text(
                              'sc_pts_live'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'btn_my_location',
                      onPressed: _zoomToMyLocation,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location, color: AppColors.brand),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'btn_tracked_location',
                      onPressed: _zoomToTrackedUser,
                      backgroundColor: AppColors.brand,
                      child: const Icon(Icons.person_pin_circle, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
