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

class _OrdersTabState extends State<OrdersTab> with SingleTickerProviderStateMixin {
  final OrderController controller = Get.find<OrderController>();

  static const _filters = <String, String>{
    '': 'Tất cả',
    'Pending': 'Chờ thanh toán',
    'Paid': 'Đã thanh toán',
    'Completed': 'Hoàn thành',
    'Cancelled': 'Đã hủy',
    'Request to Cancelled': 'Yêu cầu hủy',
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
        _tabController.index = _filters.keys.toList().indexOf(controller.statusFilter.value!);
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
      appBar: AppBar(
        title: const Text('Đơn đặt tour'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () => controller.fetchOrders(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.brand,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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
      return const LoadingWidget(message: 'Đang tải đơn đặt tour...');
    }

    if (controller.orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 80),
        children: [
          EmptyStateWidget(
            title: controller.statusFilter.value == null
                ? 'Chưa có đơn đặt tour'
                : 'Không có đơn phù hợp',
            subtitle: controller.statusFilter.value == null
                ? 'Những chuyến đi bạn đặt sẽ xuất hiện tại đây'
                : 'Thử chọn một trạng thái khác để xem thêm đơn',
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
          8,
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
    final departure = order.schedule?.departureDate;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.card,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                child: SizedBox(
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (order.tour?.imageUrl?.isNotEmpty == true)
                        CachedNetworkImage(
                          imageUrl: order.tour!.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.brandLight),
                          errorWidget: (_, __, ___) =>
                              const _OrderImagePlaceholder(),
                        )
                      else
                        const _OrderImagePlaceholder(),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Color(0xCC05073C)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.35, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _StatusBadge(style: status),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            '#${order.id}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Text(
                          order.tour?.name ?? 'Đơn đặt tour #${order.id}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(color: Color(0x88000000), blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _OrderMeta(
                            icon: Icons.calendar_month_rounded,
                            label: departure == null
                                ? 'Chưa có lịch'
                                : DateFormatter.display(departure),
                          ),
                        ),
                        Container(width: 1, height: 24, color: AppColors.separator),
                        Expanded(
                          child: _OrderMeta(
                            icon: Icons.confirmation_number_outlined,
                            label: '$_quantity vé',
                          ),
                        ),
                        if (_location.isNotEmpty) ...[
                          Container(width: 1, height: 24, color: AppColors.separator),
                          Expanded(
                            child: _OrderMeta(
                              icon: Icons.location_on_outlined,
                              label: _location,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 11),
                      child: Divider(height: 1),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tổng thanh toán',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.format(order.finalAmount),
                                style: AppTextStyles.textTheme.titleMedium
                                    ?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.brand, Color(0xFF1565C0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brand.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
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

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17, color: AppColors.brand),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.style});

  final _OrderStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
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
