import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/home_controller.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
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
      body: RefreshIndicator(
        onRefresh: _home.refresh,
        color: AppColors.brand,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: topPadding + 16),
            ),

            // ── Greeting & Search Header ──
            SliverToBoxAdapter(
              child: _GreetingHeader(
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

            // ── Promo Banner ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _PromoBanner(),
              ),
            ),

            // ── Region section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _RegionSection(home: _home, onTap: _openTour),
              ),
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
                    badgeColor: const Color(0xFFE53935),
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
                    badgeColor: const Color(0xFF34C759),
                    onTap: _openTour,
                    wishlistController: _wishlistController,
                  )),
            ),

            SliverToBoxAdapter(
              child: const SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Greeting Header (Large Title + Actions + Search)
// ─────────────────────────────────────────────────────────────
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.selectedLang,
    required this.onSearchTap,
    required this.onNotificationTap,
    required this.onLanguageTap,
    required this.notificationController,
  });

  final String selectedLang;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onLanguageTap;
  final NotificationController notificationController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title + Icons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/images/stayhub_icon_transparent.png',
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Actions
              Row(
                children: [
                  // Language toggle
                  GestureDetector(
                    onTap: onLanguageTap,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          selectedLang == 'vi' ? '🇻🇳' : '🇺🇸',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Notification Bell
                  Obx(() {
                    final unread = notificationController.unreadCount;
                    return Badge(
                      label: Text(unread > 99 ? '99+' : unread.toString()),
                      isLabelVisible: unread > 0,
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      largeSize: 16,
                      child: GestureDetector(
                        onTap: onNotificationTap,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Global Search Bar
          GestureDetector(
            onTap: onSearchTap,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'search_hint'.tr,
                      style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Promo Banner (iOS Inset Style)
// ─────────────────────────────────────────────────────────────
class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: const DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&q=80&w=1000',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'promo_banner_badge'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'promo_banner_title'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Home Section Row (Ultra Clean)
// ─────────────────────────────────────────────────────────────
class _HomeSectionRow extends StatefulWidget {
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
  State<_HomeSectionRow> createState() => _HomeSectionRowState();
}

class _HomeSectionRowState extends State<_HomeSectionRow> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onViewAll,
                child: Text(
                  'view_all'.tr,
                  style: TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        if (widget.isLoading)
          const SizedBox(
            height: 310,
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.brand),
            ),
          )
        else if (widget.tours.isEmpty)
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
            height: 310,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.tours.length,
              itemBuilder: (context, index) {
                final tour = widget.tours[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_pageController.position.haveDimensions) {
                      value = _pageController.page! - index;
                      value = (1 - (value.abs() * 0.08)).clamp(0.9, 1.0);
                    } else {
                      value = index == 0 ? 1.0 : 0.9;
                    }
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _TourCard(
                      tour: tour,
                      badgeLabel: widget.badgeLabel,
                      badgeColor: widget.badgeColor,
                      showSalePrice: widget.showSalePrice,
                      onTap: () => widget.onTap(tour.id),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tour Card (Ultra Clean - No Shadow)
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
        width: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(23)),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: tour.imageUrl != null && tour.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: tour.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: AppColors.backgroundSecondary),
                          )
                        : const ColoredBox(color: AppColors.backgroundSecondary),
                  ),
                ),
                // Badge label top-left
                if (badgeLabel != null && badgeColor != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: WishlistButton(tourId: tour.id),
                ),
              ],
            ),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      tour.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Location
                    if (tour.city != null || tour.country != null)
                      Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 14, color: AppColors.brand),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              tour.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
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
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 6),
                            Text(
                              'departure_date'.trParams({'date': depStr}),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
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
                                fontSize: 12,
                                color: AppColors.textTertiary,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.textTertiary,
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'from_price'.tr,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                CurrencyFormatter.format(tour.startingPrice!),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
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
                          fontSize: 13,
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
// Region Section (Ultra Clean)
// ─────────────────────────────────────────────────────────────
class _RegionSection extends StatefulWidget {
  const _RegionSection({required this.home, required this.onTap});
  final HomeController home;
  final void Function(int id) onTap;

  @override
  State<_RegionSection> createState() => _RegionSectionState();
}

class _RegionSectionState extends State<_RegionSection> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = widget.home.selectedRegionIndex.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              'favorite_destinations'.tr,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Tabs (Chips)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: HomeController.regions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = selected == index;
                return GestureDetector(
                  onTap: () => widget.home.selectRegion(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.brand : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.brand : Colors.black.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        HomeController.regions[index].$1,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Tour cards
          if (widget.home.isLoadingRegion.value)
            const SizedBox(
              height: 310,
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.brand),
              ),
            )
          else if (widget.home.regionTours.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('no_tours_yet'.tr,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 310,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.home.regionTours.length,
                itemBuilder: (context, index) {
                  final tour = widget.home.regionTours[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = _pageController.page! - index;
                        value = (1 - (value.abs() * 0.08)).clamp(0.9, 1.0);
                      } else {
                        value = index == 0 ? 1.0 : 0.9;
                      }
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: _TourCard(
                        tour: tour,
                        badgeLabel: null,
                        badgeColor: null,
                        onTap: () => widget.onTap(tour.id),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    });
  }
}
