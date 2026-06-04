import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/ios_grouped.dart';

class StaffCheckInTab extends StatefulWidget {
  const StaffCheckInTab({super.key});

  @override
  State<StaffCheckInTab> createState() => _StaffCheckInTabState();
}

class _StaffCheckInTabState extends State<StaffCheckInTab> {
  final _qrController = TextEditingController();
  final _staff = Get.find<StaffController>();

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
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
            Obx(() {
              final scheduleId = _staff.selectedScheduleId.value;
              return IosSurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(
                    scheduleId != null
                        ? 'Lịch trình #$scheduleId'
                        : 'Chưa chọn lịch trình',
                  ),
                  subtitle: const Text('Chọn lịch trình ở tab Lịch trình'),
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final code = await Get.toNamed(AppRoutes.qrScan);
                if (code is String) _qrController.text = code;
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Quét QR'),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _qrController,
              label: 'Hoặc nhập mã QR',
            ),
            const SizedBox(height: 12),
            CustomButton(
              label: 'Check-in',
              onPressed: () async {
                if (_qrController.text.trim().isEmpty) return;
                final ok = await _staff.checkIn(_qrController.text.trim());
                if (ok) _qrController.clear();
              },
            ),
            const SizedBox(height: 24),
            Text('Danh sách vé',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(() {
                if (_staff.tickets.isEmpty) {
                  return const Center(child: Text('Chưa có vé'));
                }
                return ListView.builder(
                  itemCount: _staff.tickets.length,
                  itemBuilder: (context, index) {
                    final t = _staff.tickets[index];
                    return ListTile(
                      leading: Icon(
                        t.checkInStatus == 'CheckedIn'
                            ? Icons.check_circle
                            : Icons.confirmation_number,
                        color: t.checkInStatus == 'CheckedIn'
                            ? Colors.green
                            : null,
                      ),
                      title: Text(t.attendeeName),
                      subtitle: Text(
                        '${t.idCard} • ${t.checkInStatus ?? 'Chưa check-in'}',
                      ),
                      trailing: t.qrCode != null && t.qrCode!.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.qr_code),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(t.attendeeName),
                                  content: QrImageView(
                                    data: t.qrCode!,
                                    size: 200,
                                  ),
                                ),
                              ),
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
