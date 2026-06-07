import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/feature_controllers.dart';
import '../../models/order_model.dart';
import '../../routes/app_routes.dart';
import '../../services/payment_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_widget.dart';
import 'my_tickets_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _controller = Get.find<OrderController>();
  PaymentProvider _payProvider = PaymentProvider.vnpay;

  @override
  void initState() {
    super.initState();
    final id = Get.arguments as int?;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.selectedOrder.value?.id != id) {
          _controller.selectedOrder.value = null;
        }
        _controller.fetchOrderDetail(id);
      });
    }
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
                  onPressed: () => _controller.fetchOrderDetail(order.id),
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
      onRefresh: () => _controller.fetchOrderDetail(order.id),
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
            const SizedBox(height: 20),
            const _SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: 'Thông tin đơn',
              subtitle: 'Chi tiết thanh toán và ưu đãi',
            ),
            const SizedBox(height: 10),
            _OrderInformationCard(order: order),
            if (order.status == 'Pending') ...[
              const SizedBox(height: 20),
              const _SectionTitle(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Hoàn tất thanh toán',
                subtitle: 'Chọn phương thức phù hợp để xác nhận chỗ',
              ),
              const SizedBox(height: 10),
              _PendingPaymentPanel(
                order: order,
                provider: _payProvider,
                onProviderChanged: (provider) {
                  setState(() => _payProvider = provider);
                },
                onDemoPayment: () => _openDemoPayment(order),
                onGatewayPayment: () => _openGatewayPayment(order),
                onCancel: () => _cancelOrder(order),
              ),
            ],
            if (order.status == 'Paid' || order.status == 'Completed') ...[
              const SizedBox(height: 20),
              OrderTicketsPanel(orderId: order.id),
              const SizedBox(height: 16),
              _PostPaymentActions(
                completed: order.status == 'Completed',
                onCancellation: () => _openCancellationRequest(order.id),
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

  Future<void> _openDemoPayment(OrderModel order) async {
    final ok = await Get.toNamed(
      AppRoutes.bankPaymentDemo,
      arguments: {
        'orderId': order.id,
        'amount': order.finalAmount,
      },
    );
    if (ok == true && mounted) {
      await _controller.fetchOrderDetail(order.id);
    }
  }

  Future<void> _openGatewayPayment(OrderModel order) async {
    final ok = await Get.toNamed(
      AppRoutes.payment,
      arguments: {
        'orderId': order.id,
        'amount': order.finalAmount,
        'provider': _payProvider == PaymentProvider.momo ? 'momo' : 'vnpay',
      },
    );
    if (ok == true && mounted) {
      await _controller.fetchOrderDetail(order.id);
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    await _controller.cancelOrder(order.id);
    if (mounted) {
      await _controller.fetchOrderDetail(order.id);
    }
  }

  Future<void> _openCancellationRequest(int orderId) async {
    final ok = await Get.toNamed<bool>(
      AppRoutes.requestCancellation,
      arguments: orderId,
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
  const _OrderInformationCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
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
          _DetailRow(
            icon: Icons.payments_outlined,
            label: 'Tạm tính',
            value: CurrencyFormatter.format(order.totalAmount),
          ),
          if ((order.discountValue ?? 0) > 0)
            _DetailRow(
              icon: Icons.local_offer_outlined,
              label: 'Ưu đãi',
              value: '-${CurrencyFormatter.format(order.discountValue!)}',
              valueColor: AppColors.success,
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
            isLast: order.note?.isNotEmpty != true,
          ),
          if (order.note?.isNotEmpty == true)
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
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
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                value,
                textAlign: TextAlign.right,
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

class _PendingPaymentPanel extends StatelessWidget {
  const _PendingPaymentPanel({
    required this.order,
    required this.provider,
    required this.onProviderChanged,
    required this.onDemoPayment,
    required this.onGatewayPayment,
    required this.onCancel,
  });

  final OrderModel order;
  final PaymentProvider provider;
  final ValueChanged<PaymentProvider> onProviderChanged;
  final VoidCallback onDemoPayment;
  final VoidCallback onGatewayPayment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.brandLight,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Ngân hàng nội địa',
                                style: AppTextStyles.textTheme.titleSmall,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const _DemoBadge(),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Mô phỏng thanh toán và xác thực OTP',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CustomButton(
                label: 'Thanh toán ngân hàng demo',
                onPressed: onDemoPayment,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
                'Cổng thanh toán thật',
                style: AppTextStyles.textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              SegmentedButton<PaymentProvider>(
                segments: const [
                  ButtonSegment(
                    value: PaymentProvider.vnpay,
                    icon: Icon(Icons.credit_card_rounded),
                    label: Text('VNPay'),
                  ),
                  ButtonSegment(
                    value: PaymentProvider.momo,
                    icon: Icon(Icons.account_balance_wallet_rounded),
                    label: Text('MoMo'),
                  ),
                ],
                selected: {provider},
                onSelectionChanged: (values) {
                  onProviderChanged(values.first);
                },
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: 'Mở cổng thanh toán',
                outlined: true,
                onPressed: onGatewayPayment,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Hủy đơn đặt tour'),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
        ),
      ],
    );
  }
}

class _PostPaymentActions extends StatelessWidget {
  const _PostPaymentActions({
    required this.completed,
    required this.onCancellation,
    required this.onReview,
  });

  final bool completed;
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
          const SizedBox(height: 10),
          CustomButton(
            label: 'Yêu cầu hủy tour',
            outlined: true,
            onPressed: onCancellation,
          ),
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

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'DEMO',
        style: TextStyle(
          color: AppColors.accent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
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
