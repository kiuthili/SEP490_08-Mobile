import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationHelper {
  LocationHelper._();

  static Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
      return false;
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<Position?> getCurrentPosition() async {
    if (!await ensurePermission()) return null;
    try {
      // 1. Thử lấy vị trí cuối cùng được OS lưu (nhanh và chạy tốt trong nhà)
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;

      // 2. Nếu không có, quét GPS mới với giới hạn thời gian (timeLimit) 4 giây để tránh treo
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
        timeLimit: const Duration(seconds: 4),
      );
    } catch (_) {
      try {
        // Fallback sang độ chính xác thấp hơn nếu quét GPS chính xác cao bị timeout
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
          ),
          timeLimit: const Duration(seconds: 3),
        );
      } catch (_) {
        return null;
      }
    }
  }
}
