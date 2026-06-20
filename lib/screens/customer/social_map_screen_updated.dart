// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:get/get.dart';
// import 'package:latlong2/latlong.dart';
// // import '../../controllers/feature_controllers.dart';
// import '../../controllers/feature_controllers.dart';
// import '../../models/feature_models.dart';
// import '../../services/location_helper.dart';
//
// /// Social Map Screen - Display tour route, live locations, and footprints
// /// Implements UC-32 and UC-33 for location sharing and tracking
// class SocialMapScreen extends StatefulWidget {
//   final int scheduleId;
//
//   const SocialMapScreen({
//     Key? key,
//     required this.scheduleId,
//   }) : super(key: key);
//
//   @override
//   State<SocialMapScreen> createState() => _SocialMapScreenState();
// }
//
// class _SocialMapScreenState extends State<SocialMapScreen> {
//   late final SocialController _controller;
//   late final MapController _mapController;
//   final LocationHelper _locationHelper = Get.find();
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = Get.find<SocialController>();
//     _mapController = MapController();
//
//     // Initialize map data
//     _initializeMapData();
//   }
//
//   Future<void> _initializeMapData() async {
//     await Future.wait([
//       _controller.loadScheduleLiveLocations(widget.scheduleId),
//       _controller.loadTourRoute(widget.scheduleId),
//       _controller.loadMyFootprints(),
//     ]);
//   }
//
//   @override
//   void dispose() {
//     _mapController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Tour Map'),
//         centerTitle: true,
//         elevation: 0,
//         actions: [
//           // Footprints toggle
//           Obx(
//             () => IconButton(
//               icon: Icon(
//                 _controller.showFootprints.value
//                     ? Icons.location_history
//                     : Icons.location_history_outlined,
//               ),
//               tooltip: 'Toggle footprints',
//               onPressed: _controller.toggleFootprints,
//             ),
//           ),
//           // Location tracking toggle
//           Obx(
//             () => IconButton(
//               icon: Icon(
//                 _controller.isLocationTrackingActive.value
//                     ? Icons.location_on
//                     : Icons.location_on_outlined,
//               ),
//               tooltip: _controller.isLocationTrackingActive.value
//                   ? 'Stop tracking'
//                   : 'Start tracking',
//               onPressed: () => _toggleLocationTracking(),
//             ),
//           ),
//         ],
//       ),
//       body: Obx(
//         () => FlutterMap(
//           mapController: _mapController,
//           options: MapOptions(
//             initialCenter: LatLng(
//               _controller.currentPosition.value?.latitude ?? 10.7769,
//               _controller.currentPosition.value?.longitude ?? 106.7009,
//             ),
//             initialZoom: 14,
//             minZoom: 5,
//             maxZoom: 18,
//           ),
//           children: [
//             // OpenStreetMap tile layer
//             TileLayer(
//               urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//               userAgent: 'SEP490-Mobile-App',
//               maxZoom: 18,
//             ),
//
//             // Tour route polyline (blue solid line)
//             if (_controller.tourRoute.isNotEmpty)
//               PolylineLayer(
//                 polylines: [
//                   Polyline(
//                     points: _controller.tourRoute
//                         .map((p) => LatLng(p['lat']!, p['lng']!))
//                         .toList(),
//                     color: Colors.blue,
//                     strokeWidth: 4,
//                   ),
//                 ],
//               ),
//
//             // Footprints layer (orange transparent line)
//             if (_controller.showFootprints.value &&
//                 _controller.myFootprints.isNotEmpty)
//               PolylineLayer(
//                 polylines: [
//                   Polyline(
//                     points: _controller.myFootprints
//                         .map((f) => LatLng(f.lat, f.lng))
//                         .toList(),
//                     color: Colors.orange.withOpacity(0.6),
//                     strokeWidth: 3,
//                   ),
//                 ],
//               ),
//
//             // Current user marker (blue circle)
//             if (_controller.currentPosition.value != null)
//               MarkerLayer(
//                 markers: [
//                   Marker(
//                     point: LatLng(
//                       _controller.currentPosition.value!.latitude,
//                       _controller.currentPosition.value!.longitude,
//                     ),
//                     width: 40,
//                     height: 40,
//                     child: Container(
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: Colors.blue,
//                         border: Border.all(color: Colors.white, width: 2),
//                       ),
//                       child: const Icon(
//                         Icons.navigation,
//                         color: Colors.white,
//                         size: 20,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//
//             // Live location markers (green circles for others)
//             MarkerLayer(
//               markers: _buildLiveLocationMarkers(),
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: _buildFloatingActionButtons(),
//     );
//   }
//
//   /// Build markers for live friend locations
//   List<Marker> _buildLiveLocationMarkers() {
//     return _controller.liveLocations
//         .map((location) => Marker(
//               point: LatLng(location.latitude, location.longitude),
//               width: 40,
//               height: 40,
//               child: GestureDetector(
//                 onTap: () => _showLocationInfo(location),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: Colors.green,
//                     border: Border.all(color: Colors.white, width: 2),
//                   ),
//                   child: Center(
//                     child: Text(
//                       location.fullName.characters.first.toUpperCase(),
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ))
//         .toList();
//   }
//
//   /// Show info about a location marker
//   void _showLocationInfo(LiveLocationModel location) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => Container(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               location.fullName,
//               style: Theme.of(context).textTheme.titleMedium,
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Location: ${location.latitude.toStringAsFixed(4)}, '
//               '${location.longitude.toStringAsFixed(4)}',
//               style: Theme.of(context).textTheme.bodySmall,
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Updated: ${location.updatedAt.toString().split('.')[0]}',
//               style: Theme.of(context).textTheme.labelSmall,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Close'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// Build floating action buttons for map controls
//   Widget _buildFloatingActionButtons() {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         // Refresh locations button
//         FloatingActionButton.small(
//           onPressed: () => _refreshLocations(),
//           tooltip: 'Refresh locations',
//           heroTag: 'refresh',
//           child: const Icon(Icons.refresh),
//         ),
//         const SizedBox(height: 8),
//
//         // Center on current position button
//         FloatingActionButton.small(
//           onPressed: () => _centerOnPosition(),
//           tooltip: 'Center on my location',
//           heroTag: 'center',
//           child: const Icon(Icons.my_location),
//         ),
//         const SizedBox(height: 8),
//
//         // Share location link button
//         FloatingActionButton.small(
//           onPressed: () => _shareLocationToken(),
//           tooltip: 'Share my location',
//           heroTag: 'share',
//           child: const Icon(Icons.share_location),
//         ),
//       ],
//     );
//   }
//
//   /// Refresh live locations from server
//   Future<void> _refreshLocations() async {
//     await _controller.loadScheduleLiveLocations(widget.scheduleId);
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Locations updated'),
//           duration: Duration(seconds: 1),
//         ),
//       );
//     }
//   }
//
//   /// Center map on current position
//   Future<void> _centerOnPosition() async {
//     try {
//       final position = await _locationHelper.getCurrentPosition();
//       _mapController.move(
//         LatLng(position.latitude, position.longitude),
//         _mapController.camera.zoom,
//       );
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: $e')),
//         );
//       }
//     }
//   }
//
//   /// Toggle location tracking on/off
//   void _toggleLocationTracking() {
//     if (_controller.isLocationTrackingActive.value) {
//       _controller.stopLocationTracking();
//     } else {
//       _controller.startLocationTracking(widget.scheduleId);
//     }
//   }
//
//   /// Share location via token
//   Future<void> _shareLocationToken() async {
//     final token = await _controller.shareLocationToken();
//     if (token.isNotEmpty && mounted) {
//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('Share Location'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Text('Share this token to let others see your location:'),
//               const SizedBox(height: 16),
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[200],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: SelectableText(token),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Close'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 // Copy to clipboard would go here
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Token copied to clipboard'),
//                     duration: Duration(seconds: 1),
//                   ),
//                 );
//               },
//               child: const Text('Copy'),
//             ),
//           ],
//         ),
//       );
//     }
//   }
// }
