import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/api_constants.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';
import 'package:stayhub_mobile/theme/app_text_styles.dart';

class VisitedLocation {
  final String name;
  final String country;
  final String date;
  final LatLng gps;
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
  final MapController _mapController = MapController();
  int _activeLocationIndex = 0;

  final List<VisitedLocation> _locations = [
    VisitedLocation(
      name: 'Vịnh Hạ Long',
      country: 'Việt Nam',
      date: 'Tháng 7, 2026',
      gps: const LatLng(20.9101, 107.1839),
      icon: Icons.sailing_outlined,
      themeColor: const Color(0xFF00FFCC),
    ),
    VisitedLocation(
      name: 'Hà Nội',
      country: 'Việt Nam',
      date: 'Tháng 6, 2026',
      gps: const LatLng(21.0285, 105.8542),
      icon: Icons.location_city_outlined,
      themeColor: const Color(0xFF00E5FF),
    ),
    VisitedLocation(
      name: 'Phố cổ Hội An',
      country: 'Việt Nam',
      date: 'Tháng 5, 2026',
      gps: const LatLng(15.8801, 108.3380),
      icon: Icons.temple_buddhist_outlined,
      themeColor: const Color(0xFFFFCC00),
    ),
    VisitedLocation(
      name: 'Singapore',
      country: 'Singapore',
      date: 'Tháng 2, 2026',
      gps: const LatLng(1.3521, 103.8198),
      icon: Icons.apartment_outlined,
      themeColor: const Color(0xFFFF3366),
    ),
    VisitedLocation(
      name: 'Kyoto',
      country: 'Nhật Bản',
      date: 'Tháng 11, 2025',
      gps: const LatLng(35.0116, 135.7681),
      icon: Icons.castle_outlined,
      themeColor: const Color(0xFFFF9900),
    ),
    VisitedLocation(
      name: 'Tokyo',
      country: 'Nhật Bản',
      date: 'Tháng 10, 2025',
      gps: const LatLng(35.6762, 139.6503),
      icon: Icons.webhook_outlined,
      themeColor: const Color(0xFF3399FF),
    ),
    VisitedLocation(
      name: 'Rome',
      country: 'Ý',
      date: 'Tháng 7, 2025',
      gps: const LatLng(41.9028, 12.4964),
      icon: Icons.account_balance_outlined,
      themeColor: const Color(0xFFA352FF),
    ),
    VisitedLocation(
      name: 'Paris',
      country: 'Pháp',
      date: 'Tháng 6, 2025',
      gps: const LatLng(48.8566, 2.3522),
      icon: Icons.museum_outlined,
      themeColor: const Color(0xFF00FF66),
    ),
  ];

  List<LatLng> _generateCirclePoints(LatLng center, double radiusInDegrees,
      {int segments = 36}) {
    final List<LatLng> points = [];
    for (int i = 0; i < segments; i++) {
      final double angle = (i * 360 / segments) * math.pi / 180;
      final double lat = center.latitude + radiusInDegrees * math.sin(angle);
      final double cosLat = math.cos(center.latitude * math.pi / 180);
      final double lng = center.longitude +
          radiusInDegrees * math.cos(angle) / (cosLat == 0 ? 1.0 : cosLat);
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  void _onLocationTap(int index) {
    setState(() {
      _activeLocationIndex = index;
    });
    _mapController.move(_locations[index].gps, 8.0);
  }

  @override
  Widget build(BuildContext context) {
    const int countryCount = 4;
    const int cityCount = 7;
    final int placeCount = _locations.length;

    // Generate circular cutout hole coordinates for all visited places
    final List<List<LatLng>> holes = _locations.map((loc) {
      final isSelected = loc == _locations[_activeLocationIndex];
      // Selected place gets a slightly larger cutout radius
      final double radius = isSelected ? 1.2 : 0.6;
      return _generateCirclePoints(loc.gps, radius);
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          // 1. Live Map with custom Fog of War Polygon Mask Layer
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _locations[_activeLocationIndex].gps,
                initialZoom: 6,
                minZoom: 2,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token=${ApiConstants.mapboxAccessToken}',
                  userAgentPackageName: 'com.stayhub.stayhub_mobile',
                  maxZoom: 18,
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: const [
                        LatLng(85.0, -180.0), // Đổi 90 thành 85.0
                        LatLng(85.0, 180.0), // Đổi 90 thành 85.0
                        LatLng(-85.0, 180.0), // Đổi -90 thành -85.0
                        LatLng(-85.0, -180.0),
                      ],
                      holePointsList: holes,
                      color: Colors.black
                          .withValues(alpha: 0.6), // The dark fog overlay
                      borderStrokeWidth: 0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: _locations.map((loc) {
                    final isSelected = loc == _locations[_activeLocationIndex];
                    return Marker(
                      point: loc.gps,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          final idx = _locations.indexOf(loc);
                          _onLocationTap(idx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: isSelected ? loc.themeColor : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: loc.themeColor.withValues(alpha: 0.5),
                                blurRadius: isSelected ? 8 : 4,
                                spreadRadius: isSelected ? 2 : 1,
                              )
                            ],
                          ),
                          child: Icon(
                            loc.icon,
                            color: isSelected ? Colors.black : loc.themeColor,
                            size: isSelected ? 24 : 18,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
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
