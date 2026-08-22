import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/api_response.dart';

enum SnackType { success, error, info }

class SnackbarHelper {
  SnackbarHelper._();

  static void success(String message) {
    _show(message, SnackType.success);
  }

  static void error(String message) {
    if (message == ApiError.silent401Message ||
        message == ApiError.silentTimeoutMessage ||
        message.toLowerCase() == 'unauthorized' ||
        message.toLowerCase().contains('timeout')) {
      return;
    }
    _show(message, SnackType.error);
  }

  static void apiError(ApiError error) {
    if (error.isSilent || error.statusCode == 401) return;
    _show(error.message, SnackType.error);
  }

  static void info(String message) {
    _show(message, SnackType.info);
  }

  static void _show(String message, SnackType type) {
    Color accentColor;
    IconData iconData;
    String titleKey;

    switch (type) {
      case SnackType.success:
        accentColor = const Color(0xFF34C759); // iOS Green
        iconData = Icons.check_circle_rounded;
        titleKey = 'success';
        break;
      case SnackType.error:
        accentColor = const Color(0xFFFF3B30); // iOS Red
        iconData = Icons.error_rounded;
        titleKey = 'error';
        break;
      case SnackType.info:
        accentColor = const Color(0xFF007AFF); // iOS Blue
        iconData = Icons.info_rounded;
        titleKey = 'info';
        break;
    }

    final isDark = Get.isDarkMode;
    final bgColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.85)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.90);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subTextColor = isDark
        ? const Color(0xFFEBEBF5).withValues(alpha: 0.6)
        : const Color(0xFF3C3C43).withValues(alpha: 0.6);

    String titleText = titleKey.tr;
    if (titleText == titleKey) {
      titleText = type == SnackType.info ? 'Thông báo' : 'Message';
    }

    Get.snackbar(
      '',
      '',
      titleText: const SizedBox.shrink(),
      messageText: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.tr,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      snackPosition: SnackPosition.TOP,
      backgroundColor: bgColor,
      barBlur: 30, // Stronger blur for iOS style
      margin: const EdgeInsets.only(top: 8, left: 12, right: 12),
      borderRadius: 24, // iOS style banner radius
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      duration: const Duration(seconds: 4),
      isDismissible: true,
      dismissDirection: DismissDirection.up, // iOS typically dismisses upwards
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOutCirc,
      reverseAnimationCurve: Curves.easeInCirc,
    );
  }
}
