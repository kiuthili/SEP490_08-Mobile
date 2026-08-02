import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import 'package:stayhub_mobile/controllers/review_controller.dart';
import 'package:stayhub_mobile/controllers/staff_controller.dart';
import 'package:stayhub_mobile/screens/staff/staff_tickets_tab.dart';
import '../controllers/feature_controllers.dart';
import '../controllers/shell_controller.dart';
import '../controllers/tour_controller.dart';
import '../screens/customer/explore_tab.dart';
import '../screens/customer/home_tab.dart';
import '../screens/customer/orders_tab.dart';
import '../screens/customer/profile_tab.dart';
import '../screens/customer/social_tab.dart';
import '../screens/customer/social_map_screen.dart';
import '../screens/customer/ai_questionnaire_screen.dart';
import '../screens/staff/staff_checkin_tab.dart';
import '../screens/staff/staff_customers_tab.dart';
import '../screens/staff/staff_schedules_tab.dart';
import '../widgets/ios_bottom_nav.dart';
import '../widgets/page_scaffold.dart';
import '../utils/auth_gate.dart';
import '../services/tutorial_service.dart';

class MainShellScreen extends GetView<ShellController> {
  const MainShellScreen({super.key});

  static List<IosBottomNavItem> get _customerNav => [
        IosBottomNavItem(
          icon: Icons.map_outlined,
          selectedIcon: Icons.map_rounded,
          label: 'nav_map'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
          label: 'nav_social'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'nav_home'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome_rounded,
          label: 'nav_ai_guide'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'nav_profile'.tr,
        ),
      ];

  static List<IosBottomNavItem> get _guestNav => [
        IosBottomNavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'nav_home'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.travel_explore_outlined,
          selectedIcon: Icons.travel_explore_rounded,
          label: 'nav_explore'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
          label: 'nav_social'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          label: 'nav_book_tour'.tr,
        ),
        IosBottomNavItem(
          key: Get.isRegistered<TutorialService>() ? Get.find<TutorialService>().loginTabKey : null,
          icon: Icons.login_rounded,
          selectedIcon: Icons.login_rounded,
          label: 'nav_login'.tr,
        ),
      ];

  static List<IosBottomNavItem> get _staffNav => [
        IosBottomNavItem(
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
          label: 'nav_schedule'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.confirmation_number_outlined,
          selectedIcon: Icons.confirmation_number_rounded,
          label: 'nav_tickets'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.qr_code_scanner_outlined,
          selectedIcon: Icons.qr_code_scanner_rounded,
          label: 'nav_checkin'.tr,
          isProminent: true,
        ),
        IosBottomNavItem(
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          label: 'nav_guests'.tr,
        ),
        IosBottomNavItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'nav_profile'.tr,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isStaff = controller.isStaff;
      final isLoggedIn = AuthGate.isLoggedIn;
      final pages = isStaff
          ? const [
              StaffSchedulesTab(),
              StaffTicketsTab(),
              StaffCheckInTab(),
              StaffCustomersTab(),
              ProfileTab(),
            ]
          : isLoggedIn
              ? const [
                  SocialMapScreen(),
                  SocialTab(),
                  HomeTab(),
                  AiQuestionnaireScreen(),
                  ProfileTab(),
                ]
              : const [
                  HomeTab(),
                  ExploreTab(),
                  SizedBox.shrink(),
                  SizedBox.shrink(),
                  SizedBox.shrink(),
                ];
      final navItems = isStaff
          ? _staffNav
          : isLoggedIn
              ? _customerNav
              : _guestNav;
      final maxIndex = pages.length - 1;
      final index = controller.selectedIndex.value.clamp(0, maxIndex);

      return PageScaffold(
        extendBody: true,
        body: IndexedStack(
          index: index.clamp(0, pages.length - 1),
          children: pages,
        ),
        floatingActionButton:
            null, // Removed AiFloatingAssistant as it is now in navigation bar
        bottomNavigationBar: IosBottomNav(
          items: navItems,
          selectedIndex: index,
          onSelect: controller.changeTab,
        ),
      );
    });
  }
}

class MainShellBinding extends Bindings {
  MainShellBinding({this.initialTab});

  final int? initialTab;

  @override
  void dependencies() {
    final arguments = Get.arguments;
    final argumentTab =
        arguments is Map ? (arguments['initialTab'] as num?)?.toInt() : null;
    Get.lazyPut<ShellController>(
      () => ShellController(initialTab: initialTab ?? argumentTab),
    );
    Get.lazyPut<TourController>(() => TourController());
    Get.lazyPut<OrderController>(() => OrderController());
    Get.lazyPut<NotificationController>(() => NotificationController());
    Get.lazyPut<WishlistController>(() => WishlistController());
    Get.lazyPut<VoucherController>(() => VoucherController());
    Get.lazyPut<ReviewController>(() => ReviewController());
    Get.lazyPut<AiController>(() => AiController());
    Get.lazyPut<SocialController>(() => SocialController());
    Get.lazyPut<StaffController>(() => StaffController());
    Get.lazyPut<BookingController>(() => BookingController());

    if (AuthGate.isLoggedIn) {
      Get.find<SocialController>();
    }
  }
}
