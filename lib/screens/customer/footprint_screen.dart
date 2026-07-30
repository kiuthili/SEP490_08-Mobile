import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:get/get.dart';
import '../../constants/api_constants.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';
import 'package:stayhub_mobile/theme/app_text_styles.dart';

class VisitedLocation {
  final String name;
  final String country;
  final String date;
  final mb.Position gps;
  final IconData icon;
  final Color themeColor;

  VisitedLocation({
    required this.name,
    required this.country,
    required this.date,
    required this.gps,
    required this.icon,
    required this.themeColor,
  });
}

class FootprintScreen extends StatefulWidget {
  const FootprintScreen({super.key});

  @override
  State<FootprintScreen> createState() => _FootprintScreenState();
}

class _FootprintScreenState extends State<FootprintScreen> {
  mb.MapboxMap? _mapboxMap;
  mb.PolygonAnnotationManager? _polygonAnnotationManager;
  mb.PointAnnotationManager? _pointAnnotationManager;
  final List<mb.PointAnnotation> _pointAnnotations = [];

  int _activeLocationIndex = 0;

  final List<VisitedLocation> _locations = [
    VisitedLocation(
      name: 'Vịnh Hạ Long',
      country: 'Việt Nam',
      date: 'Tháng 7, 2026',
      gps: mb.Position(107.1839, 20.9101),
      icon: Icons.sailing_outlined,
      themeColor: const Color(0xFF00FFCC),
    ),
    VisitedLocation(
      name: 'Hà Nội',
      country: 'Việt Nam',
      date: 'Tháng 6, 2026',
      gps: mb.Position(105.8542, 21.0285),
      icon: Icons.location_city_outlined,
      themeColor: const Color(0xFF00E5FF),
    ),
    VisitedLocation(
      name: 'Phố cổ Hội An',
      country: 'Việt Nam',
      date: 'Tháng 5, 2026',
      gps: mb.Position(108.3380, 15.8801),
      icon: Icons.temple_buddhist_outlined,
      themeColor: const Color(0xFFFFCC00),
    ),
    VisitedLocation(
      name: 'Singapore',
      country: 'Singapore',
      date: 'Tháng 2, 2026',
      gps: mb.Position(103.8198, 1.3521),
      icon: Icons.apartment_outlined,
      themeColor: const Color(0xFFFF3366),
    ),
    VisitedLocation(
      name: 'Kyoto',
      country: 'Nhật Bản',
      date: 'Tháng 11, 2025',
      gps: mb.Position(135.7681, 35.0116),
      icon: Icons.castle_outlined,
      themeColor: const Color(0xFFFF9900),
    ),
    VisitedLocation(
      name: 'Tokyo',
      country: 'Nhật Bản',
      date: 'Tháng 10, 2025',
      gps: mb.Position(139.6503, 35.6762),
      icon: Icons.webhook_outlined,
      themeColor: const Color(0xFF3399FF),
    ),
    VisitedLocation(
      name: 'Rome',
      country: 'Ý',
      date: 'Tháng 7, 2025',
      gps: mb.Position(12.4964, 41.9028),
      icon: Icons.account_balance_outlined,
      themeColor: const Color(0xFFA352FF),
    ),
    VisitedLocation(
      name: 'Paris',
      country: 'Pháp',
      date: 'Tháng 6, 2025',
      gps: mb.Position(2.3522, 48.8566),
      icon: Icons.museum_outlined,
      themeColor: const Color(0xFF00FF66),
    ),
  ];

  @override
  void initState() {
    super.initState();
    mb.MapboxOptions.setAccessToken(ApiConstants.mapboxAccessToken);
  }

  List<mb.Position> _generateCirclePoints(
      mb.Position center, double radiusInDegrees,
      {int segments = 36}) {
    final List<mb.Position> points = [];
    final lat = center.lat as double;
    final lng = center.lng as double;
    for (int i = 0; i < segments; i++) {
      final double angle = (i * 360 / segments) * math.pi / 180;
      final double pLat = lat + radiusInDegrees * math.sin(angle);
      final double cosLat = math.cos(lat * math.pi / 180);
      final double pLng = lng +
          radiusInDegrees * math.cos(angle) / (cosLat == 0 ? 1.0 : cosLat);
      points.add(mb.Position(pLng, pLat));
    }
    // Đóng kín lỗ bằng cách thêm điểm đầu tiên vào cuối
    points.add(points.first);
    return points;
  }

  void _onLocationTap(int index) {
    setState(() {
      _activeLocationIndex = index;
    });
    if (_mapboxMap != null) {
      _mapboxMap!.flyTo(
          mb.CameraOptions(
            center: mb.Point(coordinates: _locations[index].gps),
            zoom: 6.0,
          ),
          mb.MapAnimationOptions(duration: 800));
      _drawFogOfWar();
      _syncMarkers();
    }
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    mapboxMap.annotations.createPointAnnotationManager().then((manager) {
      _pointAnnotationManager = manager;
      _syncMarkers();
    });
    mapboxMap.annotations.createPolygonAnnotationManager().then((manager) {
      _polygonAnnotationManager = manager;
      _drawFogOfWar();
    });
  }

  void _drawFogOfWar() {
    if (_polygonAnnotationManager == null) return;

    _polygonAnnotationManager!.deleteAll();

    // The outer boundary covering the whole world
    final outerBoundary = [
      mb.Position(-180.0, 85.0),
      mb.Position(180.0, 85.0),
      mb.Position(180.0, -85.0),
      mb.Position(-180.0, -85.0),
      mb.Position(-180.0, 85.0),
    ];

    // Generate circular cutout hole coordinates for all visited places
    final List<List<mb.Position>> coordinates = [outerBoundary];

    for (int i = 0; i < _locations.length; i++) {
      final loc = _locations[i];
      final isSelected = i == _activeLocationIndex;
      final double radius = isSelected ? 1.2 : 0.6;
      coordinates.add(_generateCirclePoints(loc.gps, radius));
    }

    _polygonAnnotationManager!.create(mb.PolygonAnnotationOptions(
      geometry: mb.Polygon(coordinates: coordinates),
      fillColor: Colors.black.withValues(alpha: 0.6).value,
      fillOutlineColor: Colors.transparent.value,
    ));
  }

  void _syncMarkers() async {
    if (_mapboxMap == null || _pointAnnotationManager == null) return;

    await _pointAnnotationManager!.deleteAll();
    _pointAnnotations.clear();

    final options = <mb.PointAnnotationOptions>[];
    for (int i = 0; i < _locations.length; i++) {
      final loc = _locations[i];
      final isSelected = i == _activeLocationIndex;

      options.add(mb.PointAnnotationOptions(
        geometry: mb.Point(coordinates: loc.gps),
        textField: loc.name,
        textSize: isSelected ? 16.0 : 12.0,
        textColor: isSelected ? loc.themeColor.value : Colors.white.value,
        textHaloColor: Colors.black.value,
        textHaloWidth: 1.0,
        textOffset: [0.0, -1.0],
      ));
    }

    try {
      final annotations = await _pointAnnotationManager!.createMulti(options);
      _pointAnnotations.addAll(
          annotations.where((a) => a != null).cast<mb.PointAnnotation>());
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_pointAnnotationManager != null) {
      _pointAnnotationManager!.deleteAll();
    }
    if (_polygonAnnotationManager != null) {
      _polygonAnnotationManager!.deleteAll();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const int countryCount = 4;
    const int cityCount = 7;
    final int placeCount = _locations.length;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Live Map with custom Fog of War Polygon Mask Layer
          Positioned.fill(
            child: mb.MapWidget(
              key: const ValueKey('footprint_map'),
              onMapCreated: _onMapCreated,
              styleUri: mb.MapboxStyles.DARK,
              cameraOptions: mb.CameraOptions(
                center:
                    mb.Point(coordinates: _locations[_activeLocationIndex].gps),
                zoom: 6.0,
              ),
            ),
          ),

          // 2. Top Overlay: Transparent Custom AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: NavigationToolbar(
                leading: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Get.back(),
                    tooltip: 'Trở về',
                  ),
                ),
                middle: Text(
                  'My Footprint',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                centerMiddle: true,
              ),
            ),
          ),

          // 3. Bottom Sheet (The Stats Panel)
          Positioned.fill(
            child: DraggableScrollableSheet(
              initialChildSize: 0.38,
              minChildSize: 0.20,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.20, 0.38, 0.85],
              builder: (context, scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Pill Drag Handle
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Stats Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn('Countries', countryCount),
                              Container(
                                width: 1,
                                height: 32,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              _buildStatColumn('Cities', cityCount),
                              Container(
                                width: 1,
                                height: 32,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              _buildStatColumn('Places', placeCount),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                          height: 1,
                          thickness: 1,
                        ),

                        // Visited Places List
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _locations.length,
                            itemBuilder: (context, index) {
                              final loc = _locations[index];
                              final isSelected = index == _activeLocationIndex;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                      color: isSelected
                                          ? loc.themeColor
                                              .withValues(alpha: 0.3)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    onTap: () => _onLocationTap(index),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: loc.themeColor
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: loc.themeColor
                                              .withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        loc.icon,
                                        color: loc.themeColor,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      loc.name,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      loc.country,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          loc.date,
                                          style:
                                              AppTextStyles.bodyMedium.copyWith(
                                            color: Colors.white
                                                .withValues(alpha: 0.4),
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: loc.themeColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: loc.themeColor,
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                )
                                              ],
                                            ),
                                          )
                                        ]
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
