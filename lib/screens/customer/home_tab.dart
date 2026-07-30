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
import '../../theme/app_colors.dart';
import '../../utils/auth_gate.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/language_bottom_sheet.dart';
import '../../widgets/tour_card.dart';

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

  String _selectedLang = 'vi';

  @override
  void initState() {
    super.initState();
    _selectedLang = Get.locale?.languageCode ?? 'vi';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _home.refresh,
        color: AppColors.brand,
        displacement: topPadding + 60,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero Banner (collapsible) ──
            SliverToBoxAdapter(
              child: _HeroBanner(
                topPadding: topPadding,
                selectedLang: _selectedLang,
                onNotificationTap: () {
                  if (AuthGate.requireLogin(route: AppRoutes.notifications)) {
                    Get.toNamed(AppRoutes.notifications);
                  }
                },
                onLanguageTap: _showLanguagePopup,
                notificationController: _notificationController,
              ),
            ),

            // ── Search Bar (normal) ──
            SliverToBoxAdapter(
              child: _HomeSearchBar(
                onSearchTap: () => Get.toNamed(AppRoutes.tourSearch),
                isDark: isDark,
              ),
            ),

            // ── Promo Banner ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _PromoBanner(isDark: isDark),
              ),
            ),

            // ── Region section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: _RegionSection(
                    home: _home, onTap: _openTour, isDark: isDark),
              ),
            ),

            // ── Hot Tours ──
            SliverToBoxAdapter(
              child: Obx(() => _HomeSectionRow(
                    title: 'hot_tours'.tr,
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFF5722),
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
                    isDark: isDark,
                  )),
            ),

            // ── Last Minute Deals ──
            SliverToBoxAdapter(
              child: Obx(() => _HomeSectionRow(
                    title: 'last_minute_deals'.tr,
                    icon: Icons.flash_on_rounded,
                    iconColor: const Color(0xFFFFC107),
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
                    badgeColor: const Color(0xFFFF6D00),
                    showSalePrice: true,
                    onTap: _openTour,
                    wishlistController: _wishlistController,
                    isDark: isDark,
                  )),
            ),

            // ── Upcoming Tours ──
            SliverToBoxAdapter(
              child: Obx(() => _HomeSectionRow(
                    title: 'upcoming_tours'.tr,
                    icon: Icons.event_available_rounded,
                    iconColor: const Color(0xFF00BFA5),
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
                    isDark: isDark,
                  )),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hero Banner — full-width gradient + actions
// ─────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.topPadding,
    required this.selectedLang,
    required this.onNotificationTap,
    required this.onLanguageTap,
    required this.notificationController,
  });

  final double topPadding;
  final String selectedLang;
  final VoidCallback onNotificationTap;
  final VoidCallback onLanguageTap;
  final NotificationController notificationController;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [
                  Color(0xFF0A0E1A),
                  Color(0xFF0D1F3C),
                  Color(0xFF1A3A6E)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF05073C),
                  Color(0xFF003A9E),
                  Color(0xFF1A7AFF)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.55, 1.0],
              ),
      ),
      child: Stack(
        children: [
          // Background decorative circles
          Positioned(
            right: -40,
            top: -20,
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
            top: 60,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Logo + Actions
                Row(
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/stayhub_icon_transparent.png',
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    // Language toggle
                    _HeroIconBtn(
                      onTap: onLanguageTap,
                      child: Text(
                        selectedLang == 'vi' ? '🇻🇳' : '🇺🇸',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Notification
                    Obx(() {
                      final unread = notificationController.unreadCount;
                      return Badge(
                        label: Text(unread > 99 ? '99+' : unread.toString()),
                        isLabelVisible: unread > 0,
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        largeSize: 16,
                        child: _HeroIconBtn(
                          onTap: onNotificationTap,
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 24),

                // Heading
                Text(
                  'home_hero_title'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'home_hero_subtitle'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                // Stats row
                const Row(
                  children: [
                    _StatChip(icon: Icons.tour_rounded, label: '500+ tours'),
                    SizedBox(width: 10),
                    _StatChip(icon: Icons.place_rounded, label: '50+ cities'),
                    SizedBox(width: 10),
                    _StatChip(icon: Icons.star_rounded, label: '4.8★'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconBtn extends StatelessWidget {
  const _HeroIconBtn({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sticky Search Delegate
// ─────────────────────────────────────────────────────────────
class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({
    required this.onSearchTap,
    required this.isDark,
  });

  final VoidCallback onSearchTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onSearchTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark
                        ? const Color(0xFF636366)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'search_hint'.tr,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? const Color(0xFF636366)
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'search_filter'.tr,
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Promo Banner
// ─────────────────────────────────────────────────────────────
class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 150,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&q=80&w=1000',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.72),
                Colors.black.withValues(alpha: 0.10),
              ],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6D00), Color(0xFFFF3D00)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'promo_banner_badge'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'promo_banner_title'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.4,
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
// Section Header with accent icon
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onViewAll,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: onViewAll,
            child: Row(
              children: [
                Text(
                  'view_all'.tr,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.brand, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Home Section Row
// ─────────────────────────────────────────────────────────────
class _HomeSectionRow extends StatefulWidget {
  const _HomeSectionRow({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.isLoading,
    required this.tours,
    required this.onViewAll,
    required this.onTap,
    required this.wishlistController,
    required this.isDark,
    this.badgeLabel,
    this.badgeColor,
    this.showSalePrice = false,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final bool isLoading;
  final List<TourModel> tours;
  final VoidCallback onViewAll;
  final void Function(int id) onTap;
  final WishlistController wishlistController;
  final bool isDark;
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
    _pageController = PageController(viewportFraction: 0.88);
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
        _SectionHeader(
          title: widget.title,
          icon: widget.icon,
          iconColor: widget.iconColor,
          onViewAll: widget.onViewAll,
        ),
        if (widget.isLoading)
          SizedBox(
            height: 300,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.iconColor,
              ),
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
            height: 300,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.tours.length,
              itemBuilder: (context, index) {
                final tour = widget.tours[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double scale = 1.0;
                    if (_pageController.position.haveDimensions) {
                      final diff = _pageController.page! - index;
                      scale = (1 - (diff.abs() * 0.06)).clamp(0.92, 1.0);
                    } else {
                      scale = index == 0 ? 1.0 : 0.94;
                    }
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _TourCard(
                      tour: tour,
                      badgeLabel: widget.badgeLabel,
                      badgeColor: widget.badgeColor,
                      showSalePrice: widget.showSalePrice,
                      isDark: widget.isDark,
                      accentColor: widget.iconColor,
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
// Tour Card — Immersive Image + Info Panel
// ─────────────────────────────────────────────────────────────
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.tour,
    required this.onTap,
    required this.isDark,
    this.badgeLabel,
    this.badgeColor,
    this.accentColor = AppColors.brand,
    this.showSalePrice = false,
  });

  final TourModel tour;
  final VoidCallback onTap;
  final bool isDark;
  final String? badgeLabel;
  final Color? badgeColor;
  final Color accentColor;
  final bool showSalePrice;

  @override
  Widget build(BuildContext context) {
    final hasDeparture = tour.nextDeparture != null;
    final depStr = hasDeparture
        ? DateFormat('dd MMM yyyy').format(tour.nextDeparture!)
        : null;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final subtextColor =
        isDark ? const Color(0xFF8E8E93) : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.40)
                  : const Color(0xFF05073C).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image section ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  child: SizedBox(
                    height: 176,
                    width: double.infinity,
                    child: tour.imageUrl != null && tour.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: tour.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFE5E5EA),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: isDark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFE5E5EA),
                              child: const Icon(
                                  Icons.image_not_supported_rounded,
                                  color: Colors.white54),
                            ),
                          )
                        : Container(
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFE5E5EA),
                          ),
                  ),
                ),

                // Gradient overlay bottom of image
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                ),

                // Badge top-left
                if (badgeLabel != null && badgeColor != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          color: badgeColor!.withValues(alpha: 0.92),
                          child: Text(
                            badgeLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Wishlist button top-right
                Positioned(
                  top: 10,
                  right: 10,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.25),
                        child: WishlistButton(tourId: tour.id),
                      ),
                    ),
                  ),
                ),

                // Transport chip (if available)
                if (tour.transportationType != null)
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_bus_rounded,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            tour.transportationType!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ── Info panel ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tour name
                    Text(
                      tour.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Location
                    if (tour.city != null || tour.country != null)
                      Row(
                        children: [
                          Icon(Icons.place_rounded,
                              size: 13, color: accentColor),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              tour.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: subtextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                    const Spacer(),

                    // Bottom row: Date + Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Departure
                        if (depStr != null)
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month_rounded,
                                    size: 12, color: subtextColor),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    depStr,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: subtextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),

                        // Price
                        if (tour.startingPrice != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (tour.originalPrice != null)
                                Text(
                                  CurrencyFormatter.format(tour.originalPrice!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: subtextColor,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: subtextColor,
                                  ),
                                ),
                              Text(
                                CurrencyFormatter.format(tour.startingPrice!),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'contact_for_price'.tr,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtextColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
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
// Region Section
// ─────────────────────────────────────────────────────────────
class _RegionSection extends StatefulWidget {
  const _RegionSection({
    required this.home,
    required this.onTap,
    required this.isDark,
  });

  final HomeController home;
  final void Function(int id) onTap;
  final bool isDark;

  @override
  State<_RegionSection> createState() => _RegionSectionState();
}

class _RegionSectionState extends State<_RegionSection> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
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
          _SectionHeader(
            title: 'favorite_destinations'.tr,
            icon: Icons.explore_rounded,
            iconColor: AppColors.brand,
            onViewAll: () {},
          ),

          // Region tabs
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: HomeController.regions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = selected == index;
                return GestureDetector(
                  onTap: () => widget.home.selectRegion(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF1A7AFF), AppColors.brand],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected
                          ? null
                          : (widget.isDark
                              ? const Color(0xFF2C2C2E)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(19),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.brand.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      HomeController.regions[index].$1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Tour cards
          if (widget.home.isLoadingRegion.value)
            const SizedBox(
              height: 300,
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
              height: 300,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.home.regionTours.length,
                itemBuilder: (context, index) {
                  final tour = widget.home.regionTours[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double scale = 1.0;
                      if (_pageController.position.haveDimensions) {
                        final diff = _pageController.page! - index;
                        scale = (1 - (diff.abs() * 0.06)).clamp(0.92, 1.0);
                      } else {
                        scale = index == 0 ? 1.0 : 0.94;
                      }
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _TourCard(
                        tour: tour,
                        isDark: widget.isDark,
                        accentColor: AppColors.brand,
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
