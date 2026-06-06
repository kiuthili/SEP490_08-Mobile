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
import '../utils/booking_args.dart';
import '../utils/route_args.dart';
import '../utils/snackbar_helper.dart';
import '../models/tour_model.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/ios_grouped.dart';
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
      ever(_tourController.detailSchedules, (_) => refresh()),
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
    if (s.tickets.isEmpty) return true;
    return s.tickets.any((t) => t.isActive != false && t.availableQuantity > 0);
  }

  int? _scheduleMinPrice(TourScheduleModel s) {
    if (s.tickets.isEmpty) return null;
    final prices = s.tickets
        .where((t) => t.isActive != false && t.availableQuantity > 0)
        .map((t) => t.price);
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a < b ? a : b);
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (schedule != null)
              Text(
                'Khởi hành ${schedule.departureDate.toString().substring(0, 10)}',
                style: AppTextStyles.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            if (minPrice != null) ...[
              const SizedBox(height: 4),
              Text(
                'Từ ${CurrencyFormatter.format(minPrice)} / khách',
                style: AppTextStyles.textTheme.titleSmall?.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            CustomButton(
              label: 'Tiến hành đặt tour',
              onPressed: schedule != null && _scheduleAvailable(schedule)
                  ? () => _proceedToBooking(tour)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              'Chưa trừ tiền cho đến khi thanh toán thành công',
              style: AppTextStyles.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
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
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        inWishlist ? Icons.favorite : Icons.favorite_border,
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
      return const Center(child: Text('Không tìm thấy tour'));
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
                Text('Tổng quan', style: AppTextStyles.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  tour.description ?? 'Chưa có mô tả',
                  style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bao gồm trong tour',
                  style: AppTextStyles.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _buildHighlights(),
                if (_itineraries.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Lịch trình tour',
                    style: AppTextStyles.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildItineraryTimeline(),
                ],
                const SizedBox(height: 24),
                Text(
                  'Lịch khởi hành',
                  style: AppTextStyles.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_tourController.detailSchedules.isEmpty)
                  const Text('Chưa có lịch trình mở bán')
                else ...[
                  Text(
                    'Chọn ngày khởi hành để tiếp tục đặt tour',
                    style: AppTextStyles.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: _tourController.detailSchedules.map((s) {
                      final available = _scheduleAvailable(s);
                      final minPrice = _scheduleMinPrice(s);
                      final selected = _selectedSchedule?.id == s.id;
                      return IosPickRow(
                        key: ValueKey('schedule-${s.id}'),
                        selected: selected,
                        leading: Icon(
                          Icons.calendar_month,
                          color: available
                              ? AppColors.brand
                              : AppColors.textSecondary,
                        ),
                        title: Text(
                          '${s.departureDate.toString().substring(0, 10)} → '
                          '${s.returnDate.toString().substring(0, 10)}',
                        ),
                        subtitle: minPrice != null
                            ? Text('Từ ${CurrencyFormatter.format(minPrice)}')
                            : Text(available ? 'Chọn lịch này' : 'Đã hết chỗ'),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.brand,
                              )
                            : null,
                        onTap: available ? () => _selectSchedule(s) : null,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                Text('Đánh giá', style: AppTextStyles.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_reviewController.myReview.value != null)
                  OutlinedButton.icon(
                    onPressed: () => _showReviewDialog(
                      tour.id,
                      existing: _reviewController.myReview.value,
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Sửa đánh giá của tôi'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _showReviewDialog(tour.id),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Viết đánh giá'),
                  ),
                const SizedBox(height: 8),
                if (_reviewController.reviews.isEmpty)
                  const Text('Chưa có đánh giá')
                else
                  ..._reviewController.reviews.map(
                    (r) => IosSurfaceCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 88,
                            child: Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < r.rating ? Icons.star : Icons.star_border,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.customerName ?? 'Khách',
                                  style: AppTextStyles.textTheme.titleSmall,
                                ),
                                if (r.comment != null && r.comment!.isNotEmpty)
                                  Text(
                                    r.comment!,
                                    style: AppTextStyles.textTheme.bodySmall,
                                  ),
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
        ],
      ),
    );
  }

  Widget _buildHero(tour) {
    int? minPrice;
    for (final s in _tourController.detailSchedules) {
      for (final t in s.tickets) {
        if (minPrice == null || t.price < minPrice) minPrice = t.price;
      }
    }
    return Stack(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: tour.imageUrl != null && tour.imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: tour.imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _heroFallback(),
                )
              : _heroFallback(),
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
                  const Icon(
                    Icons.place_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
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
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceGrouped,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    items[i][0] as IconData,
                    color: AppColors.brand,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
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
          if (i < items.length - 1) const SizedBox(width: 10),
        ],
      ],
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
                  child: Icon(
                    h[0] as IconData,
                    color: AppColors.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    h[1] as String,
                    style: AppTextStyles.textTheme.bodyMedium,
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildItineraryTimeline() {
    return Column(
      children: [
        for (var i = 0; i < _itineraries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_itineraries[i].dayNumber ?? i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (i < _itineraries.length - 1)
                      Expanded(
                        child: Container(width: 2, color: AppColors.border),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _itineraries[i].title ?? 'Điểm đến',
                          style: AppTextStyles.textTheme.titleSmall,
                        ),
                        if (_itineraries[i].description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _itineraries[i].description!,
                            style: AppTextStyles.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    final commentController = TextEditingController(
      text: existing?.comment ?? '',
    );
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
