import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import 'package:stayhub_mobile/controllers/review_controller.dart';
import '../controllers/feature_controllers.dart';
import '../controllers/tour_controller.dart';
import '../screens/auth/profile_auth_screens.dart';
import '../screens/customer/ai_questionnaire_screen.dart';
import '../screens/customer/ai_recommendations_screen.dart';
import '../screens/customer/public_tracking_screen.dart';
import '../screens/legal/booking_terms_screen.dart';
import '../screens/legal/privacy_screen.dart';
import '../screens/legal/terms_screen.dart';
import '../screens/customer/booking_screen.dart';
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
import '../controllers/user_study_controller.dart';
import '../screens/customer/user_study_screen.dart';
import 'app_routes.dart';
import '../utils/auth_gate.dart';

class AppPages {
  AppPages._();

  static List<GetMiddleware> get _protected => [AuthMiddleware()];

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
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<BookingController>()) {
          Get.lazyPut<BookingController>(() => BookingController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.orderDetail,
      page: () => const OrderDetailScreen(),
      middlewares: _protected,
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
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<NotificationController>()) {
          Get.lazyPut<NotificationController>(() => NotificationController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.wishlist,
      page: () => const WishlistScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<WishlistController>()) {
          Get.lazyPut<WishlistController>(() => WishlistController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.vouchers,
      page: () => const VouchersScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<VoucherController>()) {
          Get.lazyPut<VoucherController>(() => VoucherController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.editProfile,
      page: () => const EditProfileScreen(),
      middlewares: _protected,
    ),
    GetPage(
      name: AppRoutes.changePassword,
      page: () => const ChangePasswordScreen(),
      middlewares: _protected,
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordScreen(),
    ),
    GetPage(
      name: AppRoutes.resetPassword,
      page: () => const ResetPasswordScreen(),
    ),
    GetPage(
      name: AppRoutes.socialMap,
      page: () => const SocialMapScreen(),
      middlewares: _protected,
    ),
    GetPage(
      name: AppRoutes.shareMoment,
      page: () => const ShareMomentScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SocialController>()) {
          Get.lazyPut<SocialController>(() => SocialController());
        }
        if (!Get.isRegistered<OrderController>()) {
          Get.lazyPut<OrderController>(() => OrderController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.qrScan,
      page: () => const QrScanScreen(),
      middlewares: _protected,
    ),
    GetPage(
      name: AppRoutes.chatInbox,
      page: () => const ChatInboxScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SocialController>()) {
          Get.lazyPut<SocialController>(() => SocialController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.chatRoom,
      page: () => const ChatRoomScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SocialController>()) {
          Get.lazyPut<SocialController>(() => SocialController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.momentDetail,
      page: () => const MomentDetailScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SocialController>()) {
          Get.lazyPut<SocialController>(() => SocialController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.userProfile,
      page: () => const UserProfileScreen(),
      middlewares: _protected,
    ),
    GetPage(
      name: AppRoutes.payment,
      page: () => const PaymentScreen(),
      middlewares: _protected,
    ),
    GetPage(
      name: AppRoutes.myTickets,
      page: () => const MyTicketsScreen(),
      middlewares: _protected,
    ),
    GetPage(
      name: AppRoutes.myReviews,
      page: () => const MyReviewsScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<ReviewController>()) {
          Get.lazyPut<ReviewController>(() => ReviewController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.requestCancellation,
      page: () => const RequestCancellationScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<OrderController>()) {
          Get.lazyPut<OrderController>(() => OrderController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.aiQuestionnaire,
      page: () => const AiQuestionnaireScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<AiController>()) {
          Get.lazyPut<AiController>(() => AiController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.aiRecommendations,
      page: () => const AiRecommendationsScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<AiController>()) {
          Get.lazyPut<AiController>(() => AiController());
        }
      }),
    ),
    GetPage(name: AppRoutes.terms, page: () => const TermsScreen()),
    GetPage(name: AppRoutes.privacy, page: () => const PrivacyScreen()),
    GetPage(
      name: AppRoutes.bookingTerms,
      page: () => const BookingTermsScreen(),
    ),
    GetPage(
      name: AppRoutes.publicTrack,
      page: () => const PublicTrackingScreen(),
    ),
    GetPage(
      name: AppRoutes.userStudy,
      page: () => const UserStudyScreen(),
      middlewares: _protected,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<UserStudyController>()) {
          Get.lazyPut<UserStudyController>(() => UserStudyController());
        }
      }),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const MainShellScreen(),
      binding: MainShellBinding(initialTab: 4),
      middlewares: _protected,
    ),
  ];
}
