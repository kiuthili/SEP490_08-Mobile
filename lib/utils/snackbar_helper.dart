import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_colors.dart';

class SnackbarHelper {
  SnackbarHelper._();

  static void success(String message) {
    _show(message, AppColors.primary);
  }

  static void error(String message) {
    _show(message, AppColors.error);
  }

  static void info(String message) {
    _show(message, AppColors.secondary);
  }

  static void _show(String message, Color color) {
    Get.snackbar(
      '',
      message,
      titleText: const SizedBox.shrink(),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }
}
