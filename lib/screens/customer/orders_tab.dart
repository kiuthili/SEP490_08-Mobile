import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/feature_controllers.dart';
import '../../models/order_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/shell_layout.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab>
    with SingleTickerProviderStateMixin {
  final OrderController controller = Get.find<OrderController>();

  static Map<String, String> get _filters => {
        '': 'pt_all'.tr,
        'Paid': 'pt_paid'.tr,
        'Cancelled': 'pt_cancelled'.tr,
        'Request to cancel': 'pt_cancel_req'.tr,
      };

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);

    final initialStatus = Get.arguments as String?;
    if (initialStatus != null && _filters.containsKey(initialStatus)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setStatusFilter(initialStatus);
      });
      _tabController.index = _filters.keys.toList().indexOf(initialStatus);
    } else {
      if (!_filters.containsKey(controller.statusFilter.value)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.setStatusFilter(_filters.keys.first);
        });
      } else {
        _tabController.index =
            _filters.keys.toList().indexOf(controller.statusFilter.value!);
      }
    }

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final status = _filters.keys.elementAt(_tabController.index);
        if (controller.statusFilter.value != status) {
          controller.setStatusFilter(status);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.orders.isEmpty && !controller.isLoading.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.orders.isEmpty && !controller.isLoading.value) {
          controller.fetchOrders(refresh: true);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceGrouped,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        scrolledUnderElevation: 0,
        title: Text('ot_tour_orders'.tr),
        actions: [
          IconButton(
            tooltip: 'ot_refresh'.tr,
            onPressed: () => controller.fetchOrders(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.textPrimary,
          indicatorWeight: 2,
          dividerColor: AppColors.separator,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: _filters.values.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.fetchOrders(refresh: true),
                child: _buildOrderList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(BuildContext context) {
    if (controller.isLoading.value && controller.orders.isEmpty) {
      return LoadingWidget(message: 'ot_loading_orders'.tr);
    }

    if (controller.orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 80),
        children: [
          EmptyStateWidget(
            title: controller.statusFilter.value == null
                ? 'ot_no_orders'.tr
                : 'ot_no_matching_orders'.tr,
            subtitle: controller.statusFilter.value == null
                ? 'ot_orders_appear_here'.tr
                : 'ot_try_other_status'.tr,
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 160 &&
            controller.canLoadMoreOrders &&
            !controller.isLoading.value) {
          controller.loadMoreOrders();
        }
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          ShellLayout.bottomInset(context),
        ),
        itemCount:
            controller.orders.length + (controller.canLoadMoreOrders ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= controller.orders.length) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _OrderCard(
            order: controller.orders[index],
            onTap: () => Get.toNamed(
              AppRoutes.orderDetail,
              arguments: controller.orders[index].id,
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderModel order;
  final VoidCallback onTap;

  int get _quantity =>
      order.totalQuantity > 0 ? order.totalQuantity : order.ticketCount;

  @override
  Widget build(BuildContext context) {
    final status = _OrderStatusStyle.from(order.status);
    final departure = order.schedule?.departureDate;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: order.tour?.imageUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: order.tour!.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.brandLight),
                          errorWidget: (_, __, ___) =>
                              const _OrderImagePlaceholder(),
                        )
                      : const _OrderImagePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            order.tour?.name ?? 'ot_order_id'.trParams({'id': order.id.toString()}),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${departure == null ? 'ot_no_schedule'.tr : DateFormatter.display(departure)} • ${'ot_tickets_count'.trParams({'count': _quantity.toString()})}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(order.finalAmount),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        _StatusBadge(style: status),
                      ],
                    ),
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

class _OrderImagePlaceholder extends StatelessWidget {
  const _OrderImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandLight,
      child: const Icon(
        Icons.landscape_rounded,
        size: 46,
        color: AppColors.brand,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.style});

  final _OrderStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.foreground),
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

