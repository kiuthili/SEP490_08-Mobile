import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/shell_controller.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/shell_layout.dart';
import '../../utils/auth_gate.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/scroll_to_top_button.dart';

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

  List<BannerModel> _banners = [];
  bool _showScrollToTop = false;

  // Language popup state
  String _selectedLang = 'vi';

  @override
  void initState() {
    super.initState();
    // Lazily put HomeController if not already registered
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController());
    }
    _home = Get.find<HomeController>();

    Get.find<CatalogService>().getBanners().then((list) {
      if (mounted) setState(() => _banners = list);
    });

    _scrollController.addListener(() {
      final show = _scrollController.offset > 400;
      if (show != _showScrollToTop && mounted) {
        setState(() => _showScrollToTop = show);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openTour(int id) => Get.toNamed(AppRoutes.tourDetail, arguments: id);

  void _openExplore({String? searchTerm}) =>
      Get.find<ShellController>().openExplore(searchTerm: searchTerm);

  void _showLanguagePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageBottomSheet(
        selected: _selectedLang,
        onSelect: (lang) {
          setState(() => _selectedLang = lang);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _scrollToTop() => _scrollController.animateTo(
    0,
    duration: const Duration(milliseconds: 550),
    curve: Curves.easeOutCubic,
  );

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
                // Space below fixed header
                SliverToBoxAdapter(
                  child: SizedBox(height: topPadding + _kHeaderHeight + 8),
                ),

                // Banner carousel
                if (_banners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _BannerCarousel(banners: _banners),
                  ),

                // ── Tour Hot section ──
                SliverToBoxAdapter(
                  child: Obx(() => _HomeSectionRow(
                    title: 'Tour nổi bật',
                    onViewAll: _openExplore,
                    isLoading: _home.isLoadingHot.value,
                    tours: _home.hotTours,
                    badgeLabel: 'Nổi bật',
                    badgeColor: AppColors.accent,
                    onTap: _openTour,
                    wishlistController: _wishlistController,
                  )),
                ),

                // ── Tour Sale section ──
                SliverToBoxAdapter(
                  child: Obx(() => _HomeSectionRow(
                    title: 'Ưu đãi giờ chót',
                    onViewAll: _openExplore,
                    isLoading: _home.isLoadingSale.value,
                    tours: _home.saleTours,
                    badgeLabel: 'Giờ chót',
                    badgeColor: const Color(0xFFE53935),
                    showSalePrice: true,
                    onTap: _openTour,
                    wishlistController: _wishlistController,
                  )),
                ),

                // ── Tour Upcoming section ──
                SliverToBoxAdapter(
                  child: Obx(() => _HomeSectionRow(
                    title: 'Sắp khởi hành',
                    onViewAll: _openExplore,
                    isLoading: _home.isLoadingUpcoming.value,
                    tours: _home.upcomingTours,
                    badgeLabel: 'Sắp đi',
                    badgeColor: const Color(0xFF43A047),
                    onTap: _openTour,
                    wishlistController: _wishlistController,
                  )),
                ),

                // ── Region section ──
                SliverToBoxAdapter(child: _RegionSection(home: _home, onTap: _openTour)),

                SliverToBoxAdapter(
                  child: SizedBox(height: ShellLayout.bottomInset(context) + 16),
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
              onSearchTap: _openExplore,
              onNotificationTap: () {
                if (AuthGate.requireLogin(route: AppRoutes.notifications)) {
                  Get.toNamed(AppRoutes.notifications);
                }
              },
              onLanguageTap: _showLanguagePopup,
              notificationController: _notificationController,
            ),
          ),

          // ── Scroll to top ──
          ScrollToTopButton(visible: _showScrollToTop, onTap: _scrollToTop),
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
                          borderRadius: BorderRadius.circular(10),
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
                                  'Tìm kiếm...',
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
                      'Xem tất cả',
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
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
            ),
          )
        else if (tours.isEmpty)
          const SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Chưa có tour nào',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          SizedBox(
            height: 260,
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
                  isInWishlist: inWishlist,
                  onTap: () => onTap(tour.id),
                  onWishlistTap: () => wishlistController.toggleWishlist(
                    tour.id,
                    isInWishlist: inWishlist,
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
// Tour Card  (Viettravel style)
// ─────────────────────────────────────────────────────────────
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.tour,
    required this.isInWishlist,
    required this.onTap,
    required this.onWishlistTap,
    this.badgeLabel,
    this.badgeColor,
    this.showSalePrice = false,
  });

  final TourModel tour;
  final bool isInWishlist;
  final VoidCallback onTap;
  final VoidCallback onWishlistTap;
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                // Wishlist button top-right
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onWishlistTap,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isInWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isInWishlist ? const Color(0xFFE53935) : AppColors.textSecondary,
                        size: 16,
                      ),
                    ),
                  ),
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
                          const Icon(Icons.place_rounded, size: 12, color: AppColors.brand),
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
                              'Khởi hành: $depStr',
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Từ ',
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
                      )
                    else
                      const Text(
                        'Liên hệ để biết giá',
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
              'Điểm đến yêu thích',
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
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                        color: isSelected ? Colors.white : AppColors.textSecondary,
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
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
              ),
            )
          else if (home.regionTours.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('Chưa có tour nào', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: home.regionTours.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final tour = home.regionTours[index];
                  return GestureDetector(
                    onTap: () => onTap(tour.id),
                    child: _RegionCard(tour: tour),
                  );
                },
              ),
            ),
        ],
      );
    });
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.tour});
  final TourModel tour;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (tour.imageUrl != null && tour.imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: tour.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                const ColoredBox(color: AppColors.brandLight),
              )
            else
              const ColoredBox(color: AppColors.brandLight),
            // Gradient overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x0005073C),
                    Color(0xDD05073C),
                  ],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            // City name
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: Text(
                tour.city ?? tour.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 1.2,
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
// Banner Carousel
// ─────────────────────────────────────────────────────────────
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});
  final List<BannerModel> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _pageController = PageController(viewportFraction: 0.9);
  int _current = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 166,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final b = widget.banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: AppRadius.card,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (b.imageUrl != null)
                        CachedNetworkImage(
                          imageUrl: b.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                          const ColoredBox(color: AppColors.brandLight),
                        )
                      else
                        const ColoredBox(color: AppColors.brandLight),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x0005073C), Color(0xAA05073C)],
                          ),
                        ),
                      ),
                      if (b.title != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 14,
                          child: Text(
                            b.title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.25,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.banners.length,
                (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _current ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _current ? AppColors.brand : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Language bottom sheet
// ─────────────────────────────────────────────────────────────
class _LanguageBottomSheet extends StatelessWidget {
  const _LanguageBottomSheet({required this.selected, required this.onSelect});
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final languages = [
      ('vi', '🇻🇳', 'Tiếng Việt'),
      ('en', '🇺🇸', 'English'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn ngôn ngữ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...languages.map((lang) => ListTile(
              leading: Text(lang.$2, style: const TextStyle(fontSize: 26)),
              title: Text(lang.$3,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: selected == lang.$1
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.brand)
                  : null,
              onTap: () => onSelect(lang.$1),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}