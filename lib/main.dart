import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stayhub_mobile/firebase_options.dart';
import 'package:stayhub_mobile/services/notification_service.dart';
import 'package:stayhub_mobile/services/push_notification_service.dart';
import 'app.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/feature_services.dart';
import 'services/catalog_service.dart';
import 'services/order_service.dart';
import 'services/payment_service.dart';
import 'services/signalr_service.dart';
import 'services/social_service.dart';
import 'services/storage_service.dart';
import 'services/tour_service.dart';
import 'controllers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _StayHubHttpOverrides();
  GoogleFonts.config.allowRuntimeFetching = false;
  await GetStorage.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Chỉ khởi tạo push notification trên Android
  if (Platform.isAndroid) {
    await Get.putAsync(() => PushNotificationService().init());
  }

  Get.put(StorageService(), permanent: true);
  Get.put(ApiClient(), permanent: true);
  Get.put(AuthService(), permanent: true);
  Get.put(TourService(), permanent: true);
  Get.put(OrderService(), permanent: true);
  Get.put(PaymentService(), permanent: true);
  Get.put(CatalogService(), permanent: true);
  Get.put(NotificationService(), permanent: true);
  Get.put(VoucherService(), permanent: true);
  Get.put(ReviewService(), permanent: true);
  Get.put(WishlistService(), permanent: true);
  Get.put(AiService(), permanent: true);
  Get.put(SocialService(), permanent: true);
  Get.put(SignalRService(), permanent: true);
  Get.put(AuthController(), permanent: true);

  runApp(const StayHubApp());
}

class _StayHubHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, host, __) => _isLocalDevHost(host);
  }

  bool _isLocalDevHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' ||
        normalized == '::1' ||
        normalized == '10.0.2.2' ||
        normalized == '127.0.0.1') {
      return true;
    }
    if (normalized.startsWith('127.') ||
        normalized.startsWith('10.') ||
        normalized.startsWith('192.168.')) {
      return true;
    }
    final parts = normalized.split('.');
    if (parts.length != 4 || parts.first != '172') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }
}