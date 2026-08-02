import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../controllers/staff_map_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/loading_widget.dart';

const Color _kBrand = AppColors.brand;

class StaffMapScreen extends StatefulWidget {
  const StaffMapScreen({super.key});

  @override
  State<StaffMapScreen> createState() => _StaffMapScreenState();
}

class _StaffMapScreenState extends State<StaffMapScreen> {
  late StaffMapController c;

  @override
  void initState() {
    super.initState();
    c = Get.find<StaffMapController>();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Customer Locations',
      body: Obx(() {
        if (c.isLoading.value && c.liveLocations.isEmpty && c.routeDays.isEmpty) {
          return const LoadingWidget(message: 'Loading map...');
        }
        return Stack(
          children: [
            mb.MapWidget(
              key: const ValueKey("staffMapWidget"),
              onMapCreated: c.onMapCreated,
              onStyleLoadedListener: c.onStyleLoaded,
              onTapListener: c.handleMapTap,
              styleUri: mb.MapboxStyles.MAPBOX_STREETS,
            ),

            // Day Selector Overlay
            if (c.showRoute.value && c.routeDays.isNotEmpty)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Container(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: c.routeDays.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final bool isOverview = i == 0;
                      final bool selected = isOverview
                          ? c.selectedDay.value == null
                          : c.selectedDay.value == c.routeDays[i - 1].dayNumber;
                      final String label = isOverview ? 'Overview' : 'Day ${c.routeDays[i - 1].dayNumber}';

                      return GestureDetector(
                        onTap: () {
                          if (isOverview) {
                            c.selectDay(null);
                          } else {
                            c.selectDay(c.routeDays[i - 1].dayNumber);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.brand : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            
            // Map controls overlay
            Positioned(
              right: 12,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'staff_recenter',
                    backgroundColor: Colors.white,
                    onPressed: c.recenter,
                    child: const Icon(Icons.my_location_rounded, color: _kBrand),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_rounded, color: _kBrand),
                          onPressed: c.zoomIn,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                        Container(height: 1, width: 24, color: Colors.grey.shade200),
                        IconButton(
                          icon: const Icon(Icons.remove_rounded, color: _kBrand),
                          onPressed: c.zoomOut,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                        Container(height: 1, width: 24, color: Colors.grey.shade200),
                        IconButton(
                          icon: Icon(
                            c.showRoute.value ? Icons.route_rounded : Icons.route_outlined,
                            color: c.showRoute.value ? AppColors.brand : Colors.black54,
                          ),
                          onPressed: () => c.showRoute.toggle(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                        Container(height: 1, width: 24, color: Colors.grey.shade200),
                        IconButton(
                          icon: Icon(
                            c.showMoments.value ? Icons.photo_library_rounded : Icons.photo_library_outlined,
                            color: c.showMoments.value ? AppColors.brand : Colors.black54,
                          ),
                          onPressed: () => c.showMoments.toggle(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
