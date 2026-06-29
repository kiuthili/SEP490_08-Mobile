import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stayhub_mobile/models/staff_ticket_model.dart';
import '../../models/check_in_result_model.dart';
import '../../routes/app_routes.dart';
import '../../utils/snackbar_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'package:flutter/services.dart';
import 'package:stayhub_mobile/controllers/staff_controller.dart';
import '../../widgets/ios_grouped.dart';

class StaffCheckInTab extends StatefulWidget {
  const StaffCheckInTab({super.key});

  @override
  State<StaffCheckInTab> createState() => _StaffCheckInTabState();
}

class _StaffCheckInTabState extends State<StaffCheckInTab> {
  final _qrController = TextEditingController();
  final _staff = Get.find<StaffController>();
  bool _isProcessing = false;

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  Future<void> _doCheckIn() async {
    final code = _qrController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final result = await _staff.checkIn(code);
      if (result != null && mounted) {
        _qrController.clear();
        _showResultDialog(result);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(CheckInResultModel result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon thành công
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.brand, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Check-in thành công!',
              style: AppTextStyles.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 20),

            // Thông tin vé
            _ResultRow(
              icon: Icons.person_rounded,
              label: 'Hành khách',
              value: result.attendeeName,
            ),
            _ResultRow(
              icon: Icons.local_activity_rounded,
              label: 'Loại vé',
              value: result.ticketTypeName,
            ),
            _ResultRow(
              icon: Icons.confirmation_number_rounded,
              label: 'Mã vé',
              value: '#${result.ticketId}',
            ),
            _ResultRow(
              icon: Icons.event_rounded,
              label: 'Ngày khởi hành',
              value: DateFormat('dd/MM/yyyy').format(result.departureDate),
            ),
            _ResultRow(
              icon: Icons.map_rounded,
              label: 'Lịch trình',
              value: '#${result.scheduleId}',
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Check-in QR')),
      body: Padding(
        padding: const EdgeInsets.all(24).copyWith(
          bottom: ShellLayout.bottomInset(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Lịch trình đang chọn
            Obx(() {
              final scheduleId = _staff.selectedScheduleId.value;
              final schedule = scheduleId != null
                  ? _staff.schedules.firstWhereOrNull(
                      (s) => s.scheduleId == scheduleId)
                  : null;
              return IosSurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.event_rounded),
                  title: Text(
                    schedule?.tourName ??
                        (scheduleId != null
                            ? 'Lịch trình #$scheduleId'
                            : 'Chưa chọn lịch trình'),
                  ),
                  subtitle: const Text('Chọn lịch trình ở tab Lịch'),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Nút quét QR
            FilledButton.icon(
              onPressed: () async {
                final code = await Get.toNamed(AppRoutes.qrScan);
                if (code is String) {
                  _qrController.text = code;
                  await _doCheckIn();
                }
              },
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Quét QR'),
            ),
            const SizedBox(height: 16),

            // Nhập thủ công
            CustomTextField(
              controller: _qrController,
              label: 'Hoặc nhập mã QR thủ công',
            ),
            const SizedBox(height: 12),

            // Nút check-in
            CustomButton(
              label: _isProcessing ? 'Đang xử lý...' : 'Check-in',
              onPressed: _isProcessing ? null : _doCheckIn,
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 16),
            // Danh sách vé của lịch trình
            Row(
              children: [
                Text('Danh sách vé',
                    style: AppTextStyles.textTheme.titleMedium),
                const Spacer(),
                Obx(() {
                  final total = _staff.tickets.length;
                  final done =
                      _staff.tickets.where((t) => t.isCheckedIn).length;
                  if (total == 0) return const SizedBox.shrink();
                  return Text(
                    '$done / $total',
                    style: AppTextStyles.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Obx(() {
                if (_staff.isLoadingTickets.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_staff.tickets.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có vé',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: _staff.tickets.length,
                  itemBuilder: (context, index) {
                    final t = _staff.tickets[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 4),
                      leading: Icon(
                        t.isCheckedIn
                            ? Icons.check_circle_rounded
                            : Icons.confirmation_number_outlined,
                        color: t.isCheckedIn ? AppColors.brand : Colors.grey,
                      ),
                      title: Text(
                        t.attendeeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${t.idCard} • ${t.checkInStatus ?? 'Chưa check-in'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: (t.qrCode != null && t.qrCode!.isNotEmpty)
                          ? IconButton(
                        tooltip: 'Hiển thị QR',
                        icon: const Icon(Icons.qr_code_rounded),
                        onPressed: () => _showQrDialog(context, t),
                      )
                          : null,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
void _showQrDialog(BuildContext context, StaffTicketModel t) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(t.attendeeName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: t.qrCode!,
            size: 200,
          ),
          const SizedBox(height: 16),
          SelectableText(
            t.qrCode!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: t.qrCode!));
            Navigator.of(ctx).pop();
            SnackbarHelper.success('Đã sao chép mã QR');
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Sao chép'),
        ),
      ],
    ),
  );
}

// ── Result row ────────────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTextStyles.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}