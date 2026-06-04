import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../services/location_helper.dart';
import '../../services/signalr_service.dart';
import '../../services/social_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class SocialMapScreen extends StatefulWidget {
  const SocialMapScreen({super.key});

  @override
  State<SocialMapScreen> createState() => _SocialMapScreenState();
}

class _SocialMapScreenState extends State<SocialMapScreen> {
  final _orderController = Get.find<OrderController>();
  final _socialService = Get.find<SocialService>();
  final _signalR = Get.find<SignalRService>();
  final _mapController = MapController();

  var _locations = <LiveLocationModel>[];
  var _loading = true;
  var _sharing = false;
  int? _selectedScheduleId;
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _orderController.fetchEligibleSchedules();
    if (_orderController.eligibleSchedules.isNotEmpty) {
      _selectedScheduleId =
          _orderController.eligibleSchedules.first.scheduleId;
      await _loadSchedule(_selectedScheduleId!);
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSchedule(int scheduleId) async {
    setState(() => _loading = true);
    _selectedScheduleId = scheduleId;
    try {
      _locations =
          await _socialService.getScheduleLiveLocations(scheduleId);
      await _signalR.disconnectTracking();
      await _signalR.connectTracking(
        onLocationUpdate: (loc) {
          setState(() {
            final idx =
                _locations.indexWhere((l) => l.userId == loc.userId);
            if (idx >= 0) {
              _locations[idx] = loc;
            } else {
              _locations.add(loc);
            }
          });
        },
      );
      await _signalR.joinTourTrackingGroup(scheduleId);
      _fitBounds();
    } catch (e) {
      SnackbarHelper.error(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fitBounds() {
    if (_locations.isEmpty) return;
    final points = _locations
        .map((l) => LatLng(l.latitude, l.longitude))
        .toList();
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  Future<void> _toggleShareLocation() async {
    if (_selectedScheduleId == null) return;
    if (_sharing) {
      _pingTimer?.cancel();
      setState(() => _sharing = false);
      return;
    }
    final ok = await LocationHelper.ensurePermission();
    if (!ok) {
      SnackbarHelper.error('Cần quyền vị trí để chia sẻ');
      return;
    }
    setState(() => _sharing = true);
    await Get.find<SocialController>()
        .shareLocationPing(_selectedScheduleId!);
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      Get.find<SocialController>()
          .shareLocationPing(_selectedScheduleId!);
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _signalR.disconnectTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Social Map',
      actions: [
        IconButton(
          icon: Icon(
            _sharing ? Icons.location_on_rounded : Icons.location_off_rounded,
          ),
          color: _sharing ? Colors.red : null,
          onPressed: _toggleShareLocation,
          tooltip: 'Chia sẻ vị trí',
        ),
      ],
      body: Column(
        children: [
          Obx(() {
            final schedules = _orderController.eligibleSchedules;
            if (schedules.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Đặt tour để xem lịch trình trên bản đồ'),
              );
            }
            return SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: schedules.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final s = schedules[index];
                  final selected = _selectedScheduleId == s.scheduleId;
                  return ChoiceChip(
                    label: Text(s.tourName),
                    selected: selected,
                    onSelected: (_) => _loadSchedule(s.scheduleId),
                  );
                },
              ),
            );
          }),
          Expanded(
            child: _loading
                ? const LoadingWidget(message: 'Đang tải bản đồ...')
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(16.047079, 108.206230),
                      initialZoom: 6,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.stayhub.mobile',
                      ),
                      MarkerLayer(
                        markers: _locations.map((loc) {
                          return Marker(
                            point: LatLng(loc.latitude, loc.longitude),
                            width: 120,
                            height: 60,
                            child: Column(
                              children: [
                                const Icon(Icons.person_pin_circle,
                                    color: Colors.red, size: 32),
                                Text(
                                  loc.fullName ?? '#${loc.userId}',
                                  style: const TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
          ),
          if (_locations.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: _locations.length,
                itemBuilder: (context, index) {
                  final loc = _locations[index];
                  return IosSurfaceCard(
                    margin: const EdgeInsets.only(right: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.fullName ?? 'User #${loc.userId}'),
                        Text(
                          '${loc.latitude.toStringAsFixed(4)}, '
                          '${loc.longitude.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
