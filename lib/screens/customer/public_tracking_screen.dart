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

  @override
  void initState() {
    super.initState();
    _token = Get.parameters['token'] ?? '';
    mb.MapboxOptions.setAccessToken(ApiConstants.mapboxAccessToken);

    if (_token.isEmpty) {
      _error = true;
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

      await _signalR.connectPublicTracking(
        token: _token,
        onLocationUpdate: (lat, lng) {
          if (!mounted) return;
          setState(() {
            _location = PublicLocationModel(
              lat: lat,
              lng: lng,
              fullName: _location?.fullName ?? 'Khách',
            );
          });

          if (_mapboxMap != null) {
            _mapboxMap!.getCameraState().then((state) {
              _moveCamera(lat, lng, state.zoom);
            });
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    mapboxMap.annotations.createPointAnnotationManager().then((manager) {
      _pointAnnotationManager = manager;
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

      _marker = await _pointAnnotationManager?.create(mb.PointAnnotationOptions(
        geometry:
            mb.Point(coordinates: mb.Position(_location!.lng, _location!.lat)),
        iconSize: 2.0,
        iconColor: AppColors.error.value,
      ));
    } catch (e) {
      debugPrint('Error updating marker: $e');
    }
  }

  void _moveCamera(double lat, double lng, double? zoom) {
    if (_mapboxMap == null) return;
    try {
      _mapboxMap!.flyTo(
          mb.CameraOptions(
            center: mb.Point(coordinates: mb.Position(lng, lat)),
            zoom: zoom ?? 15,
          ),
          mb.MapAnimationOptions(duration: 500));
      _updateMarker();
    } catch (_) {}
  }

  @override
  void dispose() {
    _signalR.disconnectPublicTracking();
    if (_pointAnnotationManager != null) {
      _pointAnnotationManager?.deleteAll();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Đang tải vị trí...'),
      );
    }

    if (_error || _location == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Theo dõi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Liên kết không hợp lệ hoặc đã hết hạn',
                  style: AppTextStyles.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vui lòng yêu cầu người chia sẻ gửi lại mã theo dõi mới.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
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
                          'Đang theo dõi ${loc.fullName}',
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: AppColors.error),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
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
        ],
      ),
    );
  }
}
