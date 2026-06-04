import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../services/payment_service.dart';
import '../customer/my_tickets_screen.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

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
    // Hoãn ra sau frame: tránh mutate Rx (isLoading) trong lúc build → tránh
    // lỗi "setState() called during build" do Obx tab Đơn hàng đang nghe chung.
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.fetchOrderDetail(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Chi tiết đặt tour',
      body: Obx(() {
        if (_controller.isLoading.value &&
            _controller.selectedOrder.value == null) {
          return const LoadingWidget();
        }
        final order = _controller.selectedOrder.value;
        if (order == null) {
          return const Center(child: Text('Không tìm thấy đơn'));
        }
        return RefreshIndicator(
          onRefresh: () => _controller.fetchOrderDetail(order.id),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (order.tour?.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(
                      order.tour!.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  order.tour?.name ?? 'Tour',
                  style: AppTextStyles.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                _StatusChip(status: order.status),
                const SizedBox(height: 16),
                IosGroupedSection(
                  header: 'Thông tin đơn',
                  margin: EdgeInsets.zero,
                  children: [
                    _InfoRow('Mã đơn', '#${order.id}'),
                    _InfoRow(
                      'Ngày đặt',
                      DateFormatter.formatDate(order.orderedAt),
                    ),
                    _InfoRow(
                      'Tổng tiền',
                      CurrencyFormatter.format(order.finalAmount),
                    ),
                    if (order.discountValue != null && order.discountValue! > 0)
                      _InfoRow(
                        'Giảm giá',
                        CurrencyFormatter.format(order.discountValue!),
                      ),
                    if (order.voucherCode != null)
                      _InfoRow('Voucher', order.voucherCode!),
                    if (order.schedule != null)
                      _InfoRow(
                        'Khởi hành',
                        order.schedule!.departureDate
                            .toString()
                            .substring(0, 10),
                      ),
                  ],
                ),
                if (order.status == 'Pending') ...[
                  const SizedBox(height: 16),
                  Text('Phương thức thanh toán',
                      style: Theme.of(context).textTheme.titleSmall),
                  SegmentedButton<PaymentProvider>(
                    segments: const [
                      ButtonSegment(
                        value: PaymentProvider.vnpay,
                        label: Text('VNPay'),
                      ),
                      ButtonSegment(
                        value: PaymentProvider.momo,
                        label: Text('MoMo'),
                      ),
                    ],
                    selected: {_payProvider},
                    onSelectionChanged: (s) =>
                        setState(() => _payProvider = s.first),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Thanh toán ngay',
                    onPressed: () async {
                      final ok = await Get.toNamed(
                        AppRoutes.payment,
                        arguments: {
                          'orderId': order.id,
                          'amount': order.finalAmount,
                          'provider': _payProvider == PaymentProvider.momo
                              ? 'momo'
                              : 'vnpay',
                        },
                      );
                      if (ok == true) {
                        await _controller.fetchOrderDetail(order.id);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  CustomButton(
                    label: 'Hủy đơn',
                    outlined: true,
                    onPressed: () async {
                      await _controller.cancelOrder(order.id);
                      await _controller.fetchOrderDetail(order.id);
                    },
                  ),
                ],
                if (order.status == 'Paid' ||
                    order.status == 'Completed') ...[
                  OrderTicketsPanel(orderId: order.id),
                  const SizedBox(height: 16),
                  CustomButton(
                    label: 'Yêu cầu hủy tour',
                    outlined: true,
                    onPressed: () => _openCancellationRequest(order.id),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Viết đánh giá',
                    onPressed: () => _showReviewDialog(order),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
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

  void _showReviewDialog(dynamic order) {
    final commentController = TextEditingController();
    var rating = 5;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đánh giá tour'),
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
              final reviewController = Get.find<ReviewController>();
              await reviewController.submitReview(
                tourId: order.tour?.id ?? 0,
                rating: rating,
                comment: commentController.text,
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

class _StatusChip extends StatelessWidget {
  final String? status;

  const _StatusChip({this.status});

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.brandLight;
    Color fg = AppColors.brand;
    String label = status ?? '—';
    switch (status) {
      case 'Pending':
        label = 'Chờ thanh toán';
        bg = AppColors.accentLight;
        fg = AppColors.accent;
        break;
      case 'Paid':
        label = 'Đã thanh toán';
        break;
      case 'Completed':
        label = 'Hoàn thành';
        bg = const Color(0xFFE8F8EF);
        fg = const Color(0xFF15803D);
        break;
      case 'Cancelled':
        label = 'Đã hủy';
        bg = const Color(0xFFFEE2E2);
        fg = AppColors.error;
        break;
      case 'Request to Cancelled':
        label = 'Yêu cầu hủy';
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFC2410C);
        break;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        label: Text(label),
        backgroundColor: bg,
        labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w600),
        side: BorderSide.none,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
