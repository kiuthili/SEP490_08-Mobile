import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:stayhub_mobile/controllers/review_controller.dart';
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
    return status == 'paid' || status == 'completed';
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
        title: order == null
            ? 'od_order_detail'.tr
            : 'od_order_id'.trParams({'id': order.id.toString()}),
        actions: order == null
            ? null
            : [
                IconButton(
                  tooltip: 'ot_refresh'.tr,
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
      return LoadingWidget(message: 'od_loading_detail'.tr);
    }
    if (order == null) {
      return const _OrderNotFound();
    }

    return DefaultTabController(
      length: 3,
      child: RefreshIndicator(
        onRefresh: () => _refreshOrder(order.id),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _OrderHero(order: order),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    labelColor: AppColors.brand,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.brand,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(fontWeight: FontWeight.w700),
                    unselectedLabelStyle:
                        TextStyle(fontWeight: FontWeight.w500),
                    tabs: [
                      Tab(text: 'od_info_tab'.tr),
                      Tab(text: 'od_itinerary_tab'.tr),
                      Tab(text: 'od_ticket_tab'.tr),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              // Tab 1: Thông tin đơn
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OrderInformationCard(
                      order: order,
                      ticketTypeNames: _ticketTypeNames,
                    ),
                    if (order.status == 'Pending') ...[
                      const SizedBox(height: 20),
                      const _PendingOrderNotice(),
                    ],
                    if (order.status == 'Paid' ||
                        order.status == 'Completed') ...[
                      const SizedBox(height: 16),
                      _PostPaymentActions(
                        completed: order.status == 'Completed',
                        showCancellation: _canRequestCancellation(order),
                        onCancellation: () => _openCancellationRequest(order),
                        onReview: () => _showReviewDialog(order),
                      ),
                    ],
                    if (order.status == 'Cancelled' ||
                        order.status == 'Request to cancel') ...[
                      const SizedBox(height: 20),
                      _InactiveOrderNotice(status: order.status),
                    ],
                  ],
                ),
              ),

              // Tab 2: Lịch trình
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TripTimeline(order: order),
                    if (_shouldLoadItineraries(order)) ...[
                      const SizedBox(height: 20),
                      _ScheduleItineraryPanel(
                        itineraries: _itineraries,
                        tourismInformation: _tourismInformation,
                        loading: _loadingItineraries,
                        error: _itineraryError,
                        onRetry: () => _loadItineraries(order, force: true),
                      ),
                    ],
                  ],
                ),
              ),

              // Tab 3: Vé
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OrderTicketsPanel(
                      tickets: order.tickets,
                      ticketTypeNames: _ticketTypeNames,
                    )
                  ],
                ),
              ),
            ],
          ),
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
      SnackbarHelper.error('od_only_paid_cancel'.tr);
      return;
    }

    final daysUntilDeparture =
        _daysUntilDeparture(order.schedule?.departureDate);
    final feePercent = _cancellationFeePercent(daysUntilDeparture);
    if (feePercent == null || daysUntilDeparture == null) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'od_cannot_cancel'.tr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'od_cancel_policy_error'.tr,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.button),
                  ),
                  child: Text('od_understood'.tr),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final feeBase =
        order.totalAmount > 0 ? order.totalAmount : order.finalAmount;
    final cancellationFee = (feeBase * feePercent / 100).round();
    final estimatedRefund =
        (order.finalAmount - cancellationFee).clamp(0, 1 << 31);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'od_confirm_cancel_policy'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'od_days_until_departure'
                    .trParams({'days': daysUntilDeparture.toString()}),
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'od_cancel_fee'.trParams({
                  'percent': feePercent.toString(),
                  'amount': CurrencyFormatter.format(cancellationFee),
                }),
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'od_estimated_refund'.trParams(
                    {'amount': CurrencyFormatter.format(estimatedRefund)}),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.button),
                      ),
                      child: Text('od_later'.tr),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.button),
                      ),
                      child: Text('od_continue'.tr),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final orderId = order.id;
    final ok = await Get.toNamed(
      AppRoutes.requestCancellationFor(orderId),
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
        title: Text('od_review_trip'.tr),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'od_how_was_experience'.tr,
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
                decoration: InputDecoration(
                  hintText: 'od_share_feelings'.tr,
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
            child: Text('od_later'.tr),
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
            label: Text('od_submit_review'.tr),
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
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'od_order_code'.trParams({'id': order.id.toString()}),
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
                  order.tour?.name ?? 'od_your_trip'.tr,
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
                    label: 'od_departure'.tr,
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
                        'od_duration_days'.trParams({
                          'days': (schedule.returnDate
                                      .difference(schedule.departureDate)
                                      .inDays +
                                  1)
                              .toString()
                        }),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _TimelineDate(
                    label: 'od_end'.tr,
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
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<TourScheduleItineraryModel> itineraries;
  final Map<int, TourismInformationModel> tourismInformation;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceGrouped,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.map_outlined,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'td_detailed_itinerary'.tr,
                        style: AppTextStyles.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'od_days_activities'.trParams({
                          'd': days.length.toString(),
                          'a': itineraries.length.toString()
                        }),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < days.length; index++)
            _ItineraryDayCard(
              day: days[index],
              activities: grouped[days[index]]!,
              tourismInformation: tourismInformation,
              isLast: index == days.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ItineraryDayCard extends StatefulWidget {
  const _ItineraryDayCard({
    required this.day,
    required this.activities,
    required this.tourismInformation,
    required this.isLast,
  });

  final int day;
  final List<TourScheduleItineraryModel> activities;
  final Map<int, TourismInformationModel> tourismInformation;
  final bool isLast;

  @override
  State<_ItineraryDayCard> createState() => _ItineraryDayCardState();
}

class _ItineraryDayCardState extends State<_ItineraryDayCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    final date = widget.activities
        .map((item) => item.itineraryDate)
        .whereType<DateTime>()
        .firstOrNull;
    _expanded = _isToday(date);
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.activities
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
          bottom: widget.isLast
              ? BorderSide.none
              : const BorderSide(color: AppColors.separator),
        ),
      ),
      child: Column(
        children: [
          Material(
            color: isToday
                ? AppColors.brandLight
                : _expanded
                    ? AppColors.brandLight.withValues(alpha: 0.6)
                    : Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                        '${widget.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
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
                                'td_day_index'
                                    .trParams({'day': widget.day.toString()}),
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
                                    borderRadius: AppRadius.button,
                                  ),
                                  child: Text(
                                    'od_today'.tr,
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
                                ? 'td_activities_count'.trParams({
                                    'count': widget.activities.length.toString()
                                  })
                                : 'od_date_activities'.trParams({
                                    'date': DateFormatter.display(date),
                                    'a': widget.activities.length.toString()
                                  }),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
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
                  for (var index = 0; index < widget.activities.length; index++)
                    _ScheduleActivity(
                      itinerary: widget.activities[index],
                      tourismInformation:
                          widget.activities[index].tourismInfoId == null
                              ? null
                              : widget.tourismInformation[
                                  widget.activities[index].tourismInfoId],
                      isLast: index == widget.activities.length - 1,
                    ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
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
            : 'td_daily_activities'.tr;
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
                                  : 'td_heritage_sites'.tr,
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
                                          : 'td_heritage_sites'.tr,
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
                                      : 'td_references'.tr,
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
        SnackBar(content: Text('td_cannot_open_link'.tr)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSource(context),
        borderRadius: AppRadius.button,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.brandLight.withValues(alpha: 0.72),
            borderRadius: AppRadius.button,
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
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('od_loading_itinerary'.tr),
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
          SizedBox(width: 10),
          Expanded(child: Text('od_cannot_load_itinerary'.tr)),
          TextButton(onPressed: onRetry, child: Text('od_retry'.tr)),
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
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text('od_itinerary_updating'.tr),
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

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.separator),
              ),
            );
          }),
        );
      },
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
    final status = _OrderStatusStyle.from(order.status);
    final hasNote = order.note?.isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 32,
                  color: AppColors.brand,
                ),
                const SizedBox(height: 8),
                Text(
                  'od_tour_invoice'.tr,
                  style: AppTextStyles.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${order.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _StatusPill(style: status),
                const SizedBox(height: 12),
                Text(
                  DateFormatter.display(order.orderedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _DashedDivider(),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _TicketBreakdownSection(
              order: order,
              ticketTypeNames: ticketTypeNames,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _DashedDivider(),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _DetailRow(
                  label: 'od_subtotal'.tr,
                  value: CurrencyFormatter.format(order.totalAmount),
                ),
                if ((order.discountValue ?? 0) > 0)
                  _DetailRow(
                    label: 'od_discount'.tr,
                    value: '-${CurrencyFormatter.format(order.discountValue!)}',
                    valueColor: AppColors.success,
                  ),
                if ((order.promotionDiscountValue ?? 0) > 0)
                  _DetailRow(
                    label: 'od_promotion'.tr,
                    value:
                        '-${CurrencyFormatter.format(order.promotionDiscountValue!)}',
                    valueColor: AppColors.success,
                  ),
                if (order.voucherCode?.isNotEmpty == true)
                  _DetailRow(
                    label: 'Voucher',
                    value: order.voucherCode!,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'od_total_amount'.tr,
                      style: AppTextStyles.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(order.finalAmount),
                      style: AppTextStyles.textTheme.titleMedium?.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasNote) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _DashedDivider(),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'od_note'.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.note!,
                    style: Theme.of(context).textTheme.bodyMedium,
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
          promotionDiscountValue: detail.promotionDiscountValue,
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
            promotionDiscountValue: null,
          ),
        )
        .toList();
  }

  String _ticketTypeName(int ticketTypeId) {
    final name = ticketTypeNames[ticketTypeId]?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'od_ticket_type'.trParams({'id': ticketTypeId.toString()});
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'od_ticket_details'.tr,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => _TicketBreakdownRow(
            name: _ticketTypeName(item.ticketTypeId),
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
            promotionDiscountValue: item.promotionDiscountValue,
          ),
        ),
      ],
    );
  }
}

class _TicketBreakdownItem {
  const _TicketBreakdownItem({
    required this.ticketTypeId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.promotionDiscountValue,
  });

  final int ticketTypeId;
  final int quantity;
  final int unitPrice;
  final int totalPrice;
  final int? promotionDiscountValue;
}

class _TicketBreakdownRow extends StatelessWidget {
  const _TicketBreakdownRow({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.promotionDiscountValue,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final int totalPrice;
  final int? promotionDiscountValue;

  @override
  Widget build(BuildContext context) {
    final hasPrice = unitPrice > 0 || totalPrice > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPrice
                      ? '$quantity x ${CurrencyFormatter.format(unitPrice)}'
                      : 'ot_tickets_count'
                          .trParams({'count': quantity.toString()}),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasPrice ? CurrencyFormatter.format(totalPrice) : '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              if ((promotionDiscountValue ?? 0) > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '-${CurrencyFormatter.format(promotionDiscountValue!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
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
              'od_unpaid_notice'.tr,
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
            completed ? 'od_trip_completed'.tr : 'od_manage_trip'.tr,
            style: AppTextStyles.textTheme.titleSmall,
          ),
          const SizedBox(height: 5),
          Text(
            completed ? 'od_review_prompt'.tr : 'od_qr_ready'.tr,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
            onPressed: onReview,
            child: Text(
              'td_write_review'.tr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          if (showCancellation) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                side: const BorderSide(color: AppColors.brand),
              ),
              onPressed: onCancellation,
              child: Text(
                'od_request_cancel_tour'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                ),
              ),
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
    final requested = status == 'Request to cancel';
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
              requested ? 'od_cancel_processing'.tr : 'od_order_cancelled'.tr,
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
        return _OrderStatusStyle(
          label: 'od_status_pending'.tr,
          icon: Icons.schedule_rounded,
          foreground: AppColors.accent,
          background: AppColors.accentLight,
        );
      case 'Paid':
        return _OrderStatusStyle(
          label: 'pt_paid'.tr,
          icon: Icons.verified_rounded,
          foreground: AppColors.brand,
          background: AppColors.brandLight,
        );
      case 'Completed':
        return _OrderStatusStyle(
          label: 'od_status_completed'.tr,
          icon: Icons.task_alt_rounded,
          foreground: Color(0xFF15803D),
          background: Color(0xFFE8F8EF),
        );
      case 'Cancelled':
        return _OrderStatusStyle(
          label: 'pt_cancelled'.tr,
          icon: Icons.cancel_rounded,
          foreground: AppColors.error,
          background: Color(0xFFFEE2E2),
        );
      case 'Request to cancel':
        return _OrderStatusStyle(
          label: 'pt_cancel_req'.tr,
          icon: Icons.pending_actions_rounded,
          foreground: Color(0xFFC2410C),
          background: Color(0xFFFFF7ED),
        );
      default:
        return _OrderStatusStyle(
          label: status ?? 'od_status_unknown'.tr,
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
          'od_no_departure_info'.tr,
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
              'od_order_not_found'.tr,
              style: AppTextStyles.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'od_order_deleted_or_no_access'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

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
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
