import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/feature_controllers.dart';
import '../controllers/shell_controller.dart';
import '../controllers/tour_controller.dart';
import '../screens/customer/explore_tab.dart';
import '../screens/customer/home_tab.dart';
import '../screens/customer/orders_tab.dart';
import '../screens/customer/profile_tab.dart';
import '../screens/customer/social_tab.dart';
import '../screens/staff/staff_checkin_tab.dart';
import '../screens/staff/staff_customers_tab.dart';
import '../screens/staff/staff_schedules_tab.dart';
import '../widgets/ios_bottom_nav.dart';
import '../widgets/page_scaffold.dart';

class MainShellScreen extends GetView<ShellController> {
  const MainShellScreen({super.key});

  static const _customerNav = [
    IosBottomNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Trang chủ',
    ),
    IosBottomNavItem(
      icon: Icons.travel_explore_outlined,
      selectedIcon: Icons.travel_explore_rounded,
      label: 'Khám phá',
    ),
    IosBottomNavItem(
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      label: 'Xã hội',
    ),
    IosBottomNavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Đặt tour',
    ),
    IosBottomNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Hồ sơ',
    ),
  ];

  static const _staffNav = [
    IosBottomNavItem(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      label: 'Lịch',
    ),
    IosBottomNavItem(
      icon: Icons.qr_code_scanner_outlined,
      selectedIcon: Icons.qr_code_scanner_rounded,
      label: 'Check-in',
    ),
    IosBottomNavItem(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: 'Khách',
    ),
    IosBottomNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Hồ sơ',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isStaff = controller.isStaff;
      final pages = isStaff
          ? const [
              StaffSchedulesTab(),
              StaffCheckInTab(),
              StaffCustomersTab(),
              ProfileTab(),
            ]
          : const [
              HomeTab(),
              ExploreTab(),
              SocialTab(),
              OrdersTab(),
              ProfileTab(),
            ];
      final navItems = isStaff ? _staffNav : _customerNav;
      final maxIndex = pages.length - 1;
      final index = controller.selectedIndex.value.clamp(0, maxIndex);

      return PageScaffold(
        extendBody: false,
        body: IndexedStack(
          index: index.clamp(0, pages.length - 1),
          children: pages,
        ),
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
    Get.lazyPut<ShellController>(
      () => ShellController(initialTab: initialTab),
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
  }
}
