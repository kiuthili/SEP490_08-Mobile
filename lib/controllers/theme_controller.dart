import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Quản lý Dark / Light Mode toàn app.
/// Lưu lựa chọn của user vào GetStorage (persist qua lần mở lại).
class ThemeController extends GetxController {
  static const _key = 'themeMode';
  final _box = GetStorage();

  /// Reactive ThemeMode
  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final saved = _box.read<String>(_key);
    if (saved == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else if (saved == 'light') {
      themeMode.value = ThemeMode.light;
    } else {
      themeMode.value = ThemeMode.system;
    }
  }

  bool get isDark {
    if (themeMode.value == ThemeMode.system) {
      return Get.isPlatformDarkMode;
    }
    return themeMode.value == ThemeMode.dark;
  }

  /// Toggle giữa Dark / Light (bỏ qua system)
  void toggleTheme() {
    if (isDark) {
      setLight();
    } else {
      setDark();
    }
  }

  void setDark() {
    themeMode.value = ThemeMode.dark;
    _box.write(_key, 'dark');
    Get.changeThemeMode(ThemeMode.dark);
  }

  void setLight() {
    themeMode.value = ThemeMode.light;
    _box.write(_key, 'light');
    Get.changeThemeMode(ThemeMode.light);
  }

  void setSystem() {
    themeMode.value = ThemeMode.system;
    _box.write(_key, 'system');
    Get.changeThemeMode(ThemeMode.system);
  }
}
