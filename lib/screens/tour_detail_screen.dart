import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/review_controller.dart';
import 'package:stayhub_mobile/models/review_model.dart';
import 'package:stayhub_mobile/models/reviewreply_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/feature_controllers.dart';
import '../controllers/tour_controller.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../services/catalog_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../utils/booking_args.dart';
import '../utils/route_args.dart';
import '../utils/snackbar_helper.dart';
import '../models/tour_model.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/loading_widget.dart';
import '../utils/auth_gate.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class TourDetailScreen extends StatefulWidget {
  const TourDetailScreen({super.key});

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  late final TourController _tourController;
  late final ReviewController _reviewController;
  late final WishlistController _wishlistController;
  final _workers = <Worker>[];
  int? _tourId;
  List<TourItineraryModel> _itineraries = [];
  Map<int, TourismInformationModel> _tourismInformation = {};
  Set<int> _expandedItineraryDays = {};
  bool _itineraryLoading = false;
  TourScheduleModel? _selectedSchedule;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _tourController = Get.find<TourController>();
    _reviewController = Get.find<ReviewController>();
    _wishlistController = Get.find<WishlistController>();
    _tourId = parseTourId(Get.arguments);

    void refresh() {
      if (mounted) setState(() {});
    }

    _workers.addAll([
      ever(_tourController.selectedTour, (_) => refresh()),
      ever(_tourController.detailLoading, (_) => refresh()),
      ever(_tourController.detailSchedules, (_) {
        _syncSelectedSchedule();
        refresh();
      }),
      ever(_reviewController.reviews, (_) => refresh()),
      ever(_reviewController.myReview, (_) => refresh()),
      ever(_wishlistController.items, (_) => refresh()),
      ever(_wishlistController.processingTourIds, (_) => refresh()),
    ]);

    if (_tourId != null) {
      _tourController.fetchTourDetail(_tourId!);
      _reviewController.fetchReviews(_tourId!);
      _wishlistController.fetchWishlist();
      _loadItineraries(_tourId!);
    }
  }

  Future<void> _loadItineraries(int tourId) async {
    setState(() => _itineraryLoading = true);
    final catalog = Get.find<CatalogService>();
    try {
      final itineraries = await catalog.getTourItineraries(tourId);
      final tourismIds = itineraries
          .map((item) => item.tourismInfoId)
          .whereType<int>()
          .toSet();
      final tourismEntries = await Future.wait(
        tourismIds.map((id) async {
          try {
            final info = await catalog.getTourismInformationById(id);
            return MapEntry(id, info);
          } catch (_) {
            return null;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _itineraries = itineraries;
        _tourismInformation = Map.fromEntries(
          tourismEntries.whereType<MapEntry<int, TourismInformationModel>>(),
        );
        _expandedItineraryDays =
            itineraries.map((item) => item.dayNumber ?? 1).toSet();
        _itineraryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _itineraryLoading = false);
    }
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.dispose();
  }

  bool _isInWishlist(int tourId) =>
      _wishlistController.items.any((i) => i.tourId == tourId);

  bool _scheduleAvailable(TourScheduleModel s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (s.departureDate.isBefore(today) || s.tickets.isEmpty) return false;
    return s.tickets.any(
      (t) => t.isActive != false && t.availableQuantity > 0,
    );
  }

  void _syncSelectedSchedule() {
    final current = _selectedSchedule;
    if (current != null &&
        _tourController.detailSchedules.any(
          (schedule) =>
              schedule.id == current.id && _scheduleAvailable(schedule),
        )) {
      return;
    }

    _selectedSchedule = null;
    for (final schedule in _tourController.detailSchedules) {
      if (_scheduleAvailable(schedule)) {
        _selectedSchedule = schedule;
        break;
      }
    }
  }

  int? _scheduleMinPrice(TourScheduleModel s) {
    if (s.tickets.isEmpty) return null;
    final prices = s.tickets
        .where((t) => t.isActive != false && t.availableQuantity > 0)
        .map((t) => t.effectivePrice);
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a < b ? a : b);
  }

  int? _scheduleOriginalMinPrice(TourScheduleModel s) {
    if (s.tickets.isEmpty) return null;
    final prices = s.tickets
        .where((t) => t.isActive != false && t.availableQuantity > 0)
        .map((t) => t.price);
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a < b ? a : b);
  }

  int _scheduleAvailableSeats(TourScheduleModel schedule) {
    return schedule.tickets
        .where((ticket) => ticket.isActive != false)
        .fold(0, (total, ticket) => total + ticket.availableQuantity);
  }

  void _selectSchedule(TourScheduleModel schedule) {
    if (!_scheduleAvailable(schedule)) return;
    setState(() => _selectedSchedule = schedule);
  }

  void _showSchedulePicker() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 1. Lọc các schedule ở tương lai
    final futureSchedules = _tourController.detailSchedules
        .where((s) => s.departureDate.isAfter(today) || s.departureDate.isAtSameMomentAs(today))
        .toList();
        
    futureSchedules.sort((a, b) => a.departureDate.compareTo(b.departureDate));

    // 2. Nhóm theo tháng
    final Map<String, List<TourScheduleModel>> schedulesByMonth = {};
    for (final s in futureSchedules) {
      final monthKey = 'Tháng ${s.departureDate.month} - ${s.departureDate.year}';
      if (!schedulesByMonth.containsKey(monthKey)) {
        schedulesByMonth[monthKey] = [];
      }
      schedulesByMonth[monthKey]!.add(s);
    }

    if (schedulesByMonth.isEmpty) {
      SnackbarHelper.info('Hiện chưa có lịch khởi hành mới');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SchedulePickerSheet(
          schedulesByMonth: schedulesByMonth,
          selectedSchedule: _selectedSchedule,
          onSelect: (schedule) {
            _selectSchedule(schedule);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _proceedToBooking(TourModel tour) {
    final schedule = _selectedSchedule;
    if (schedule == null) {
      SnackbarHelper.error('Vui lòng chọn lịch khởi hành');
      return;
    }
    final arguments = BookingRouteArgs.fromTourSchedule(
      tour: tour,
      schedule: schedule,
    );
    if (!AuthGate.requireLogin(
      route: AppRoutes.booking,
      arguments: arguments,
      message: 'Vui lòng đăng nhập trước khi đặt tour',
    )) {
      return;
    }
    Get.toNamed(AppRoutes.booking, arguments: arguments);
  }

  Widget? _buildCheckoutBar() {
    final tour = _tourController.selectedTour.value;
    if (tour == null) return null;
    final schedule = _selectedSchedule;
    final minPrice = schedule != null ? _scheduleMinPrice(schedule) : null;
    final originalPrice = schedule != null ? _scheduleOriginalMinPrice(schedule) : null;
    final hasSchedules = _tourController.detailSchedules.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Giá:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (originalPrice != null && originalPrice > (minPrice ?? 0))
                      Text(
                        CurrencyFormatter.format(originalPrice),
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    Row(
                      children: [
                        Text(
                          minPrice != null
                              ? CurrencyFormatter.format(minPrice)
                              : schedule != null
                                  ? 'Đang cập nhật'
                                  : 'Chưa thể đặt',
                          style: TextStyle(
                            color: minPrice != null ? AppColors.brand : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        if (minPrice != null)
                          const Text(
                            ' /khách',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.phone_in_talk_rounded, color: Colors.blue.shade700),
                    onPressed: () {
                      // TODO: Implement Consultation request
                      SnackbarHelper.info('Tính năng yêu cầu tư vấn đang phát triển');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: hasSchedules ? _showSchedulePicker : null,
                    child: Text(
                      'Ngày khác',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasSchedules ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: schedule != null && _scheduleAvailable(schedule)
                        ? () => _proceedToBooking(tour)
                        : null,
                    child: const Text(
                      'Đặt ngay',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Chi tiết tour',
      actions: [
        if (_tourController.selectedTour.value != null)
          Builder(
            builder: (context) {
              final tour = _tourController.selectedTour.value!;
              final inWishlist = _isInWishlist(tour.id);
              final busy = _wishlistController.isProcessing(tour.id);
              return IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: inWishlist
                      ? Colors.red.withValues(alpha: 0.1)
                      : AppColors.surfaceGrouped,
                ),
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        inWishlist
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: inWishlist ? AppColors.error : null,
                      ),
                onPressed: busy
                    ? null
                    : () => _wishlistController.toggleWishlist(
                          tour.id,
                          isInWishlist: inWishlist,
                        ),
              );
            },
          ),
      ],
      bottomBar: _buildCheckoutBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_tourId == null) {
      return const Center(child: Text('Không xác định được tour'));
    }
    if (_tourController.detailLoading.value &&
        _tourController.selectedTour.value == null) {
      return const LoadingWidget(message: 'Đang tải chi tiết tour...');
    }
    final tour = _tourController.selectedTour.value;
    if (tour == null || tour.id != _tourId) {
      return EmptyStateWidget(
        icon: Icons.error_outline_rounded,
        title: 'Không tải được chi tiết tour',
        subtitle: _tourController.detailError.value ??
            'Tour không tồn tại hoặc không còn hoạt động',
        onRetry: () => _tourController.fetchTourDetail(_tourId!),
      );
    }
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildHero(tour),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildQuickInfo(),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  labelColor: AppColors.brand,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.brand,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Tổng quan'),
                    Tab(text: 'Lịch trình'),
                    Tab(text: 'Lưu ý'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            // Tab 1: Tổng quan
            SingleChildScrollView(
              padding: const EdgeInsets.all(20).copyWith(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailSection(
                    icon: Icons.auto_stories_rounded,
                    title: 'Giới thiệu',
                    child: HtmlWidget(
                      tour.description ?? 'Chưa có mô tả',
                      textStyle: AppTextStyles.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailSection(
                    icon: Icons.verified_rounded,
                    title: 'Trải nghiệm nổi bật',
                    child: _buildHighlights(),
                  ),
                ],
              ),
            ),
            // Tab 2: Lịch trình
            SingleChildScrollView(
              padding: const EdgeInsets.all(20).copyWith(bottom: 120),
              child: _itineraryLoading || _itineraries.isNotEmpty
                  ? _DetailSection(
                      icon: Icons.route_rounded,
                      title: 'Lịch trình chi tiết',
                      subtitle: _itineraryLoading
                          ? 'Đang chuẩn bị hành trình của bạn'
                          : '${_itineraries.length} hoạt động trong hành trình',
                      trailing: _itineraries.isEmpty
                          ? null
                          : TextButton.icon(
                              onPressed: _toggleAllItineraryDays,
                              icon: Icon(
                                _allItineraryDaysExpanded
                                    ? Icons.unfold_less_rounded
                                    : Icons.unfold_more_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _allItineraryDaysExpanded
                                    ? 'Thu gọn'
                                    : 'Mở tất cả',
                              ),
                            ),
                      child: _itineraryLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _buildItineraryTimeline(),
                    )
                  : const Text('Chưa có thông tin lịch trình.'),
            ),
            // Tab 3: Lưu ý / Đánh giá
            SingleChildScrollView(
              padding: const EdgeInsets.all(20).copyWith(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailSection(
                    icon: Icons.info_outline_rounded,
                    title: 'Lưu ý chuyến đi',
                    child: HtmlWidget(
                      '<p>Vui lòng đến đúng giờ khởi hành.</p><ul><li>Đem theo giấy tờ tùy thân.</li><li>Theo sát hướng dẫn viên.</li></ul>',
                      textStyle: AppTextStyles.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailSection(
                    icon: Icons.star_rounded,
                    title: 'Đánh giá',
                    subtitle: _reviewController.reviews.isEmpty
                        ? 'Chưa có đánh giá'
                        : '${_reviewController.reviews.length} đánh giá gần đây',
                    child: _reviewController.reviews.isEmpty
                        ? const Text(
                            'Hãy là người đầu tiên chia sẻ trải nghiệm về tour này.',
                          )
                        : Column(
                            children: _reviewController.reviews
                                .map(
                                  (review) => _ReviewCard(review: review),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(tour) {
    int? minPrice;
    for (final s in _tourController.detailSchedules) {
      for (final t in s.tickets) {
        if (t.isActive != false &&
            t.availableQuantity > 0 &&
            (minPrice == null || t.effectivePrice < minPrice)) {
          minPrice = t.effectivePrice;
        }
      }
    }
    
    final hasImages = tour.tourImages != null && tour.tourImages!.isNotEmpty;
    final images = hasImages ? tour.tourImages! : (tour.imageUrl != null ? [tour.imageUrl!] : []);

    return Stack(
      children: [
        SizedBox(
          height: 320,
          width: double.infinity,
          child: images.isNotEmpty
              ? PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Hero(
                      tag: 'tour-image-${tour.id}-$index',
                      child: CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _heroFallback(),
                      ),
                    );
                  },
                )
              : Hero(
                  tag: 'tour-image-${tour.id}',
                  child: _heroFallback(),
                ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xCC05073C),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 120, // Position above the title area
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  width: _currentImageIndex == index ? 8.0 : 6.0,
                  height: _currentImageIndex == index ? 8.0 : 6.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (tour.averageStar != null)
                    _heroPill(
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFFFFB800),
                      label: tour.averageStar!.toStringAsFixed(1),
                    ),
                  if (minPrice != null)
                    _heroPill(
                      icon: Icons.local_offer_rounded,
                      iconColor: Colors.white,
                      label: 'Từ ${CurrencyFormatter.format(minPrice)}',
                      background: AppColors.brand.withValues(alpha: 0.9),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tour.name,
                style: AppTextStyles.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place_rounded,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tour.locationLabel,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfo() {
    final scheduleCount = _tourController.detailSchedules.length;
    final dayCount = _itineraries
        .map((e) => e.dayNumber ?? 0)
        .fold<int>(0, (a, b) => b > a ? b : a);
    final tour = _tourController.selectedTour.value;
    final items = <List<dynamic>>[
      [Icons.event_available_rounded, '$scheduleCount lịch', 'Khởi hành'],
      [
        Icons.schedule_rounded,
        dayCount > 0 ? '$dayCount ngày' : 'Linh hoạt',
        'Thời lượng',
      ],
      [
        Icons.star_rounded,
        tour?.averageStar != null
            ? tour!.averageStar!.toStringAsFixed(1)
            : 'Mới',
        'Đánh giá',
      ],
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      i == 0 ? AppColors.brandLight : AppColors.surfaceGrouped,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    Icon(items[i][0] as IconData,
                        color: AppColors.brand, size: 21),
                    const SizedBox(height: 5),
                    Text(
                      items[i][1] as String,
                      style: AppTextStyles.textTheme.titleSmall,
                    ),
                    Text(
                      items[i][2] as String,
                      style: AppTextStyles.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
            if (i < items.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleCard(TourScheduleModel schedule) {
    final available = _scheduleAvailable(schedule);
    final selected = _selectedSchedule?.id == schedule.id;
    final minPrice = _scheduleMinPrice(schedule);
    final originalMinPrice = _scheduleOriginalMinPrice(schedule);
    final seats = _scheduleAvailableSeats(schedule);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandLight : AppColors.surfaceGrouped,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: available ? () => _selectSchedule(schedule) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: available
                        ? AppColors.brand.withValues(alpha: 0.12)
                        : AppColors.fillTertiary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color:
                        available ? AppColors.brand : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormatter.display(schedule.departureDate)} - '
                        '${DateFormatter.display(schedule.returnDate)}',
                        style: AppTextStyles.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        available
                            ? '$seats chỗ còn lại'
                            : schedule.tickets.isEmpty
                                ? 'Chưa mở bán vé'
                                : 'Đã hết chỗ',
                        style: AppTextStyles.textTheme.bodySmall?.copyWith(
                          color: available && seats <= 5
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (minPrice != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Từ', style: AppTextStyles.textTheme.labelSmall),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (originalMinPrice != null && minPrice < originalMinPrice)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                CurrencyFormatter.format(originalMinPrice),
                                style: AppTextStyles.textTheme.bodySmall?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          Text(
                            CurrencyFormatter.format(minPrice),
                            style: AppTextStyles.textTheme.titleSmall?.copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: selected ? AppColors.brand : AppColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlights() {
    const highlights = [
      [Icons.verified_user_rounded, 'Hướng dẫn viên chuyên nghiệp'],
      [Icons.directions_bus_rounded, 'Phương tiện di chuyển'],
      [Icons.confirmation_number_rounded, 'Vé tham quan & phí vào cửa'],
      [Icons.event_repeat_rounded, 'Miễn phí hủy theo chính sách'],
    ];
    return Column(
      children: [
        for (final h in highlights)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child:
                      Icon(h[0] as IconData, color: AppColors.brand, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    h[1] as String,
                    style: AppTextStyles.textTheme.bodyMedium,
                  ),
                ),
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildItineraryTimeline() {
    final grouped = <int, List<TourItineraryModel>>{};
    for (final itinerary in _itineraries) {
      grouped.putIfAbsent(itinerary.dayNumber ?? 1, () => []).add(itinerary);
    }
    final days = grouped.keys.toList()..sort();

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF05073C), Color(0xFF0048B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${days.length} ngày khám phá',
                      style: AppTextStyles.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chạm vào từng ngày để xem hoặc thu gọn lịch trình.',
                      style: AppTextStyles.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (var dayIndex = 0; dayIndex < days.length; dayIndex++) ...[
          _buildItineraryDay(
            day: days[dayIndex],
            activities: grouped[days[dayIndex]]!,
            isLastDay: dayIndex == days.length - 1,
          ),
        ],
      ],
    );
  }

  bool get _allItineraryDaysExpanded {
    final days = _itineraries.map((item) => item.dayNumber ?? 1).toSet();
    return days.isNotEmpty && _expandedItineraryDays.containsAll(days);
  }

  void _toggleAllItineraryDays() {
    final days = _itineraries.map((item) => item.dayNumber ?? 1).toSet();
    setState(() {
      _expandedItineraryDays = _allItineraryDaysExpanded ? <int>{} : days;
    });
  }

  Widget _buildItineraryDay({
    required int day,
    required List<TourItineraryModel> activities,
    required bool isLastDay,
  }) {
    final expanded = _expandedItineraryDays.contains(day);
    final heritageCount = activities
        .where((item) =>
            item.tourismInfoId != null &&
            _tourismInformation.containsKey(item.tourismInfoId))
        .length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: EdgeInsets.only(bottom: isLastDay ? 0 : 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrouped,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: expanded
              ? AppColors.brand.withValues(alpha: 0.2)
              : AppColors.border,
        ),
        boxShadow: expanded
            ? [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (expanded) {
                    _expandedItineraryDays.remove(day);
                  } else {
                    _expandedItineraryDays.add(day);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.brandLight, AppColors.surface],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$day',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày $day',
                            style: AppTextStyles.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            heritageCount > 0
                                ? '${activities.length} hoạt động • $heritageCount điểm di sản'
                                : '${activities.length} hoạt động',
                            style: AppTextStyles.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                for (var activityIndex = 0;
                    activityIndex < activities.length;
                    activityIndex++)
                  _ItineraryActivityCard(
                    itinerary: activities[activityIndex],
                    tourismInformation:
                        activities[activityIndex].tourismInfoId == null
                            ? null
                            : _tourismInformation[
                                activities[activityIndex].tourismInfoId],
                    isLast: activityIndex == activities.length - 1,
                  ),
              ],
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 260),
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _heroFallback() => Container(
        color: AppColors.brandLight,
        child: const Center(
          child:
              Icon(Icons.landscape_rounded, size: 64, color: AppColors.brand),
        ),
      );

  Widget _heroPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color background = const Color(0x33000000),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(int tourId, {ReviewModel? existing}) {
    final commentController =
        TextEditingController(text: existing?.comment ?? '');
    var rating = existing?.rating ?? 5;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Sửa đánh giá' : 'Viết đánh giá'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setState(() => rating = i + 1),
                  );
                }),
              ),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(hintText: 'Nhận xét...'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              await _reviewController.submitReview(
                tourId: tourId,
                rating: rating,
                comment: commentController.text,
                existingReviewId: existing?.id,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }
}

class _ItineraryActivityCard extends StatelessWidget {
  const _ItineraryActivityCard({
    required this.itinerary,
    required this.isLast,
    this.tourismInformation,
  });

  final TourItineraryModel itinerary;
  final bool isLast;
  final TourismInformationModel? tourismInformation;

  @override
  Widget build(BuildContext context) {
    final heritage = tourismInformation;
    final title = heritage?.name.trim().isNotEmpty == true
        ? heritage!.name.trim()
        : itinerary.title?.trim().isNotEmpty == true
            ? itinerary.title!.trim()
            : 'Hoạt động trong ngày';
    final description = heritage?.description?.trim().isNotEmpty == true
        ? heritage!.description!.trim()
        : itinerary.description?.trim();
    final location = heritage?.locationLabel ??
        (itinerary.locationName?.trim().isNotEmpty == true
            ? itinerary.locationName!.trim()
            : null);
    final imageUrl = heritage?.imageUrl?.trim();
    final sourceUri = _sourceUri(heritage?.sourceUrl);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, isLast ? 14 : 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  if (!isLast)
                    Positioned(
                      top: 34,
                      bottom: -14,
                      child: Container(
                        width: 2,
                        color: AppColors.brand.withValues(alpha: 0.16),
                      ),
                    ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: heritage != null
                          ? const LinearGradient(
                              colors: [AppColors.accent, Color(0xFFFF9A4D)],
                            )
                          : AppColors.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (heritage != null
                                  ? AppColors.accent
                                  : AppColors.brand)
                              .withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      heritage != null
                          ? Icons.account_balance_rounded
                          : Icons.schedule_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Stack(
                        children: [
                          SizedBox(
                            height: 164,
                            width: double.infinity,
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _heritageImageFallback(),
                            ),
                          ),
                          const Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xA805073C),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (heritage?.type?.trim().isNotEmpty == true)
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: _HeritageBadge(
                                label: heritage!.type!.trim(),
                              ),
                            ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (heritage != null &&
                              (imageUrl == null || imageUrl.isEmpty))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: _HeritageBadge(
                                label: heritage.type?.trim().isNotEmpty == true
                                    ? heritage.type!.trim()
                                    : 'Điểm di sản',
                              ),
                            ),
                          Text(
                            title,
                            style: AppTextStyles.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          if (heritage != null &&
                              itinerary.title?.trim().isNotEmpty == true &&
                              itinerary.title!.trim() != title) ...[
                            const SizedBox(height: 4),
                            Text(
                              itinerary.title!.trim(),
                              style:
                                  AppTextStyles.textTheme.bodySmall?.copyWith(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ItineraryTimeChip(
                                icon: Icons.play_arrow_rounded,
                                label: 'Bắt đầu',
                                value: itinerary.startTimeLabel ?? 'Linh hoạt',
                                color: AppColors.brand,
                              ),
                              if (itinerary.endTimeLabel != null)
                                _ItineraryTimeChip(
                                  icon: Icons.flag_rounded,
                                  label: 'Kết thúc',
                                  value: itinerary.endTimeLabel!,
                                  color: AppColors.accent,
                                ),
                            ],
                          ),
                          if (location != null) ...[
                            const SizedBox(height: 11),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.place_rounded,
                                  size: 17,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: AppTextStyles.textTheme.bodySmall
                                        ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (description?.isNotEmpty == true) ...[
                            const SizedBox(height: 11),
                            Text(
                              description!,
                              style:
                                  AppTextStyles.textTheme.bodySmall?.copyWith(
                                height: 1.55,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (sourceUri != null) ...[
                            const SizedBox(height: 12),
                            _HeritageSourceLink(
                              sourceName:
                                  heritage?.sourceName?.trim().isNotEmpty ==
                                          true
                                      ? heritage!.sourceName!.trim()
                                      : 'Nguồn tham khảo',
                              uri: sourceUri,
                            ),
                          ],
                          if (heritage == null && itinerary.hasCoordinates) ...[
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                const Icon(
                                  Icons.map_outlined,
                                  size: 15,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${itinerary.locationLat!.toStringAsFixed(5)}, '
                                  '${itinerary.locationLng!.toStringAsFixed(5)}',
                                  style: AppTextStyles.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ],
                        ],
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

  Widget _heritageImageFallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF1EB), Color(0xFFE8F2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.account_balance_rounded,
            size: 46,
            color: AppColors.accent,
          ),
        ),
      );

  Uri? _sourceUri(String? rawUrl) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) return null;
    final normalized = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}

class _HeritageSourceLink extends StatelessWidget {
  const _HeritageSourceLink({
    required this.sourceName,
    required this.uri,
  });

  final String sourceName;
  final Uri uri;

  Future<void> _openSource(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở liên kết nguồn')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSource(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.brandLight.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  size: 17,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.textTheme.labelMedium?.copyWith(
                        color: AppColors.brandDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      uri.host.replaceFirst(RegExp(r'^www\.'), ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: AppColors.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeritageBadge extends StatelessWidget {
  const _HeritageBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItineraryTimeChip extends StatelessWidget {
  const _ItineraryTimeChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            '$label ',
            style: AppTextStyles.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.brand),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.textTheme.titleMedium),
                    if (subtitle != null)
                      Text(subtitle!, style: AppTextStyles.textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrouped,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Review body ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(
                  name: review.customerName,
                  avatarUrl: review.customerAvatar,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.customerName ?? 'Người dùng',
                        style: AppTextStyles.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 15,
                            color: const Color(0xFFFFB800),
                          ),
                        ),
                      ),
                      if (review.comment?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          review.comment!,
                          style: AppTextStyles.textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                      if (review.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          DateFormatter.display(review.createdAt),
                          style: AppTextStyles.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Replies ──────────────────────────────────────────
          if (review.replies.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.forum_rounded,
                          size: 14,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Phản hồi từ ban tổ chức',
                          style: AppTextStyles.textTheme.labelMedium?.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 12, endIndent: 12),

                  // Reply items
                  ...review.replies.map(
                    (reply) => _ReplyItem(reply: reply),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyItem extends StatelessWidget {
  const _ReplyItem({required this.reply});

  final ReviewReplyModel reply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            name: reply.userName,
            avatarUrl: reply.userAvatar,
            radius: 15,
            backgroundColor: AppColors.brand,
            textColor: Colors.white,
            fallbackIcon: Icons.support_agent_rounded,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reply.userName ?? 'Staff',
                        style: AppTextStyles.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (reply.createdAt != null)
                      Text(
                        DateFormatter.display(reply.createdAt!),
                        style: AppTextStyles.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (reply.content?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    reply.content!,
                    style: AppTextStyles.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dùng chung cho cả review author lẫn reply author.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    this.avatarUrl,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.fallbackIcon,
  });

  final String? name;
  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.brandLight;
    final fg = textColor ?? AppColors.brand;

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!.trim()),
        backgroundColor: bg,
      );
    }

    final initial =
        name?.trim().isNotEmpty == true ? name!.trim()[0].toUpperCase() : null;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: initial != null
          ? Text(
              initial,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.8,
              ),
            )
          : Icon(
              fallbackIcon ?? Icons.person_rounded,
              color: fg,
              size: radius,
            ),
    );
  }
}

class _SchedulePickerSheet extends StatefulWidget {
  final Map<String, List<TourScheduleModel>> schedulesByMonth;
  final TourScheduleModel? selectedSchedule;
  final ValueChanged<TourScheduleModel> onSelect;

  const _SchedulePickerSheet({
    required this.schedulesByMonth,
    this.selectedSchedule,
    required this.onSelect,
  });

  @override
  State<_SchedulePickerSheet> createState() => _SchedulePickerSheetState();
}

class _SchedulePickerSheetState extends State<_SchedulePickerSheet> {
  late String _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.schedulesByMonth.keys.first;
    if (widget.selectedSchedule != null) {
      for (final entry in widget.schedulesByMonth.entries) {
        if (entry.value.any((s) => s.id == widget.selectedSchedule!.id)) {
          _selectedMonth = entry.key;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chọn ngày khởi hành',
                  style: AppTextStyles.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: widget.schedulesByMonth.keys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final monthKey = widget.schedulesByMonth.keys.elementAt(index);
                final isSelected = monthKey == _selectedMonth;
                final lines = monthKey.split(' - ');
                return GestureDetector(
                  onTap: () => setState(() => _selectedMonth = monthKey),
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade50 : AppColors.surface,
                      border: Border.all(
                        color: isSelected ? Colors.blue : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: isSelected ? Colors.blue : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lines.first,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.blue : AppColors.textPrimary,
                          ),
                        ),
                        if (lines.length > 1)
                          Text(
                            lines[1],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.blue : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: widget.schedulesByMonth[_selectedMonth]!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final schedule = widget.schedulesByMonth[_selectedMonth]![index];
                final isSelected = schedule.id == widget.selectedSchedule?.id;
                
                int? minPrice;
                int? originalPrice;
                for (final t in schedule.tickets) {
                  if (t.isActive != false && t.availableQuantity > 0) {
                    if (minPrice == null || t.effectivePrice < minPrice) {
                      minPrice = t.effectivePrice;
                      originalPrice = t.price;
                    }
                  }
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.brand : AppColors.brandLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${schedule.departureDate.day}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.brand,
                            ),
                          ),
                          Text(
                            '${schedule.departureDate.month}-${schedule.departureDate.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : AppColors.brand,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (originalPrice != null && originalPrice > (minPrice ?? 0))
                            Text(
                              CurrencyFormatter.format(originalPrice),
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          Row(
                            children: [
                              const Text('Giá: ', style: TextStyle(color: AppColors.textSecondary)),
                              Text(
                                minPrice != null ? CurrencyFormatter.format(minPrice) : 'Chưa cập nhật',
                                style: const TextStyle(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Text(
                        'Đang chọn',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => widget.onSelect(schedule),
                        child: const Text('Chọn', style: TextStyle(color: Colors.white)),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
