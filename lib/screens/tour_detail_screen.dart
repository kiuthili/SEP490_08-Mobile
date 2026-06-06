import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/feature_models.dart';
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
  TourScheduleModel? _selectedSchedule;

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
      Get.find<CatalogService>().getTourItineraries(_tourId!).then((list) {
        if (mounted) setState(() => _itineraries = list);
      });
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

  void _proceedToBooking(TourModel tour) {
    final schedule = _selectedSchedule;
    if (schedule == null) {
      SnackbarHelper.error('Vui lòng chọn lịch khởi hành');
      return;
    }
    Get.toNamed(
      AppRoutes.booking,
      arguments: BookingRouteArgs.fromTourSchedule(
        tour: tour,
        schedule: schedule,
      ),
    );
  }

  Widget? _buildCheckoutBar() {
    final tour = _tourController.selectedTour.value;
    if (tour == null) return null;
    final schedule = _selectedSchedule;
    final minPrice = schedule != null ? _scheduleMinPrice(schedule) : null;
    final hasSchedules = _tourController.detailSchedules.isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    minPrice != null
                        ? CurrencyFormatter.format(minPrice)
                        : schedule != null
                            ? 'Đang cập nhật giá'
                            : 'Chưa thể đặt',
                    style: AppTextStyles.textTheme.titleLarge?.copyWith(
                      color: minPrice != null
                          ? AppColors.brand
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    schedule != null
                        ? 'Khởi hành ${DateFormatter.display(schedule.departureDate)}'
                        : hasSchedules
                            ? 'Các lịch hiện đã hết chỗ'
                            : 'Chưa có lịch mở bán',
                    style: AppTextStyles.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 164,
              child: CustomButton(
                compact: true,
                label: schedule != null ? 'Đặt tour' : 'Chưa khả dụng',
                onPressed: schedule != null && _scheduleAvailable(schedule)
                    ? () => _proceedToBooking(tour)
                    : null,
              ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(tour),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickInfo(),
                const SizedBox(height: 20),
                _DetailSection(
                  icon: Icons.auto_stories_rounded,
                  title: 'Tổng quan',
                  child: Text(
                    tour.description ?? 'Chưa có mô tả',
                    style: AppTextStyles.textTheme.bodyMedium?.copyWith(
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
                if (_itineraries.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DetailSection(
                    icon: Icons.route_rounded,
                    title: 'Lịch trình tour',
                    subtitle:
                        '${_itineraries.length} hoạt động trong hành trình',
                    child: _buildItineraryTimeline(),
                  ),
                ],
                const SizedBox(height: 14),
                _DetailSection(
                  icon: Icons.calendar_month_rounded,
                  title: 'Lịch khởi hành',
                  subtitle: _tourController.detailSchedules.isEmpty
                      ? 'Chưa có lịch sắp tới'
                      : 'Chọn lịch phù hợp để tiếp tục',
                  child: _tourController.detailSchedules.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGrouped,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.event_busy_rounded,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tour chưa có lịch khởi hành sắp tới. '
                                  'Vui lòng quay lại sau.',
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children:
                              _tourController.detailSchedules.map((schedule) {
                            return _buildScheduleCard(schedule);
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _DetailSection(
                  icon: Icons.star_rounded,
                  title: 'Đánh giá',
                  subtitle: _reviewController.reviews.isEmpty
                      ? 'Chưa có đánh giá'
                      : '${_reviewController.reviews.length} đánh giá gần đây',
                  trailing: OutlinedButton.icon(
                    onPressed: () => _showReviewDialog(
                      tour.id,
                      existing: _reviewController.myReview.value,
                    ),
                    icon: Icon(
                      _reviewController.myReview.value != null
                          ? Icons.edit_rounded
                          : Icons.add_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _reviewController.myReview.value != null
                          ? 'Chỉnh sửa'
                          : 'Viết đánh giá',
                    ),
                  ),
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
    );
  }

  Widget _buildHero(tour) {
    int? minPrice;
    for (final s in _tourController.detailSchedules) {
      for (final t in s.tickets) {
        if (t.isActive != false &&
            t.availableQuantity > 0 &&
            (minPrice == null || t.price < minPrice)) {
          minPrice = t.price;
        }
      }
    }
    return Stack(
      children: [
        SizedBox(
          height: 320,
          width: double.infinity,
          child: Hero(
            tag: 'tour-image-${tour.id}',
            child: tour.imageUrl != null && tour.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: tour.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _heroFallback(),
                  )
                : _heroFallback(),
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
                      Text(
                        CurrencyFormatter.format(minPrice),
                        style: AppTextStyles.textTheme.titleSmall?.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w700,
                        ),
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
        for (var dayIndex = 0; dayIndex < days.length; dayIndex++) ...[
          Container(
            margin: EdgeInsets.only(
              bottom: dayIndex == days.length - 1 ? 0 : 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrouped,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.brandLight, AppColors.surface],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.md),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${days[dayIndex]}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ngày ${days[dayIndex]}',
                              style: AppTextStyles.textTheme.titleSmall,
                            ),
                            Text(
                              '${grouped[days[dayIndex]]!.length} hoạt động',
                              style: AppTextStyles.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.route_rounded,
                        color: AppColors.brand,
                      ),
                    ],
                  ),
                ),
                for (var activityIndex = 0;
                    activityIndex < grouped[days[dayIndex]]!.length;
                    activityIndex++)
                  _ItineraryActivityCard(
                    itinerary: grouped[days[dayIndex]]![activityIndex],
                    isLast:
                        activityIndex == grouped[days[dayIndex]]!.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ],
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
  });

  final TourItineraryModel itinerary;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final hasDescription = itinerary.description?.trim().isNotEmpty ?? false;
    final hasLocation = itinerary.locationName?.trim().isNotEmpty ?? false;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, isLast ? 14 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: AppColors.brand,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 92,
                    margin: const EdgeInsets.only(top: 6),
                    color: AppColors.border,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itinerary.title?.trim().isNotEmpty == true
                        ? itinerary.title!.trim()
                        : 'Hoạt động trong ngày',
                    style: AppTextStyles.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 9),
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
                  if (hasLocation) ...[
                    const SizedBox(height: 7),
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
                            itinerary.locationName!.trim(),
                            style: AppTextStyles.textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hasDescription) ...[
                    const SizedBox(height: 9),
                    Text(
                      itinerary.description!.trim(),
                      style: AppTextStyles.textTheme.bodySmall?.copyWith(
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (itinerary.hasCoordinates) ...[
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrouped,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.brandLight,
            child: Text(
              (review.customerName?.trim().isNotEmpty ?? false)
                  ? review.customerName!.trim()[0].toUpperCase()
                  : 'K',
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.customerName ?? 'Khách',
                  style: AppTextStyles.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < review.rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 15,
                      color: const Color(0xFFFFB800),
                    ),
                  ),
                ),
                if (review.comment != null &&
                    review.comment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    review.comment!,
                    style: AppTextStyles.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
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
