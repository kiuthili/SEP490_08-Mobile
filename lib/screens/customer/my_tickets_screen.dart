import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_screen.dart';
import '../../utils/snackbar_helper.dart';
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
class OrderTicketsPanel extends StatelessWidget {
  const OrderTicketsPanel({
    super.key,
    required this.tickets,
    this.ticketTypeNames = const {},
  });

  final List<TicketModel> tickets;
  final Map<int, String> ticketTypeNames;

  String _ticketTypeName(int ticketTypeId) {
    final name = ticketTypeNames[ticketTypeId]?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Loại vé #$ticketTypeId';
  }

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                size: 22,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vé & QR check-in',
                    style: AppTextStyles.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tickets.length} vé điện tử sẵn sàng sử dụng',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...tickets.map((t) {
          final checkedIn =
              t.checkInStatus?.toLowerCase().contains('checked') == true ||
                  t.checkInStatus?.toLowerCase().contains('đã') == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  color: AppColors.brandLight.withValues(alpha: 0.58),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.attendeeName,
                              style: AppTextStyles.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'CCCD ${t.idCard} - ${_ticketTypeName(t.ticketTypeId)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: checkedIn
                              ? AppColors.success.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.checkInStatus ?? 'Chưa check-in',
                          style: TextStyle(
                            color: checkedIn
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (t.qrCode != null && t.qrCode!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.separator),
                          ),
                          child: QrImageView(
                            data: t.qrCode!,
                            size: 154,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGrouped,
                            borderRadius: AppRadius.input,
                            border: Border.all(color: AppColors.separator),
                          ),
                          child: SelectableText(
                            t.qrCode!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Đưa mã này cho nhân viên khi check-in',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: t.qrCode!));
                                SnackbarHelper.success('Đã sao chép mã QR');
                              },
                              icon: const Icon(Icons.copy_all_rounded, size: 16),
                              label: const Text('Sao chép mã'),
                            )
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'QR đang được hệ thống khởi tạo',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
