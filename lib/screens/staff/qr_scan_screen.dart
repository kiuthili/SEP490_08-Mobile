import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stayhub_mobile/controllers/staff_controller.dart';
import 'package:stayhub_mobile/models/check_in_result_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with SingleTickerProviderStateMixin {
  final _staff = Get.find<StaffController>();
  final _cameraController = MobileScannerController();

  bool _processed = false;
  bool _torchOn = false;

  // Scan-line animation
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
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processed) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _processed = true);

    final result = await _staff.checkIn(code);

    if (!mounted) return;

    if (result != null) {
      await _showResultDialog(result);
      if (mounted) Get.back(result: code);
    } else {
      // Lỗi đã được xử lý bởi controller (SnackbarHelper)
      // Cho phép quét lại
      setState(() => _processed = false);
    }
  }

  Future<void> _showResultDialog(CheckInResultModel result) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon thành công
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.brandLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.brand, size: 40),
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
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('st_close'.tr),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('st_scan_qr_checkin'.tr),
        actions: [
          // Torch toggle
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _cameraController.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),

          // Dimmed overlay với hole ở giữa
          _ScanOverlay(),

          // Scan frame + animated line
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  // Corner markers
                  const _CornerMarkers(),

                  // Scan line
                  AnimatedBuilder(
                    animation: _lineAnimation,
                    builder: (_, __) => Positioned(
                      top: 8 + (_lineAnimation.value * 244),
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
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

          // Instruction text
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_processed)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  const Icon(Icons.qr_code_scanner_rounded,
                      color: Colors.white54, size: 28),
                const SizedBox(height: 12),
                Text(
                  _processed
                      ? 'st_processing'.tr
                      : 'st_point_camera_qr'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    const frameSize = 260.0;
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
        // Top-left
        Positioned(
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
        // Top-right
        Positioned(
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
        // Bottom-left
        Positioned(
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
        // Bottom-right
        Positioned(
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
            style: AppTextStyles.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
