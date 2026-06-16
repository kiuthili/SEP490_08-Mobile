import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/feature_controllers.dart';
import '../../models/order_model.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../services/catalog_service.dart';
import '../../services/tour_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_widget.dart';
import 'my_tickets_screen.dart';

bool _isToday(DateTime? date) {
  if (date == null) return false;
  final localDate = date.toLocal();
  final today = DateTime.now();
  return localDate.year == today.year &&
      localDate.month == today.month &&
      localDate.day == today.day;
}

int? _daysUntilDeparture(DateTime? date) {
  if (date == null) return null;
  final diff = date.toLocal().difference(DateTime.now());
  return (diff.inMilliseconds / Duration.millisecondsPerDay).ceil();
}

int? _cancellationFeePercent(int? daysUntilDeparture) {
  if (daysUntilDeparture == null || daysUntilDeparture <= 1) return null;
  if (daysUntilDeparture <= 2) return 10;
  if (daysUntilDeparture <= 5) return 15;
  if (daysUntilDeparture <= 10) return 10;
  if (daysUntilDeparture <= 15) return 5;
  return 0;
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _controller = Get.find<OrderController>();
  final _tourService = Get.find<TourService>();
  final _catalogService = Get.find<CatalogService>();
  List<TourScheduleItineraryModel> _itineraries = [];
  Map<int, TourismInformationModel> _tourismInformation = {};
  Map<int, String> _ticketTypeNames = {};
  Set<int> _expandedDays = {};
  bool _loadingItineraries = false;
  String? _itineraryError;
  int? _loadedScheduleId;

  @override
  void initState() {
    super.initState();
    final id = Get.arguments as int?;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.selectedOrder.value?.id != id) {
          _controller.selectedOrder.value = null;
        }
        _refreshOrder(id);
      });
    }
  }

  Future<void> _refreshOrder(int orderId) async {
    await _controller.fetchOrderDetail(orderId);
    final order = _controller.selectedOrder.value;
    if (!mounted || order?.id != orderId) return;
    await Future.wait([
      _loadItineraries(order!),
      _loadTicketTypeNames(order),
    ]);
  }

  Future<void> _loadItineraries(
    OrderModel order, {
    bool force = false,
  }) async {
    if (!_shouldLoadItineraries(order)) {
      if (_loadedScheduleId != null ||
          _itineraries.isNotEmpty ||
          _tourismInformation.isNotEmpty ||
          _expandedDays.isNotEmpty ||
          _loadingItineraries ||
          _itineraryError != null) {
        setState(() {
          _loadedScheduleId = null;
          _itineraries = [];
          _tourismInformation = {};
          _expandedDays = {};
          _loadingItineraries = false;
          _itineraryError = null;
        });
      }
      return;
    }

    final scheduleId =
        order.scheduleId > 0 ? order.scheduleId : order.schedule?.id ?? 0;
    if (scheduleId <= 0) return;
    if (!force && _loadedScheduleId == scheduleId && _itineraries.isNotEmpty) {
      return;
    }

    setState(() {
      _loadedScheduleId = scheduleId;
      _loadingItineraries = true;
      _itineraryError = null;
      if (force || _itineraries.isNotEmpty) {
        _itineraries = [];
        _tourismInformation = {};
        _expandedDays = {};
      }
    });

    try {
      final itineraries = await _tourService.getScheduleItineraries(scheduleId);
      if (!mounted || _loadedScheduleId != scheduleId) return;
      final tourismInformation = await _loadTourismInformation(itineraries);
      if (!mounted || _loadedScheduleId != scheduleId) return;
      final days = itineraries.map((item) => item.dayNumber).toSet();
      final todayDay = itineraries
          .where((item) => _isToday(item.itineraryDate))
          .map((item) => item.dayNumber)
          .firstOrNull;
      setState(() {
        _itineraries = itineraries;
        _tourismInformation = tourismInformation;
        _expandedDays = todayDay != null
            ? {todayDay}
            : days.length <= 2
                ? days
                : {days.first};
      });
    } catch (e) {
      if (!mounted || _loadedScheduleId != scheduleId) return;
      setState(() => _itineraryError = e.toString());
    } finally {
      if (mounted && _loadedScheduleId == scheduleId) {
        setState(() => _loadingItineraries = false);
      }
    }
  }

  bool _shouldLoadItineraries(OrderModel order) {
    final status = order.status?.trim().toLowerCase();
    return status != 'pending' && status != 'cancelled';
  }

  Future<Map<int, TourismInformationModel>> _loadTourismInformation(
    List<TourScheduleItineraryModel> itineraries,
  ) async {
    final ids = itineraries
        .map((item) => item.tourismInfoId)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
    if (ids.isEmpty) return {};

    final entries = await Future.wait(
      ids.map((id) async {
        try {
          final info = await _catalogService.getTourismInformationById(id);
          return MapEntry(id, info);
        } catch (_) {
          return null;
        }
      }),
    );

    return Map.fromEntries(
        entries.whereType<MapEntry<int, TourismInformationModel>>());
  }

  Future<void> _loadTicketTypeNames(OrderModel order) async {
    final ids = <int>{
      ...order.orderDetails.map((detail) => detail.ticketTypeId),
      ...order.tickets.map((ticket) => ticket.ticketTypeId),
    }.where((id) => id > 0).toSet();

    if (ids.isEmpty) {
      if (mounted) setState(() => _ticketTypeNames = {});
      return;
    }

    final entries = await Future.wait(
      ids.map((id) async {
        try {
          final ticketType = await _catalogService.getTicketTypeById(id);
          final name = ticketType.name.trim();
          if (name.isEmpty) return null;
          return MapEntry(id, name);
        } catch (_) {
          return null;
        }
      }),
    );

    if (!mounted || _controller.selectedOrder.value?.id != order.id) return;
    setState(() {
      _ticketTypeNames =
          Map.fromEntries(entries.whereType<MapEntry<int, String>>());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final order = _controller.selectedOrder.value;
      return AppScreen(
        title: order == null ? 'Chi tiết đơn' : 'Đơn #${order.id}',
        actions: order == null
            ? null
            : [
                IconButton(
                  tooltip: 'Làm mới',
                  onPressed: () => _refreshOrder(order.id),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 6),
              ],
        body: _buildBody(order),
      );
    });
  }

  Widget _buildBody(OrderModel? order) {
    if (_controller.isLoading.value && order == null) {
      return const LoadingWidget(message: 'Đang tải chi tiết đơn...');
    }
    if (order == null) {
      return const _OrderNotFound();
    }

    return RefreshIndicator(
      onRefresh: () => _refreshOrder(order.id),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OrderHero(order: order),
            const SizedBox(height: 16),
            _OrderValueCard(order: order),
            const SizedBox(height: 20),
            const _SectionTitle(
              icon: Icons.route_rounded,
              title: 'Hành trình',
              subtitle: 'Thông tin lịch khởi hành của chuyến đi',
            ),
            const SizedBox(height: 10),
            _TripTimeline(order: order),
            if (_shouldLoadItineraries(order)) ...[
              const SizedBox(height: 12),
              _ScheduleItineraryPanel(
                itineraries: _itineraries,
                tourismInformation: _tourismInformation,
                expandedDays: _expandedDays,
                loading: _loadingItineraries,
                error: _itineraryError,
                onRetry: () => _loadItineraries(order, force: true),
                onToggleDay: (day) {
                  setState(() {
                    if (_expandedDays.contains(day)) {
                      _expandedDays.remove(day);
                    } else {
                      _expandedDays.add(day);
                    }
                  });
                },
                onToggleAll: () {
                  final allDays =
                      _itineraries.map((item) => item.dayNumber).toSet();
                  setState(() {
                    _expandedDays =
                        _expandedDays.containsAll(allDays) ? <int>{} : allDays;
                  });
                },
              ),
            ],
            const SizedBox(height: 20),
            const _SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: 'Thông tin đơn',
              subtitle: 'Chi tiết thanh toán và ưu đãi',
            ),
            const SizedBox(height: 10),
            _OrderInformationCard(
              order: order,
              ticketTypeNames: _ticketTypeNames,
            ),
            if (order.status == 'Pending') ...[
              const SizedBox(height: 20),
              const _PendingOrderNotice(),
            ],
            if (order.status == 'Paid' || order.status == 'Completed') ...[
              const SizedBox(height: 20),
              OrderTicketsPanel(
                tickets: order.tickets,
                ticketTypeNames: _ticketTypeNames,
              ),
              const SizedBox(height: 16),
              _PostPaymentActions(
                completed: order.status == 'Completed',
                showCancellation: _canRequestCancellation(order),
                onCancellation: () => _openCancellationRequest(order),
                onReview: () => _showReviewDialog(order),
              ),
            ],
            if (order.status == 'Cancelled' ||
                order.status == 'Request to Cancelled') ...[
              const SizedBox(height: 20),
              _InactiveOrderNotice(status: order.status),
            ],
          ],
        ),
      ),
    );
  }

  bool _canRequestCancellation(OrderModel order) {
    final status = order.status?.trim().toLowerCase();
    return status == 'paid';
  }

  Future<void> _openCancellationRequest(OrderModel order) async {
    if (!_canRequestCancellation(order)) {
      SnackbarHelper.error('Chỉ đơn đã thanh toán mới có thể yêu cầu hủy tour');
      return;
    }

    final daysUntilDeparture =
        _daysUntilDeparture(order.schedule?.departureDate);
    final feePercent = _cancellationFeePercent(daysUntilDeparture);
    if (feePercent == null || daysUntilDeparture == null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Không thể yêu cầu hủy'),
          content: const Text(
            'Yêu cầu hủy không được hỗ trợ trong vòng 1 ngày trước ngày khởi hành hoặc khi thiếu thông tin ngày khởi hành.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    final feeBase =
        order.totalAmount > 0 ? order.totalAmount : order.finalAmount;
    final cancellationFee = (feeBase * feePercent / 100).round();
    final estimatedRefund =
        (order.finalAmount - cancellationFee).clamp(0, 1 << 31);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận chính sách hủy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Còn $daysUntilDeparture ngày trước ngày khởi hành.'),
            const SizedBox(height: 10),
            Text(
              'Phí hủy: $feePercent% '
              '(${CurrencyFormatter.format(cancellationFee)})',
            ),
            const SizedBox(height: 6),
            Text('Dự kiến hoàn: ${CurrencyFormatter.format(estimatedRefund)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final orderId = order.id;
    final ok = await Get.toNamed<bool>(
      AppRoutes.requestCancellation,
      arguments: {
        'orderId': orderId,
        'status': order.status,
        'departureDate': order.schedule?.departureDate.toIso8601String(),
      },
    );
    if (ok == true && mounted) {
      await _controller.fetchOrderDetail(orderId);
    }
  }

  void _showReviewDialog(OrderModel order) {
    final commentController = TextEditingController();
    var rating = 5;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đánh giá chuyến đi'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trải nghiệm của bạn thế nào?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFFFB020),
                      size: 30,
                    ),
                    onPressed: () {
                      setDialogState(() => rating = index + 1);
                    },
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Chia sẻ cảm nhận của bạn...',
                  prefixIcon: Icon(Icons.rate_review_outlined),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Để sau'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final reviewController = Get.find<ReviewController>();
              await reviewController.submitReview(
                tourId: order.tour?.id ?? 0,
                rating: rating,
                comment: commentController.text,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Gửi đánh giá'),
          ),
        ],
      ),
    ).whenComplete(commentController.dispose);
  }
}

class _OrderHero extends StatelessWidget {
  const _OrderHero({required this.order});

  final OrderModel order;

  String get _location {
    final parts = [
      order.tour?.city,
      order.tour?.country,
    ].whereType<String>().where((value) => value.trim().isNotEmpty);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final status = _OrderStatusStyle.from(order.status);
    return Container(
      height: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.15),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (order.tour?.imageUrl?.isNotEmpty == true)
            CachedNetworkImage(
              imageUrl: order.tour!.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.brandLight),
              errorWidget: (_, __, ___) => const _HeroPlaceholder(),
            )
          else
            const _HeroPlaceholder(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x1505073C),
                  Color(0x4D05073C),
                  Color(0xED05073C),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: _StatusPill(style: status),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.36),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Mã đơn #${order.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.tour?.name ?? 'Chuyến đi của bạn',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                if (_location.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 17,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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

class _OrderValueCard extends StatelessWidget {
  const _OrderValueCard({required this.order});

  final OrderModel order;

  int get _quantity =>
      order.totalQuantity > 0 ? order.totalQuantity : order.ticketCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071A3D), Color(0xFF073B78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TỔNG THANH TOÁN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  CurrencyFormatter.format(order.finalAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 42,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_quantity vé',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormatter.display(order.orderedAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.brandLight,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 21, color: AppColors.brand),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripTimeline extends StatelessWidget {
  const _TripTimeline({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final schedule = order.schedule;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: schedule == null
          ? const _EmptySchedule()
          : Row(
              children: [
                Expanded(
                  child: _TimelineDate(
                    label: 'KHỞI HÀNH',
                    date: schedule.departureDate,
                    icon: Icons.flight_takeoff_rounded,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.brand,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${schedule.returnDate.difference(schedule.departureDate).inDays + 1} ngày',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _TimelineDate(
                    label: 'KẾT THÚC',
                    date: schedule.returnDate,
                    icon: Icons.flag_rounded,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ScheduleItineraryPanel extends StatelessWidget {
  const _ScheduleItineraryPanel({
    required this.itineraries,
    required this.tourismInformation,
    required this.expandedDays,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onToggleDay,
    required this.onToggleAll,
  });

  final List<TourScheduleItineraryModel> itineraries;
  final Map<int, TourismInformationModel> tourismInformation;
  final Set<int> expandedDays;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<int> onToggleDay;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    if (loading && itineraries.isEmpty) {
      return const _ItineraryLoadingCard();
    }
    if (error != null && itineraries.isEmpty) {
      return _ItineraryErrorCard(onRetry: onRetry);
    }
    if (itineraries.isEmpty) {
      return const _EmptyItineraryCard();
    }

    final grouped = <int, List<TourScheduleItineraryModel>>{};
    for (final itinerary in itineraries) {
      grouped.putIfAbsent(itinerary.dayNumber, () => []).add(itinerary);
    }
    final days = grouped.keys.toList()..sort();
    final allExpanded = expandedDays.containsAll(days);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF05073C), Color(0xFF0048B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                    Icons.map_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lịch trình chi tiết',
                        style: AppTextStyles.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${days.length} ngày • ${itineraries.length} hoạt động',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onToggleAll,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(allExpanded ? 'Thu gọn' : 'Mở hết'),
                ),
              ],
            ),
          ),
          for (var index = 0; index < days.length; index++)
            _ItineraryDayCard(
              day: days[index],
              activities: grouped[days[index]]!,
              tourismInformation: tourismInformation,
              expanded: expandedDays.contains(days[index]),
              isLast: index == days.length - 1,
              onTap: () => onToggleDay(days[index]),
            ),
        ],
      ),
    );
  }
}

class _ItineraryDayCard extends StatelessWidget {
  const _ItineraryDayCard({
    required this.day,
    required this.activities,
    required this.tourismInformation,
    required this.expanded,
    required this.isLast,
    required this.onTap,
  });

  final int day;
  final List<TourScheduleItineraryModel> activities;
  final Map<int, TourismInformationModel> tourismInformation;
  final bool expanded;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = activities
        .map((item) => item.itineraryDate)
        .whereType<DateTime>()
        .firstOrNull;
    final isToday = _isToday(date);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: isToday
              ? const BorderSide(color: AppColors.brand, width: 4)
              : BorderSide.none,
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: AppColors.separator),
        ),
      ),
      child: Column(
        children: [
          Material(
            color: isToday
                ? AppColors.brandLight
                : expanded
                    ? AppColors.brandLight.withValues(alpha: 0.6)
                    : Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                          Row(
                            children: [
                              Text(
                                'Ngày $day',
                                style: AppTextStyles.textTheme.titleSmall
                                    ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isToday
                                      ? AppColors.brandDeep
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: const Text(
                                    'HÔM NAY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date == null
                                ? '${activities.length} hoạt động'
                                : '${DateFormatter.display(date)} • ${activities.length} hoạt động',
                            style: Theme.of(context).textTheme.bodySmall,
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
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 15),
              child: Column(
                children: [
                  for (var index = 0; index < activities.length; index++)
                    _ScheduleActivity(
                      itinerary: activities[index],
                      tourismInformation: activities[index].tourismInfoId ==
                              null
                          ? null
                          : tourismInformation[activities[index].tourismInfoId],
                      isLast: index == activities.length - 1,
                    ),
                ],
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }
}

class _ScheduleActivity extends StatelessWidget {
  const _ScheduleActivity({
    required this.itinerary,
    required this.isLast,
    this.tourismInformation,
  });

  final TourScheduleItineraryModel itinerary;
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: heritage != null ? AppColors.brandGradient : null,
                    color: heritage == null ? AppColors.accentLight : null,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (heritage != null
                              ? AppColors.brand
                              : AppColors.accent)
                          .withValues(alpha: 0.24),
                    ),
                  ),
                  child: Icon(
                    heritage != null
                        ? Icons.account_balance_rounded
                        : Icons.place_rounded,
                    size: 15,
                    color: heritage != null ? Colors.white : AppColors.accent,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.brand.withValues(alpha: 0.16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      heritage != null ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: heritage != null
                      ? Border.all(
                          color: AppColors.accent.withValues(alpha: 0.18),
                        )
                      : null,
                ),
                clipBehavior: heritage != null ? Clip.antiAlias : Clip.none,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl?.isNotEmpty == true)
                      Stack(
                        children: [
                          SizedBox(
                            height: 132,
                            width: double.infinity,
                            child: CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const _HeritageImageFallback(),
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
                                    Color(0x9905073C),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: _HeritageBadge(
                              label: heritage?.type?.trim().isNotEmpty == true
                                  ? heritage!.type!.trim()
                                  : 'Điểm di sản',
                            ),
                          ),
                        ],
                      ),
                    Padding(
                      padding: EdgeInsets.all(heritage != null ? 12 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (itinerary.timeLabel != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 7),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandLight,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    itinerary.timeLabel!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.brand,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              if (heritage != null &&
                                  (imageUrl == null || imageUrl.isEmpty))
                                _HeritageBadge(
                                  label:
                                      heritage.type?.trim().isNotEmpty == true
                                          ? heritage.type!.trim()
                                          : 'Điểm di sản',
                                ),
                            ],
                          ),
                          if (itinerary.timeLabel != null || heritage != null)
                            const SizedBox(height: 7),
                          Text(
                            title,
                            style: AppTextStyles.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (heritage != null &&
                              itinerary.title?.trim().isNotEmpty == true &&
                              itinerary.title!.trim() != title) ...[
                            const SizedBox(height: 4),
                            Text(
                              itinerary.title!.trim(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                          if (location?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 15,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    location!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (description?.isNotEmpty == true) ...[
                            const SizedBox(height: 7),
                            Text(
                              description!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (sourceUri != null) ...[
                            const SizedBox(height: 10),
                            _HeritageSourceLink(
                              sourceName:
                                  heritage?.sourceName?.trim().isNotEmpty ==
                                          true
                                      ? heritage!.sourceName!.trim()
                                      : 'Nguồn tham khảo',
                              uri: sourceUri,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

class _HeritageImageFallback extends StatelessWidget {
  const _HeritageImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          size: 38,
          color: AppColors.accent,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.22),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.brandLight.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.public_rounded,
                size: 17,
                color: AppColors.brand,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.brandDeep,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                uri.host.replaceFirst(RegExp(r'^www\.'), ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: AppColors.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItineraryLoadingCard extends StatelessWidget {
  const _ItineraryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Đang tải lịch trình chi tiết...'),
        ],
      ),
    );
  }
}

class _ItineraryErrorCard extends StatelessWidget {
  const _ItineraryErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_outlined, color: AppColors.error),
          const SizedBox(width: 10),
          const Expanded(child: Text('Chưa tải được lịch trình chuyến đi.')),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _EmptyItineraryCard extends StatelessWidget {
  const _EmptyItineraryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrouped,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_note_outlined, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text('Lịch trình chi tiết đang được cập nhật.'),
          ),
        ],
      ),
    );
  }
}

class _TimelineDate extends StatelessWidget {
  const _TimelineDate({
    required this.label,
    required this.date,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final DateTime date;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.brand),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormatter.display(date),
          style: AppTextStyles.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _OrderInformationCard extends StatelessWidget {
  const _OrderInformationCard({
    required this.order,
    required this.ticketTypeNames,
  });

  final OrderModel order;
  final Map<int, String> ticketTypeNames;

  @override
  Widget build(BuildContext context) {
    final hasNote = order.note?.isNotEmpty == true;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.tag_rounded,
            label: 'Mã đơn',
            value: '#${order.id}',
          ),
          _DetailRow(
            icon: Icons.event_note_rounded,
            label: 'Ngày đặt',
            value: DateFormatter.display(order.orderedAt),
          ),
          _TicketBreakdownSection(
            order: order,
            ticketTypeNames: ticketTypeNames,
          ),
          _DetailRow(
            icon: Icons.payments_outlined,
            label: 'Tạm tính',
            value: CurrencyFormatter.format(order.totalAmount),
            isAmount: true,
          ),
          if ((order.discountValue ?? 0) > 0)
            _DetailRow(
              icon: Icons.local_offer_outlined,
              label: 'Ưu đãi',
              value: '-${CurrencyFormatter.format(order.discountValue!)}',
              valueColor: AppColors.success,
              isAmount: true,
            ),
          if (order.voucherCode?.isNotEmpty == true)
            _DetailRow(
              icon: Icons.confirmation_number_outlined,
              label: 'Voucher',
              value: order.voucherCode!,
            ),
          _DetailRow(
            icon: Icons.receipt_rounded,
            label: 'Thành tiền',
            value: CurrencyFormatter.format(order.finalAmount),
            valueColor: AppColors.brand,
            isAmount: true,
            isLast: !hasNote,
          ),
          if (hasNote)
            _DetailRow(
              icon: Icons.notes_rounded,
              label: 'Ghi chú',
              value: order.note!,
              isLast: true,
            ),
        ],
      ),
    );
  }
}

class _TicketBreakdownSection extends StatelessWidget {
  const _TicketBreakdownSection({
    required this.order,
    required this.ticketTypeNames,
  });

  final OrderModel order;
  final Map<int, String> ticketTypeNames;

  List<_TicketBreakdownItem> get _items {
    if (order.orderDetails.isNotEmpty) {
      return order.orderDetails
          .where((detail) => detail.quantity > 0 || detail.tickets.isNotEmpty)
          .map((detail) {
        final quantity =
            detail.quantity > 0 ? detail.quantity : detail.tickets.length;
        final totalPrice = detail.totalPrice > 0
            ? detail.totalPrice
            : detail.unitPrice * quantity;
        return _TicketBreakdownItem(
          ticketTypeId: detail.ticketTypeId,
          quantity: quantity,
          unitPrice: detail.unitPrice,
          totalPrice: totalPrice,
        );
      }).toList();
    }

    final grouped = <int, int>{};
    for (final ticket in order.tickets) {
      grouped[ticket.ticketTypeId] = (grouped[ticket.ticketTypeId] ?? 0) + 1;
    }

    return grouped.entries
        .where((entry) => entry.key > 0 && entry.value > 0)
        .map(
          (entry) => _TicketBreakdownItem(
            ticketTypeId: entry.key,
            quantity: entry.value,
            unitPrice: 0,
            totalPrice: 0,
          ),
        )
        .toList();
  }

  String _ticketTypeName(int ticketTypeId) {
    final name = ticketTypeNames[ticketTypeId]?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Loại vé #$ticketTypeId';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceGrouped,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              size: 17,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, bottom: 8),
                  child: Text(
                    'Chi tiết vé',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                ...items.map(
                  (item) => _TicketBreakdownRow(
                    name: _ticketTypeName(item.ticketTypeId),
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    totalPrice: item.totalPrice,
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

class _TicketBreakdownItem {
  const _TicketBreakdownItem({
    required this.ticketTypeId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final int ticketTypeId;
  final int quantity;
  final int unitPrice;
  final int totalPrice;
}

class _TicketBreakdownRow extends StatelessWidget {
  const _TicketBreakdownRow({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final int totalPrice;

  @override
  Widget build(BuildContext context) {
    final hasPrice = unitPrice > 0 || totalPrice > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPrice
                      ? '$quantity vé x ${CurrencyFormatter.format(unitPrice)}'
                      : '$quantity vé',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 124,
            child: Text(
              hasPrice ? CurrencyFormatter.format(totalPrice) : '',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isAmount = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isAmount;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.separator),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceGrouped,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: isAmount ? 124 : 88,
                maxWidth: MediaQuery.sizeOf(context).width * 0.46,
              ),
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: isAmount ? 1 : 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingOrderNotice extends StatelessWidget {
  const _PendingOrderNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Giao dịch chưa hoàn tất. Đơn này không thể thanh toán lại; '
              'hệ thống sẽ tự hủy nếu cổng thanh toán không xác nhận thành công.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostPaymentActions extends StatelessWidget {
  const _PostPaymentActions({
    required this.completed,
    required this.showCancellation,
    required this.onCancellation,
    required this.onReview,
  });

  final bool completed;
  final bool showCancellation;
  final VoidCallback onCancellation;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            completed ? 'Chuyến đi đã hoàn thành' : 'Quản lý chuyến đi',
            style: AppTextStyles.textTheme.titleSmall,
          ),
          const SizedBox(height: 5),
          Text(
            completed
                ? 'Cảm nhận của bạn giúp cộng đồng chọn tour tốt hơn.'
                : 'Vé QR đã sẵn sàng. Bạn có thể quản lý yêu cầu tại đây.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          CustomButton(
            label: 'Viết đánh giá',
            onPressed: onReview,
          ),
          if (showCancellation) ...[
            const SizedBox(height: 10),
            CustomButton(
              label: 'Yêu cầu hủy tour',
              outlined: true,
              onPressed: onCancellation,
            ),
          ],
        ],
      ),
    );
  }
}

class _InactiveOrderNotice extends StatelessWidget {
  const _InactiveOrderNotice({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final requested = status == 'Request to Cancelled';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: requested ? const Color(0xFFFFF7ED) : const Color(0xFFFEE2E2),
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          Icon(
            requested ? Icons.pending_actions_rounded : Icons.cancel_outlined,
            color: requested ? const Color(0xFFC2410C) : AppColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              requested
                  ? 'Yêu cầu hủy đang được xử lý. StayHub sẽ cập nhật khi có kết quả.'
                  : 'Đơn đặt tour này đã được hủy và không còn hiệu lực.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.navy,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusStyle {
  const _OrderStatusStyle({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  factory _OrderStatusStyle.from(String? status) {
    switch (status) {
      case 'Pending':
        return const _OrderStatusStyle(
          label: 'Chờ thanh toán',
          icon: Icons.schedule_rounded,
          foreground: AppColors.accent,
          background: AppColors.accentLight,
        );
      case 'Paid':
        return const _OrderStatusStyle(
          label: 'Đã thanh toán',
          icon: Icons.verified_rounded,
          foreground: AppColors.brand,
          background: AppColors.brandLight,
        );
      case 'Completed':
        return const _OrderStatusStyle(
          label: 'Hoàn thành',
          icon: Icons.task_alt_rounded,
          foreground: Color(0xFF15803D),
          background: Color(0xFFE8F8EF),
        );
      case 'Cancelled':
        return const _OrderStatusStyle(
          label: 'Đã hủy',
          icon: Icons.cancel_rounded,
          foreground: AppColors.error,
          background: Color(0xFFFEE2E2),
        );
      case 'Request to Cancelled':
        return const _OrderStatusStyle(
          label: 'Yêu cầu hủy',
          icon: Icons.pending_actions_rounded,
          foreground: Color(0xFFC2410C),
          background: Color(0xFFFFF7ED),
        );
      default:
        return _OrderStatusStyle(
          label: status ?? 'Không xác định',
          icon: Icons.info_outline_rounded,
          foreground: AppColors.textSecondary,
          background: AppColors.surfaceGrouped,
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.style});

  final _OrderStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: style.foreground),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              color: style.foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandLight,
      child: const Icon(
        Icons.landscape_rounded,
        size: 54,
        color: AppColors.brand,
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.event_busy_rounded, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          'Chưa có thông tin lịch khởi hành',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _OrderNotFound extends StatelessWidget {
  const _OrderNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.brandLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 34,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Không tìm thấy đơn',
              style: AppTextStyles.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Đơn có thể đã bị xóa hoặc bạn không có quyền truy cập.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
