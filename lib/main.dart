import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
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
  GoogleFonts.config.allowRuntimeFetching = false;
  await GetStorage.init();

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
