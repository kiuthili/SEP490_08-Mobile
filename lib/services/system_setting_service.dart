import 'package:get/get.dart';
import 'base_service.dart';

class SystemSettingService extends GetxService with BaseServiceMixin {
  final Map<String, String> _cache = {};
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllSettings();
  }

  Future<void> fetchAllSettings() async {
    try {
      isLoading.value = true;
      final response = await request(() => api.get('/api/system-settings'));
      if (response is List) {
        for (var item in response) {
          if (item is Map<String, dynamic> && item.containsKey('settingKey')) {
            _cache[item['settingKey']] = item['settingValue']?.toString() ?? '';
          }
        }
      }
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  String? getSettingSync(String key) {
    return _cache[key];
  }

  Future<String?> getSetting(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final response = await request(() => api.get('/api/system-settings/$key'));
      if (response is Map<String, dynamic> && response.containsKey('settingValue')) {
        final val = response['settingValue'] as String?;
        if (val != null) _cache[key] = val;
        return val;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
