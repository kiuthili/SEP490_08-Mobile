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
import '../../controllers/notification_controller.dart';
import '../../routes/app_routes.dart';
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
              'st_checkin_success'.tr,
              style: AppTextStyles.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 20),
            _ResultRow(
              icon: Icons.person_rounded,
              label: 'st_passenger'.tr,
              value: result.attendeeName,
            ),
            _ResultRow(
              icon: Icons.local_activity_rounded,
              label: 'st_ticket_type'.tr,
              value: result.ticketTypeName,
            ),
            _ResultRow(
              icon: Icons.confirmation_number_rounded,
              label: 'st_ticket_code'.tr,
              value: '#${result.ticketId}',
            ),
            _ResultRow(
              icon: Icons.event_rounded,
              label: 'st_departure_date'.tr,
              value: DateFormat('dd/MM/yyyy').format(result.departureDate),
            ),
            _ResultRow(
              icon: Icons.map_rounded,
              label: 'st_schedule'.tr,
              value: '#${result.scheduleId}',
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('st_close'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('st_qr_checkin'.tr),
        actions: [
          Obx(() {
            if (!Get.isRegistered<NotificationController>()) return const SizedBox.shrink();
            final notifController = Get.find<NotificationController>();
            final unread = notifController.unreadCount;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: () => Get.toNamed(AppRoutes.notifications),
                icon: Badge(
                  label: Text(unread > 99 ? '99+' : unread.toString()),
                  isLabelVisible: unread > 0,
                  backgroundColor: AppColors.error,
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            );
          }),
        ],
      ),
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
                  label: 'st_enter_qr_manually'.tr,
                ),
                const SizedBox(height: 12),

                // Nút check-in
                CustomButton(
                  label: _isProcessing ? 'st_processing'.tr : 'st_checkin'.tr,
                  onPressed: _isProcessing ? null : _doCheckIn,
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
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
          child: Text('st_close'.tr),
        ),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: t.qrCode!));
            Navigator.of(ctx).pop();
            SnackbarHelper.success('st_qr_copied'.tr);
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text('st_copy'.tr),
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
