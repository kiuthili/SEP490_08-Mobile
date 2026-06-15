import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/shell_controller.dart';
import '../../controllers/tour_controller.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../services/catalog_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/shell_layout.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/tour_card.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _TripType {
  const _TripType(this.label, this.searchTerm, this.icon, this.color);
  final String label;
  final String searchTerm;
  final IconData icon;
  final Color color;
}

class _HomeTabState extends State<HomeTab> {
  final _controller = Get.find<TourController>();
  final _wishlistController = Get.find<WishlistController>();
  final _notificationController = Get.put(NotificationController());
  final _scrollController = ScrollController();
  List<BannerModel> _banners = [];
  bool _showScrollToTop = false;

  static const _tripTypes = [
    _TripType(
      'Biển đảo',
      'Beach',
      Icons.beach_access_rounded,
      Color(0xFF0EA5E9),
    ),
    _TripType(
      'Núi rừng',
      'Mountain',
      Icons.terrain_rounded,
      Color(0xFF16A34A),
    ),
    _TripType(
      'Văn hóa',
      'Culture',
      Icons.temple_buddhist_rounded,
      Color(0xFFEB662B),
    ),
    _TripType(
      'Trong ngày',
      'Day Tour',
      Icons.wb_sunny_rounded,
      Color(0xFFF59E0B),
    ),
    _TripType(
      'Ẩm thực',
      'Food',
      Icons.restaurant_rounded,
      Color(0xFFE11D48),
    ),
    _TripType(
      'Phiêu lưu',
      'Adventure',
      Icons.hiking_rounded,
      Color(0xFF7C3AED),
    ),
  ];

  @override
  void initState() {
    super.initState();
    Get.find<CatalogService>().getBanners().then((list) {
      if (mounted) setState(() => _banners = list);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final showScrollToTop = _scrollController.offset > 520;
    if (showScrollToTop != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = showScrollToTop);
    }
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 280 &&
        !_controller.isLoadingMore.value) {
      _controller.loadMore();
    }
  }

  Future<void> _scrollToTop() {
    return _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openExplore({String? searchTerm, bool openFilters = false}) =>
      Get.find<ShellController>().openExplore(
        searchTerm: searchTerm,
        openFilters: openFilters,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.pageGradient),
            child: RefreshIndicator(
              onRefresh: () => _controller.fetchTours(refresh: true),
              child: Obx(() {
                final tours = _controller.tours;
                final loadingFirst =
                    _controller.isLoading.value && tours.isEmpty;
                return CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildCategoryStrip()),
                    if (_banners.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _BannerCarousel(banners: _banners),
                        ),
                      ),
                    if (loadingFirst)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: LoadingWidget(message: 'Đang tải tour...'),
                      )
                    else if (tours.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateWidget(
                          title: 'Chưa có tour nào',
                          subtitle: 'Kéo xuống để tải lại',
                          onRetry: () => _controller.fetchTours(refresh: true),
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          title: 'Tour nổi bật',
                          subtitle: 'Những hành trình đang được yêu thích nhất',
                          actionLabel: 'Xem tất cả',
                          onAction: _openExplore,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _FeaturedRow(
                          tours: tours.take(6).toList(),
                          onTap: _openTour,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SectionHeader(
                          title: 'Hành trình dành cho bạn',
                          subtitle: 'Chọn một chuyến đi và bắt đầu khám phá',
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          ShellLayout.bottomInset(context),
                        ),
                        sliver: SliverList.separated(
                          itemCount: tours.length +
                              (_controller.isLoadingMore.value ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            if (index >= tours.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            final tour = tours[index];
                            final inWishlist = _wishlistController.containsTour(
                              tour.id,
                            );
                            return TourCard(
                              tour: tour,
                              isInWishlist: inWishlist,
                              wishlistBusy: _wishlistController.isProcessing(
                                tour.id,
                              ),
                              onWishlistTap: () =>
                                  _wishlistController.toggleWishlist(
                                tour.id,
                                isInWishlist: inWishlist,
                              ),
                              onTap: () => _openTour(tour.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ),
          ),
          ScrollToTopButton(
            visible: _showScrollToTop,
            onTap: _scrollToTop,
          ),
        ],
      ),
    );
  }

  void _openTour(int id) => Get.toNamed(AppRoutes.tourDetail, arguments: id);

  Widget _buildHeader() {
    final user = Get.find<StorageService>().user;
    final name = user?.fullName ?? 'Khách';
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      margin: EdgeInsets.fromLTRB(16, topInset + 10, 16, 4),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: AppColors.homeHeroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.26),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -44,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào,',
                          style: AppTextStyles.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (user != null) ...[
                    _CircleIconButton(
                      icon: Icons.forum_outlined,
                      onTap: () => Get.toNamed(AppRoutes.chatInbox),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Trong _buildHeader của HomeTab
                  Obx(() {
                    final unreadCount = _notificationController.unreadCount;
                    return Badge(
                      label: Text(unreadCount.toString()),
                      isLabelVisible: unreadCount > 0,
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      largeSize: 18,
                      child: _CircleIconButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: () => Get.toNamed(AppRoutes.notifications),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                      ),
                    );
                  }),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Get.find<ShellController>().changeTab(4),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        backgroundImage: user?.avatarUrl != null
                            ? CachedNetworkImageProvider(user!.avatarUrl!)
                            : null,
                        child: user?.avatarUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: AppColors.brand,
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Đi đâu cũng được,\nmiễn là thật đáng nhớ.',
                style: AppTextStyles.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Khám phá những chuyến đi được chọn lọc cho riêng bạn.',
                style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _openExplore,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: AppColors.brand,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  'Tìm tour, điểm đến...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openExplore(openFilters: true),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            gradient: AppColors.brandGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStrip() {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _tripTypes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final t = _tripTypes[index];
            return GestureDetector(
              onTap: () => _openExplore(searchTerm: t.searchTerm),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: t.color.withValues(alpha: 0.14)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            t.color.withValues(alpha: 0.2),
                            t.color.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(t.icon, color: t.color, size: 27),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.label,
                      maxLines: 1,
                      style: AppTextStyles.textTheme.labelMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.foregroundColor = AppColors.textPrimary,
    this.backgroundColor = AppColors.surface,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, color: foregroundColor, size: 22),
      ),
    );
  }
}

class _FeaturedRow extends StatelessWidget {
  const _FeaturedRow({required this.tours, required this.onTap});
  final List<TourModel> tours;
  final void Function(int id) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tours.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final tour = tours[index];
          return _FeaturedCard(tour: tour, onTap: () => onTap(tour.id));
        },
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.tour, required this.onTap});
  final TourModel tour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 278,
        child: ClipRRect(
          borderRadius: AppRadius.card,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (tour.imageUrl != null && tour.imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: tour.imageUrl!,
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
                    colors: [
                      Color(0x1A05073C),
                      Colors.transparent,
                      Color(0xF205073C),
                    ],
                    stops: [0, 0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Nổi bật',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (tour.averageStar != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFB800),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          tour.averageStar!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tour.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tour.locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tour.startingPrice != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          'Từ ${CurrencyFormatter.format(tour.startingPrice!)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          height: 172,
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
                            colors: [
                              Color(0x1105073C),
                              Color(0xCC05073C),
                            ],
                          ),
                        ),
                      ),
                      if (b.title != null)
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  b.title!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
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
      ],
    );
  }
}
