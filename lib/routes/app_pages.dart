import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import '../controllers/feature_controllers.dart';
import '../controllers/tour_controller.dart';
import '../screens/auth/profile_auth_screens.dart';
import '../screens/customer/ai_questionnaire_screen.dart';
import '../screens/customer/ai_recommendations_screen.dart';
import '../screens/customer/public_tracking_screen.dart';
import '../screens/legal/privacy_screen.dart';
import '../screens/legal/terms_screen.dart';
import '../screens/customer/booking_screen.dart';
import '../screens/customer/bank_payment_demo_screen.dart';
import '../screens/customer/chat_inbox_screen.dart';
import '../screens/customer/my_reviews_screen.dart';
import '../screens/customer/request_cancellation_screen.dart';
import '../screens/customer/notifications_screen.dart';
import '../screens/customer/my_tickets_screen.dart';
import '../screens/customer/order_detail_screen.dart';
import '../screens/customer/payment_screen.dart';
import '../screens/customer/share_moment_screen.dart';
import '../screens/customer/social_detail_screens.dart';
import '../screens/customer/social_map_screen.dart';
import '../screens/customer/vouchers_screen.dart';
import '../screens/customer/wishlist_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell_screen.dart';
import '../screens/register_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/staff/qr_scan_screen.dart';
import '../screens/tour_detail_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final routes = [
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(name: AppRoutes.register, page: () => const RegisterScreen()),
    GetPage(
      name: AppRoutes.home,
      page: () => const MainShellScreen(),
      binding: MainShellBinding(),
    ),
    GetPage(
      name: AppRoutes.tourDetail,
      page: () => const TourDetailScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<TourController>()) {
          Get.lazyPut<TourController>(() => TourController());
        }
        if (!Get.isRegistered<ReviewController>()) {
          Get.lazyPut<ReviewController>(() => ReviewController());
        }
        if (!Get.isRegistered<WishlistController>()) {
          Get.lazyPut<WishlistController>(() => WishlistController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.booking,
      page: () => const BookingScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<BookingController>()) {
          Get.lazyPut<BookingController>(() => BookingController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.orderDetail,
      page: () => const OrderDetailScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<OrderController>()) {
          Get.lazyPut<OrderController>(() => OrderController());
        }
        if (!Get.isRegistered<ReviewController>()) {
          Get.lazyPut<ReviewController>(() => ReviewController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.notifications,
      page: () => const NotificationsScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<NotificationController>()) {
          Get.lazyPut<NotificationController>(() => NotificationController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.wishlist,
      page: () => const WishlistScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<WishlistController>()) {
          Get.lazyPut<WishlistController>(() => WishlistController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.vouchers,
      page: () => const VouchersScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<VoucherController>()) {
          Get.lazyPut<VoucherController>(() => VoucherController());
        }
      }),
    ),
    GetPage(name: AppRoutes.editProfile, page: () => const EditProfileScreen()),
    GetPage(
      name: AppRoutes.changePassword,
      page: () => const ChangePasswordScreen(),
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordScreen(),
    ),
    GetPage(
      name: AppRoutes.resetPassword,
      page: () => const ResetPasswordScreen(),
    ),
    GetPage(name: AppRoutes.socialMap, page: () => const SocialMapScreen()),
    GetPage(
      name: AppRoutes.shareMoment,
      page: () => const ShareMomentScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SocialController>()) {
          Get.lazyPut<SocialController>(() => SocialController());
        }
        if (!Get.isRegistered<OrderController>()) {
          Get.lazyPut<OrderController>(() => OrderController());
        }
      }),
    ),
    GetPage(name: AppRoutes.qrScan, page: () => const QrScanScreen()),
    GetPage(
      name: AppRoutes.chatInbox,
      page: () => const ChatInboxScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SocialController>()) {
          Get.lazyPut<SocialController>(() => SocialController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.chatRoom,
      page: () => const ChatRoomScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SocialController>()) {
          Get.lazyPut<SocialController>(() => SocialController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.momentDetail,
      page: () => const MomentDetailScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SocialController>()) {
          Get.lazyPut<SocialController>(() => SocialController());
        }
      }),
    ),
    GetPage(name: AppRoutes.userProfile, page: () => const UserProfileScreen()),
    GetPage(name: AppRoutes.payment, page: () => const PaymentScreen()),
    GetPage(
      name: AppRoutes.bankPaymentDemo,
      page: () => const BankPaymentDemoScreen(),
    ),
    GetPage(name: AppRoutes.myTickets, page: () => const MyTicketsScreen()),
    GetPage(
      name: AppRoutes.myReviews,
      page: () => const MyReviewsScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<ReviewController>()) {
          Get.lazyPut<ReviewController>(() => ReviewController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.requestCancellation,
      page: () => const RequestCancellationScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<OrderController>()) {
          Get.lazyPut<OrderController>(() => OrderController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.aiQuestionnaire,
      page: () => const AiQuestionnaireScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<AiController>()) {
          Get.lazyPut<AiController>(() => AiController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.aiRecommendations,
      page: () => const AiRecommendationsScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<AiController>()) {
          Get.lazyPut<AiController>(() => AiController());
        }
      }),
    ),
    GetPage(name: AppRoutes.terms, page: () => const TermsScreen()),
    GetPage(name: AppRoutes.privacy, page: () => const PrivacyScreen()),
    GetPage(
      name: AppRoutes.publicTrack,
      page: () => const PublicTrackingScreen(),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const MainShellScreen(),
      binding: MainShellBinding(initialTab: 4),
    ),
  ];
}
