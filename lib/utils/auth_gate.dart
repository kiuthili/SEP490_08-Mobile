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
    String message = 'Vui lòng đăng nhập để sử dụng chức năng này',
  }) {
    if (isAuthenticated) return true;
    SnackbarHelper.info(message);
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

    final tab = destination?.shellTab;
    Get.offAllNamed(
      AppRoutes.home,
      arguments: tab == null ? null : {'initialTab': tab},
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