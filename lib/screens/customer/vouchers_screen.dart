import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../routes/app_routes.dart';
import '../../utils/validators.dart';
import '../../widgets/loading_widget.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  late final VoucherController _controller;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<VoucherController>();
    _controller.fetchVouchers();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'vc_my_vouchers'.tr,
      body: ColoredBox(
        color: AppColors.surfaceGrouped,
        child: Column(
        children: [
          // ── Redeem code bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'vc_enter_code'.tr,
                      prefixIcon: const Icon(
                        Icons.confirmation_number_outlined,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: const BorderSide(
                          color: AppColors.brand,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(
                  () => FilledButton(
                    onPressed: _controller.isSaving.value ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: _controller.isSaving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'vc_save'.tr,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ── List ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: _controller.fetchVouchers,
              child: Obx(() => _buildList()),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildList() {
    const physics = AlwaysScrollableScrollPhysics();

    if (_controller.isLoading.value && _controller.vouchers.isEmpty) {
      return ListView(
        physics: physics,
        children: [
          const SizedBox(height: 120),
          LoadingWidget(message: 'vc_loading_vouchers'.tr),
        ],
      );
    }

    if (_controller.vouchers.isEmpty) {
      return ListView(
        physics: physics,
        children: [
          const SizedBox(height: 80),
          EmptyStateWidget(
            title: 'vc_no_vouchers'.tr,
            subtitle: 'vc_save_to_use'.tr,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: physics,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: _controller.vouchers.length,
      itemBuilder: (context, index) {
        final v = _controller.vouchers[index];
        return _VoucherCard(
          voucher: v,
          discountText: _discountText(v),
          statusLabel: _statusLabel(v.status, v.voucherStatus),
        );
      },
    );
  }

  String _discountText(VoucherModel voucher) {
    final value = voucher.discountValue ?? 0;
    final type = voucher.discountType?.toLowerCase() ?? '';
    if (type.contains('percent')) {
      return 'vc_discount_percent'.trParams({'val': value.toString()});
    }
    if (value >= 1000) {
      return 'vc_discount_k'
          .trParams({'val': (value / 1000).toStringAsFixed(0)});
    }
    return 'vc_discount_amount'
        .trParams({'val': CurrencyFormatter.format(value)});
  }

  String _statusLabel(String? userStatus, String? voucherStatus) {
    final status = (userStatus?.isNotEmpty == true ? userStatus : voucherStatus)
            ?.toLowerCase() ??
        '';
    return switch (status) {
      'available' || 'active' => 'vc_status_active'.tr,
      'used' => 'vc_status_used'.tr,
      'expired' => 'vc_status_expired'.tr,
      'inactive' => 'vc_status_inactive'.tr,
      _ => 'Voucher',
    };
  }

  Future<void> _save() async {
    final code = _codeController.text.trim();
    final err = Validators.voucherCode(code);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final ok = await _controller.saveVoucher(code);
    if (ok) _codeController.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voucher Card — iOS-style ticket shape
// ─────────────────────────────────────────────────────────────────────────────

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.voucher,
    required this.discountText,
    required this.statusLabel,
  });

  final VoucherModel voucher;
  final String discountText;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final isAvailable = voucher.isAvailable;
    final accentColor = isAvailable ? AppColors.brand : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: AppColors.surface,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left accent panel ──────────────────────────────────────
                Container(
                  width: 100,
                  color: isAvailable
                      ? AppColors.brand
                      : AppColors.surfaceGrouped,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            discountText,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isAvailable
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'VOUCHER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: isAvailable
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Dashed divider notch ───────────────────────────────────
                _TicketDivider(color: accentColor),

                // ── Right content ──────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Code + status
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              voucher.code,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isAvailable
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (voucher.minOrderAmount != null &&
                                voucher.minOrderAmount! > 0)
                              Text(
                                'vc_min_order'.trParams({
                                  'amount': CurrencyFormatter.format(
                                      voucher.minOrderAmount!)
                                }),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),

                        // Bottom row: status badge + use button / expiry
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Status pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? AppColors.brand.withValues(alpha: 0.1)
                                        : AppColors.surfaceGrouped,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isAvailable
                                          ? AppColors.brand
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (voucher.endDate != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'HSD: ${DateFormatter.display(voucher.endDate)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (isAvailable)
                              GestureDetector(
                                onTap: () {
                                  if (voucher.tourId != null &&
                                      voucher.tourId! > 0) {
                                    Get.toNamed(AppRoutes.tourDetail,
                                        arguments: voucher.tourId);
                                  } else {
                                    Get.toNamed(AppRoutes.tourSearch);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    'vc_use_now'.tr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dashed ticket notch divider
class _TicketDivider extends StatelessWidget {
  const _TicketDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      child: CustomPaint(
        painter: _DashPainter(color: color.withValues(alpha: 0.2)),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 6.0;
    const gap = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashHeight),
        paint,
      );
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
