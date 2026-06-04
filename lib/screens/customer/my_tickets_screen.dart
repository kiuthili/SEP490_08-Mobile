import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final _service = Get.find<OrderService>();
  var _loading = true;
  List<TicketModel> _tickets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _tickets = await _service.getMyTickets();
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Vé của tôi',
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingWidget()
            : _tickets.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyStateWidget(
                        title: 'Chưa có vé',
                        subtitle: 'Đặt tour và thanh toán để nhận vé QR',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: _tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = _tickets[index];
                      return IosSurfaceCard(
                        margin: EdgeInsets.zero,
                        padding: EdgeInsets.zero,
                        child: ExpansionTile(
                          leading: const Icon(Icons.confirmation_number),
                          title: Text(t.attendeeName),
                          subtitle: Text(
                            '${t.checkInStatus ?? 'Chưa check-in'} • CMND: ${t.idCard}',
                          ),
                          children: [
                            if (t.qrCode != null && t.qrCode!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: QrImageView(
                                  data: t.qrCode!,
                                  size: 200,
                                  backgroundColor: Colors.white,
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('QR chưa được cấp'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// Vé theo một đơn hàng (dùng trong order detail).
class OrderTicketsPanel extends StatefulWidget {
  const OrderTicketsPanel({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderTicketsPanel> createState() => _OrderTicketsPanelState();
}

class _OrderTicketsPanelState extends State<OrderTicketsPanel> {
  final _service = Get.find<OrderService>();
  var _loading = true;
  List<TicketModel> _tickets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _tickets = await _service.getTicketsForOrder(widget.orderId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_tickets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vé & QR check-in',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._tickets.map((t) {
          return IosSurfaceCard(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
                children: [
                  Text(t.attendeeName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(t.idCard, style: Theme.of(context).textTheme.bodySmall),
                  if (t.qrCode != null && t.qrCode!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    QrImageView(
                      data: t.qrCode!,
                      size: 160,
                      backgroundColor: Colors.white,
                    ),
                  ],
                  Text(
                    t.checkInStatus ?? 'Chưa check-in',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
            ),
          );
        }),
      ],
    );
  }
}
