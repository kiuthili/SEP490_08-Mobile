import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/shell_layout.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class OrdersTab extends GetView<OrderController> {
  const OrdersTab({super.key});

  static const _filters = <String?, String>{
    null: 'Tất cả',
    'Pending': 'Chờ thanh toán',
    'Paid': 'Đã thanh toán',
    'Completed': 'Hoàn thành',
    'Cancelled': 'Đã hủy',
    'Request to Cancelled': 'Yêu cầu hủy',
  };

  @override
  Widget build(BuildContext context) {
    if (controller.orders.isEmpty && !controller.isLoading.value) {
      // Hoãn ra sau frame: không mutate Rx trong build (tránh crash Obx).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.orders.isEmpty && !controller.isLoading.value) {
          controller.fetchOrders(refresh: true);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Đặt tour của tôi')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _filters.entries.map((e) {
                final selected = controller.statusFilter.value == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => controller.setStatusFilter(e.key),
                    selectedColor: AppColors.brandLight,
                    checkmarkColor: AppColors.brand,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => controller.fetchOrders(refresh: true),
              child: Obx(() {
                if (controller.isLoading.value &&
                    controller.orders.isEmpty) {
                  return const LoadingWidget();
                }
                if (controller.orders.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyStateWidget(title: 'Chưa có đơn hàng'),
                    ],
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollEndNotification &&
                        n.metrics.extentAfter < 120 &&
                        controller.canLoadMoreOrders &&
                        !controller.isLoading.value) {
                      controller.loadMoreOrders();
                    }
                    return false;
                  },
                  child: ListView.separated(
                  padding: const EdgeInsets.all(16).copyWith(
                    bottom: ShellLayout.bottomInset(context),
                  ),
                  itemCount: controller.orders.length +
                      (controller.canLoadMoreOrders ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index >= controller.orders.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final order = controller.orders[index];
                    return IosSurfaceCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        onTap: () => Get.toNamed(
                          AppRoutes.orderDetail,
                          arguments: order.id,
                        ),
                        leading: order.tour?.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  order.tour!.imageUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.receipt_long_rounded),
                        title: Text(order.tour?.name ?? 'Đơn #${order.id}'),
                        subtitle: Text(
                          '${_statusLabel(order.status)} • ${DateFormatter.formatDate(order.orderedAt)}',
                        ),
                        trailing: Text(
                          CurrencyFormatter.format(order.finalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'Pending':
        return 'Chờ thanh toán';
      case 'Paid':
        return 'Đã thanh toán';
      case 'Completed':
        return 'Hoàn thành';
      case 'Cancelled':
        return 'Đã hủy';
      case 'Request to Cancelled':
        return 'Yêu cầu hủy';
      default:
        return status ?? '—';
    }
  }
}
