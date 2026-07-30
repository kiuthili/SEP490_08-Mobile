import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/home_controller.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/auth_gate.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/tour_card.dart';
import '../../widgets/language_bottom_sheet.dart';

// ─────────────────────────────────────────────────────────────
// Home Tab root
// ─────────────────────────────────────────────────────────────
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final HomeController _home;
  final _wishlistController = Get.find<WishlistController>();
  final _notificationController = Get.find<NotificationController>();
  final _scrollController = ScrollController();


  // Language popup state
  String _selectedLang = 'vi';

  @override
  void initState() {
    super.initState();
    _selectedLang = Get.locale?.languageCode ?? 'vi';
    // Lazily put HomeController if not already registered
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController());
    }
    _home = Get.find<HomeController>();


    _scrollController.addListener(() {
      // no-op, reserved for future use
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openTour(int id) => Get.toNamed(AppRoutes.tourDetail, arguments: id);

  void _showLanguagePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LanguageBottomSheet(
        selected: _selectedLang,
        onSelect: (lang) {
          setState(() => _selectedLang = lang);
          if (lang == 'vi') {
            Get.updateLocale(const Locale('vi', 'VN'));
          } else {
            Get.updateLocale(const Locale('en', 'US'));
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Scrollable content ──
          RefreshIndicator(
            onRefresh: _home.refresh,
            color: AppColors.brand,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Space below fixed header — no extra gap so hero connects seamlessly
                SliverToBoxAdapter(
                  child: SizedBox(height: topPadding + _kHeaderHeight),
                ),

                // ── Hero section ──
                SliverToBoxAdapter(
                  child: _HeroSection(
                      onSearchTap: () => Get.toNamed(AppRoutes.tourSearch)),
                ),


                // ── Tour Hot section ──
                SliverToBoxAdapter(
                  child: Obx(() => _HomeSectionRow(
                        title: 'hot_tours'.tr,
                        onViewAll: () => Get.toNamed(
                          AppRoutes.sectionTours,
                          arguments: {'title': 'hot_tours'.tr, 'type': 'hot'},
                        ),
                        isLoading: _home.isLoadingHot.value,
                        tours: _home.hotTours,
                        badgeLabel: 'hot_badge'.tr,
                        badgeColor: AppColors.accent,
                        onTap: _openTour,
                        wishlistController: _wishlistController,
                      )),
                ),

                // ── Tour Sale section ──
                SliverToBoxAdapter(
                  child: Obx(() => _HomeSectionRow(
                        title: 'last_minute_deals'.tr,
                        onViewAll: () => Get.toNamed(
                          AppRoutes.sectionTours,
                          arguments: {
                            'title': 'last_minute_deals'.tr,
                            'type': 'sale'
                          },
                        ),
                        isLoading: _home.isLoadingSale.value,
                        tours: _home.saleTours,
                        badgeLabel: 'last_minute_badge'.tr,
                        badgeColor: const Color(0xFFE53935),
                        showSalePrice: true,
                        onTap: _openTour,
                        wishlistController: _wishlistController,
                      )),
                ),

                // ── Tour Upcoming section ──
                SliverToBoxAdapter(
                  child: Obx(() => _HomeSectionRow(
                        title: 'upcoming_tours'.tr,
                        onViewAll: () => Get.toNamed(
                          AppRoutes.sectionTours,
                          arguments: {
                            'title': 'upcoming_tours'.tr,
                            'type': 'upcoming'
                          },
                        ),
                        isLoading: _home.isLoadingUpcoming.value,
                        tours: _home.upcomingTours,
                        badgeLabel: 'upcoming_badge'.tr,
                        badgeColor: const Color(0xFF43A047),
                        onTap: _openTour,
                        wishlistController: _wishlistController,
                      )),
                ),

                // ── Region section ──
                SliverToBoxAdapter(
                    child: _RegionSection(home: _home, onTap: _openTour)),

                SliverToBoxAdapter(
                  child: const SizedBox(height: 20),
                ),
              ],
            ),
          ),

          // ── Fixed sticky header ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _StickyHeader(
              topPadding: topPadding,
              selectedLang: _selectedLang,
              onSearchTap: () => Get.toNamed(AppRoutes.tourSearch),
              onNotificationTap: () {
                if (AuthGate.requireLogin(route: AppRoutes.notifications)) {
                  Get.toNamed(AppRoutes.notifications);
                }
              },
              onLanguageTap: _showLanguagePopup,
              notificationController: _notificationController,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────
const double _kHeaderHeight = 56.0;

// ─────────────────────────────────────────────────────────────
// Sticky Header
// ─────────────────────────────────────────────────────────────
class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.topPadding,
    required this.selectedLang,
    required this.onSearchTap,
    required this.onNotificationTap,
    required this.onLanguageTap,
    required this.notificationController,
  });

  final double topPadding;
  final String selectedLang;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onLanguageTap;
  final NotificationController notificationController;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: AppColors.brand.withValues(alpha: 0.94),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: _kHeaderHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Language / Logo button
                    GestureDetector(
                      onTap: onLanguageTap,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Center(
                          child: Text(
                            selectedLang == 'vi' ? '🇻🇳' : '🇺🇸',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Search bar
                    Expanded(
                      child: GestureDetector(
                        onTap: onSearchTap,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: AppColors.brand.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'search_hint'.tr,
                                  style: AppTextStyles.textTheme.bodyMedium
                                      ?.copyWith(color: AppColors.textTertiary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Notification bell
                    Obx(() {
                      final unread = notificationController.unreadCount;
                      return Badge(
                        label: Text(unread > 99 ? '99+' : unread.toString()),
                        isLabelVisible: unread > 0,
                        backgroundColor: const Color(0xFFE53935),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        largeSize: 16,
                        child: GestureDetector(
                          onTap: onNotificationTap,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Home Section Row  (title + horizontal ListView of TourCards)
// ─────────────────────────────────────────────────────────────
class _HomeSectionRow extends StatelessWidget {
  const _HomeSectionRow({
    required this.title,
    required this.isLoading,
    required this.tours,
    required this.onViewAll,
    required this.onTap,
    required this.wishlistController,
    this.badgeLabel,
    this.badgeColor,
    this.showSalePrice = false,
  });

  final String title;
  final bool isLoading;
  final List<TourModel> tours;
  final VoidCallback onViewAll;
  final void Function(int id) onTap;
  final WishlistController wishlistController;
  final String? badgeLabel;
  final Color? badgeColor;
  final bool showSalePrice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                    fontSize: 17,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: Row(
                  children: [
                    Text(
                      'view_all'.tr,
                      style: AppTextStyles.textTheme.bodySmall?.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content
        if (isLoading)
          const SizedBox(
            height: 230,
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.brand),
            ),
          )
        else if (tours.isEmpty)
          SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'no_tours_yet'.tr,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          SizedBox(
            height: 285,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tours.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final tour = tours[index];
                final inWishlist = wishlistController.containsTour(tour.id);
                return _TourCard(
                  tour: tour,
                  badgeLabel: badgeLabel,
                  badgeColor: badgeColor,
                  showSalePrice: showSalePrice,
                  onTap: () => onTap(tour.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tour Card  (Viettravel style)
// ─────────────────────────────────────────────────────────────
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.tour,
    required this.onTap,
    this.badgeLabel,
    this.badgeColor,
    this.showSalePrice = false,
  });

  final TourModel tour;
  final VoidCallback onTap;
  final String? badgeLabel;
  final Color? badgeColor;
  final bool showSalePrice;

  @override
  Widget build(BuildContext context) {
    final hasDeparture = tour.nextDeparture != null;
    final depStr = hasDeparture
        ? DateFormat('dd/MM/yyyy').format(tour.nextDeparture!)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.card,
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: SizedBox(
                    height: 138,
                    width: double.infinity,
                    child: tour.imageUrl != null && tour.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: tour.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: AppColors.brandLight),
                          )
                        : const ColoredBox(color: AppColors.brandLight),
                  ),
                ),
                // Badge label top-left
                if (badgeLabel != null && badgeColor != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        badgeLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: WishlistButton(tourId: tour.id),
                ),
              ],
            ),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      tour.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Location
                    if (tour.city != null || tour.country != null)
                      Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 12, color: AppColors.brand),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              tour.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.brand,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),

                    // Departure date
                    if (depStr != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 11, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              'departure_date'.trParams({'date': depStr}),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Price row
                    if (tour.startingPrice != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gạch giá gốc nếu có khuyến mãi
                          if (tour.originalPrice != null)
                            Text(
                              CurrencyFormatter.format(tour.originalPrice!),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.textSecondary,
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'from_price'.tr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(tour.startingPrice!),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Text(
                        'contact_for_price'.tr,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Region Section  (tabs + horizontal tour list)
// ─────────────────────────────────────────────────────────────
class _RegionSection extends StatelessWidget {
  const _RegionSection({required this.home, required this.onTap});
  final HomeController home;
  final void Function(int id) onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = home.selectedRegionIndex.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 12, 12),
            child: Text(
              'favorite_destinations'.tr,
              style: AppTextStyles.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
                fontSize: 17,
              ),
            ),
          ),

          // Tabs
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: HomeController.regions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = selected == index;
                return GestureDetector(
                  onTap: () => home.selectRegion(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.brand : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: isSelected ? AppColors.brand : AppColors.border,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.brand.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      HomeController.regions[index].$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Tour cards
          if (home.isLoadingRegion.value)
            const SizedBox(
              height: 170,
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.brand),
              ),
            )
          else if (home.regionTours.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('no_tours_yet'.tr,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 285,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: home.regionTours.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final tour = home.regionTours[index];
                  final wishlist = Get.find<WishlistController>();
                  final inWishlist = wishlist.containsTour(tour.id);
                  return _TourCard(
                    tour: tour,
                    badgeLabel: null,
                    badgeColor: null,
                    onTap: () => onTap(tour.id),
                  );
                },
              ),
            ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Banner Carousel
// ─────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────
// Hero Section
// ─────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onSearchTap});
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient background — starts from same brand blue as sticky header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.brand, Color(0xFF003A8C), Color(0xFF05073C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            right: 60,
            top: 30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Eyebrow tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEB662B),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'app_exclusive'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Headline
                Text(
                  'discover_vn'.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'thousands_tours'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),

                // CTA button
                GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.explore_outlined,
                            size: 16, color: AppColors.brand),
                        const SizedBox(width: 6),
                        Text(
                          'explore_now'.tr,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// Language bottom sheet
// ─────────────────────────────────────────────────────────────
