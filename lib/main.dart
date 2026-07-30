import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:stayhub_mobile/firebase_options.dart';
import 'package:stayhub_mobile/services/notification_service.dart';
import 'package:stayhub_mobile/services/push_notification_service.dart';
import 'package:stayhub_mobile/services/review_service.dart';
import 'package:stayhub_mobile/services/staff_service.dart';
import 'app.dart';
import 'controllers/feature_controllers.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/feature_services.dart';
import 'services/catalog_service.dart';
import 'services/order_service.dart';
import 'services/payment_service.dart';
import 'services/payment_deep_link_service.dart';
import 'services/signalr_service.dart';
import 'services/social_service.dart';
import 'services/storage_service.dart';
import 'services/tour_service.dart';
import 'services/ai_trend_service.dart';
import 'services/user_study_service.dart';
import 'services/system_setting_service.dart';
import 'constants/api_constants.dart';
import 'controllers/auth_controller.dart';
import 'controllers/home_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _StayHubHttpOverrides();
  GoogleFonts.config.allowRuntimeFetching = true;

  // Configure Mapbox access token before running app
  MapboxOptions.setAccessToken(ApiConstants.mapboxAccessToken);

  await GetStorage.init();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed/skipped: $e');
  }

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
  final paymentDeepLinks = Get.put(PaymentDeepLinkService(), permanent: true);
  Get.put(CatalogService(), permanent: true);
  Get.put(NotificationService(), permanent: true);
  Get.put(VoucherService(), permanent: true);
  Get.put(ReviewService(), permanent: true);
  Get.put(WishlistService(), permanent: true);
  Get.put(AiService(), permanent: true);
  Get.put(UserStudyService(), permanent: true);
  Get.put(SystemSettingService(), permanent: true);
  Get.put(SocialService(), permanent: true);
  Get.put(SignalRService(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(HomeController(), permanent: true);
  Get.put(AiController(), permanent: true);
  Get.put(AiTrendService(), permanent: true);
  Get.put(StaffScheduleService(), permanent: true);
  Get.lazyPut<SocialService>(() => SocialService());
  Get.lazyPut<SocialController>(() => SocialController());

  runApp(const StayHubApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    paymentDeepLinks.start();
  });
}

class _StayHubHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}
