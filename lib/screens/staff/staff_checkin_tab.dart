import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stayhub_mobile/models/staff_ticket_model.dart';
import '../../models/check_in_result_model.dart';
import '../../utils/snackbar_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'package:flutter/services.dart';
import 'package:stayhub_mobile/controllers/staff_controller.dart';
import '../../widgets/ios_grouped.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class StaffCheckInTab extends StatefulWidget {
  const StaffCheckInTab({super.key});

  @override
  State<StaffCheckInTab> createState() => _StaffCheckInTabState();
}

class _StaffCheckInTabState extends State<StaffCheckInTab>
    with SingleTickerProviderStateMixin {
  final _qrController = TextEditingController();
  final _staff = Get.find<StaffController>();
  final _cameraController = MobileScannerController();

  bool _isProcessing = false;
  bool _processed = false;

  late final AnimationController _lineController;
  late final Animation<double> _lineAnimation;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _lineAnimation = Tween<double>(begin: 0, end: 1).animate(_lineController);
  }

  @override
  void dispose() {
    _lineController.dispose();
    _cameraController.dispose();
    _qrController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processed || _isProcessing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _processed = true;
      _qrController.text = code;
    });

    await _doCheckIn();

    if (mounted) {
      setState(() => _processed = false);
    }
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
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
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24).copyWith(bottom: 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Camera Scanner
                Container(
                  height: 280,
                  width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _cameraController,
                        onDetect: _onDetect,
                      ),
                      _ScanOverlay(),
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: Stack(
                            children: [
                              const _CornerMarkers(),
                              AnimatedBuilder(
                                animation: _lineAnimation,
                                builder: (_, __) => Positioned(
                                  top: 8 + (_lineAnimation.value * 184),
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    height: 2,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          AppColors.brand,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_processed)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
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
              ]),
            ),
          ),
          Obx(() {
            if (_staff.isLoadingTickets.value) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_staff.tickets.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Chưa có vé',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.only(
                  bottom: ShellLayout.bottomInset(context) + 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final t = _staff.tickets[index];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 24),
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
                  childCount: _staff.tickets.length,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

void _showQrDialog(BuildContext context, StaffTicketModel t) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
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

// ── Overlay mờ xung quanh khung quét ─────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameSize = 200.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: frameSize,
      height: frameSize,
    );

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    // Vẽ 4 vùng tối xung quanh khung
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), paint);
    canvas.drawRect(
        Rect.fromLTRB(0, rect.bottom, size.width, size.height), paint);
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), paint);
    canvas.drawRect(
        Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 4 góc khung quét ──────────────────────────────────────────────────────────

class _CornerMarkers extends StatelessWidget {
  const _CornerMarkers();

  @override
  Widget build(BuildContext context) {
    const color = AppColors.brand;
    const thickness = 4.0;
    const length = 28.0;
    const r = 6.0;

    return Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          child: _Corner(
              color: color,
              t: thickness,
              l: length,
              r: r,
              flipH: false,
              flipV: false),
        ),
        const Positioned(
          top: 0,
          right: 0,
          child: _Corner(
              color: color,
              t: thickness,
              l: length,
              r: r,
              flipH: true,
              flipV: false),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          child: _Corner(
              color: color,
              t: thickness,
              l: length,
              r: r,
              flipH: false,
              flipV: true),
        ),
        const Positioned(
          bottom: 0,
          right: 0,
          child: _Corner(
              color: color,
              t: thickness,
              l: length,
              r: r,
              flipH: true,
              flipV: true),
        ),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({
    required this.color,
    required this.t,
    required this.l,
    required this.r,
    required this.flipH,
    required this.flipV,
  });

  final Color color;
  final double t, l, r;
  final bool flipH, flipV;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flipH ? -1 : 1,
      scaleY: flipV ? -1 : 1,
      child: SizedBox(
        width: l,
        height: l,
        child: CustomPaint(
          painter: _CornerPainter(color: color, thickness: t, radius: r),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(
      {required this.color, required this.thickness, required this.radius});

  final Color color;
  final double thickness, radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
