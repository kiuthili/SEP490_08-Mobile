import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../services/storage_service.dart';
import 'snackbar_helper.dart';

class LoginDestination {
  const LoginDestination({this.route, this.arguments, this.shellTab});

  final String? route;
  final dynamic arguments;
  final int? shellTab;
}

class AuthGate {
  AuthGate._();

  /// Đã đăng nhập (bất kỳ role nào — customer, staff, manager...)
  static bool get isAuthenticated {
    if (!Get.isRegistered<StorageService>()) return false;
    final storage = Get.find<StorageService>();
    return storage.isLoggedIn;
  }

  /// Chỉ true với tài khoản customer — dùng để ẩn/hiện UI dành riêng cho customer
  static bool get isLoggedIn {
    if (!Get.isRegistered<StorageService>()) return false;
    final storage = Get.find<StorageService>();
    return storage.isLoggedIn && storage.user?.isCustomerOnly == true;
  }

  static bool requireLogin({
    String? route,
    dynamic arguments,
    int? shellTab,
    String? message,
  }) {
    if (isAuthenticated) return true;
    SnackbarHelper.info(message ?? 'login_required'.tr);
    Get.toNamed(
      AppRoutes.login,
      arguments: LoginDestination(
        route: route,
        arguments: arguments,
        shellTab: shellTab,
      ),
    );
    return false;
  }

  static void completeLogin([LoginDestination? destination]) {
    if (destination?.route != null) {
      Get.offAllNamed(destination!.route!, arguments: destination.arguments);
      return;
    }

    final storage = Get.find<StorageService>();
    final isStaff = storage.user?.isStaff ?? false;
    
    // Default home tab: Schedule (0) for Staff, Home (2) for Customer
    int targetTab = isStaff ? 0 : 2; 

    final guestTab = destination?.shellTab;
    if (guestTab != null && !isStaff) {
      if (guestTab == 2) {
        // Guest clicked Social -> map to Customer Social (1)
        targetTab = 1;
      }
      // For Login (guest tab 4) or other guest tabs, default to Home (2)
    }

    Get.offAllNamed(
      AppRoutes.home,
      arguments: {'initialTab': targetTab},
    );
  }
}

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (AuthGate.isAuthenticated) return null;
    return RouteSettings(
      name: AppRoutes.login,
      arguments: LoginDestination(
        route: route,
        arguments: Get.arguments,
      ),
    );
  }
}
