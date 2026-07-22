import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/api_constants.dart';
import '../../models/ai_models.dart';
import '../../services/signalr_service.dart';
import '../../services/social_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/loading_widget.dart';

/// Theo dõi vị trí công khai qua token — `/track/:token` (giống web).
class PublicTrackingScreen extends StatefulWidget {
  const PublicTrackingScreen({super.key});

  @override
  State<PublicTrackingScreen> createState() => _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends State<PublicTrackingScreen> {
  final _social = Get.find<SocialService>();
  final _signalR = Get.find<SignalRService>();
  final _mapController = MapController();

  late final String _token;
  PublicLocationModel? _location;
  var _loading = true;
  var _error = false;

  @override
  void initState() {
    super.initState();
    _token = Get.parameters['token'] ?? '';
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
      _mapController.move(LatLng(loc.lat, loc.lng), 15);
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
          _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
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

  @override
  void dispose() {
    _signalR.disconnectPublicTracking();
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
                Icon(Icons.link_off, size: 56, color: Colors.red.shade300),
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
    final point = LatLng(loc.lat, loc.lng);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: ApiConstants.mapboxTileUrl,
                additionalOptions: const {
                  'accessToken': ApiConstants.mapboxAccessToken,
                },
                userAgentPackageName: 'com.stayhub.mobile',
                maxZoom: 19,
                tileSize: 256,
                zoomOffset: -1,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_pin,
                      color: AppColors.brand,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
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
                          color: Colors.red.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: Colors.red),
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
