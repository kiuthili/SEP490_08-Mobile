import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/feature_controllers.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';

class StaffCustomersTab extends GetView<StaffController> {
  const StaffCustomersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Khách hàng & Vị trí'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Khách tour'),
              Tab(text: 'Vị trí live'),
              Tab(text: 'Bản đồ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Obx(() {
              if (controller.customers.isEmpty) {
                return const EmptyStateWidget(
                  title: 'Chưa có khách',
                  subtitle: 'Chọn lịch trình ở tab Lịch trình',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16).copyWith(
                  bottom: ShellLayout.bottomInset(context),
                ),
                itemCount: controller.customers.length,
                itemBuilder: (context, index) {
                  final c = controller.customers[index];
                  return IosSurfaceCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (c.fullName?.isNotEmpty == true
                                  ? c.fullName![0]
                                  : '?')
                              .toUpperCase(),
                        ),
                      ),
                      title: Text(c.fullName ?? 'Khách #${c.customerId}'),
                      subtitle: Text(
                        '${c.email ?? ''}\n${c.phoneNumber ?? ''}',
                      ),
                      trailing: Chip(label: Text('${c.ticketCount} vé')),
                    ),
                  );
                },
              );
            }),
            Obx(() {
              if (controller.liveLocations.isEmpty) {
                return const EmptyStateWidget(
                  title: 'Chưa có vị trí',
                  subtitle: 'Khách chưa chia sẻ vị trí',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16).copyWith(
                  bottom: ShellLayout.bottomInset(context),
                ),
                itemCount: controller.liveLocations.length,
                itemBuilder: (context, index) {
                  final loc = controller.liveLocations[index];
                  return IosSurfaceCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.red,
                      ),
                      title: Text(loc.fullName ?? 'User #${loc.userId}'),
                      subtitle: Text(
                        'Lat: ${loc.latitude.toStringAsFixed(4)}, '
                        'Lng: ${loc.longitude.toStringAsFixed(4)}',
                      ),
                    ),
                  );
                },
              );
            }),
            Obx(() {
              if (controller.liveLocations.isEmpty) {
                return const Center(child: Text('Chưa có dữ liệu vị trí'));
              }
              final locs = controller.liveLocations;
              final center = LatLng(locs.first.latitude, locs.first.longitude);
              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 1 || constraints.maxWidth < 1) {
                    return const SizedBox.shrink();
                  }
                  return SizedBox(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.stayhub.mobile',
                        ),
                        MarkerLayer(
                          markers: locs.map((loc) {
                            return Marker(
                              point: LatLng(loc.latitude, loc.longitude),
                              width: 100,
                              height: 50,
                              child: Column(
                                children: [
                                  const Icon(Icons.person_pin_circle,
                                      color: Colors.red),
                                  Text(
                                    loc.fullName ?? '#${loc.userId}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
