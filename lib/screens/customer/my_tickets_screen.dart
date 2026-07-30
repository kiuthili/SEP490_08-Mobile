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
      Get.snackbar('mt_error'.tr, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'mt_my_tickets'.tr,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingWidget()
            : _tickets.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: 80),
                      EmptyStateWidget(
                        title: 'mt_no_tickets'.tr,
                        subtitle: 'mt_book_to_get_qr'.tr,
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
                            '${t.checkInStatus ?? 'mt_not_checked_in'.tr} • CMND: ${t.idCard}',
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
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('mt_qr_not_issued'.tr),
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
  final List<TicketModel> tickets;
  final Map<int, String> ticketTypeNames;

  const OrderTicketsPanel({
    super.key,
    required this.tickets,
    required this.ticketTypeNames,
  });

  String _getTranslatedStatus(String? status) {
    if (status == null || status.isEmpty) return 'mt_not_checked_in'.tr;
    final s = status.toLowerCase();
    if (s == 'pending') return 'tk_pending'.tr;
    if (s == 'checkedin') return 'tk_checkedin'.tr;
    if (s == 'cancelled') return 'pt_cancelled'.tr;
    return status;
  }

  String _ticketTypeName(int ticketTypeId) {
    final name = ticketTypeNames[ticketTypeId]?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'od_ticket_type'.trParams({'id': ticketTypeId.toString()});
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
                    'mt_tickets_qr_checkin'.tr,
                    style: AppTextStyles.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'mt_tickets_ready'
                        .trParams({'count': tickets.length.toString()}),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...tickets.map((t) {
          final statusStr = t.checkInStatus?.toLowerCase() ?? '';
          Color statusColor = AppColors.textSecondary;
          if (statusStr.contains('checked') ||
              statusStr.contains('mt_already'.tr)) {
            statusColor = AppColors.success;
          } else if (statusStr.contains('pending') ||
              statusStr.contains('mt_wait'.tr)) {
            statusColor = Colors.orange;
          } else if (statusStr.contains('cancel') ||
              statusStr.contains('pt_cancelled'.tr)) {
            statusColor = AppColors.error;
          }

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
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          _getTranslatedStatus(t.checkInStatus),
                          style: TextStyle(
                            color: statusColor,
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
                              'mt_show_code_to_staff'.tr,
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
                                Clipboard.setData(
                                    ClipboardData(text: t.qrCode!));
                                SnackbarHelper.success('mt_qr_copied'.tr);
                              },
                              icon:
                                  const Icon(Icons.copy_all_rounded, size: 16),
                              label: Text('mt_copy_code'.tr),
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
                          'mt_qr_generating'.tr,
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
