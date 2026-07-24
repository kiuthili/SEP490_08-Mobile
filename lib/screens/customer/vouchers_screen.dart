import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
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
      title: 'Voucher của tôi',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập mã voucher',
                      prefixIcon: Icon(Icons.local_offer_outlined),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 8),
                Obx(
                  () => FilledButton(
                    onPressed: _controller.isSaving.value ? null : _save,
                    child: _controller.isSaving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _controller.fetchVouchers,
              child: Obx(() => _buildList()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    const physics = AlwaysScrollableScrollPhysics();

    if (_controller.isLoading.value && _controller.vouchers.isEmpty) {
      return ListView(
        physics: physics,
        children: const [
          SizedBox(height: 120),
          LoadingWidget(message: 'Đang tải voucher...'),
        ],
      );
    }

    if (_controller.vouchers.isEmpty) {
      return ListView(
        physics: physics,
        children: const [
          SizedBox(height: 80),
          EmptyStateWidget(
            title: 'Chưa có voucher',
            subtitle: 'Lưu mã voucher để dùng khi đặt tour',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: physics,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _controller.vouchers.length,
      itemBuilder: (context, index) {
        final v = _controller.vouchers[index];
        final statusLabel = _statusLabel(v.status, v.voucherStatus);
        final discountText = _discountText(v);
        final isAvailable = v.isAvailable;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 115,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 110,
                decoration: BoxDecoration(
                  color: isAvailable ? AppColors.brand : const Color(0xFFE0E0E0),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FittedBox(
                        child: Text(
                          discountText,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isAvailable ? Colors.white : Colors.black45,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'VOUCHER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isAvailable ? Colors.white70 : Colors.black38,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                color: const Color(0xFFF0F0F0),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        v.code,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.black87 : Colors.black45,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (v.minOrderAmount != null && v.minOrderAmount! > 0)
                        Text(
                          'Đơn tối thiểu ${CurrencyFormatter.format(v.minOrderAmount!)}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAvailable ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isAvailable ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (v.endDate != null)
                                Text(
                                  'HSD: ${DateFormatter.display(v.endDate)}',
                                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                                ),
                            ],
                          ),
                          if (isAvailable)
                            OutlinedButton(
                              onPressed: () {
                                if (v.tourId != null && v.tourId! > 0) {
                                  Get.toNamed(AppRoutes.tourDetail, arguments: v.tourId);
                                } else {
                                  Get.toNamed(AppRoutes.tourSearch);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brand,
                                side: const BorderSide(color: AppColors.brand, width: 1),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                minimumSize: const Size(0, 26),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text('Dùng ngay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _discountText(VoucherModel voucher) {
    final value = voucher.discountValue ?? 0;
    final type = voucher.discountType?.toLowerCase() ?? '';
    if (type.contains('percent')) return 'Giảm $value%';
    if (value >= 1000) {
      return 'Giảm ${(value / 1000).toStringAsFixed(0)}K';
    }
    return 'Giảm ${CurrencyFormatter.format(value)}';
  }

  String _statusLabel(String? userStatus, String? voucherStatus) {
    final status = (userStatus?.isNotEmpty == true ? userStatus : voucherStatus)
            ?.toLowerCase() ??
        '';
    return switch (status) {
      'available' || 'active' => 'Có thể dùng',
      'used' => 'Đã dùng',
      'expired' => 'Hết hạn',
      'inactive' => 'Tạm ngưng',
      _ => 'Voucher',
    };
  }

  Future<void> _save() async {
    final code = _codeController.text.trim();
    final err = Validators.voucherCode(code);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final ok = await _controller.saveVoucher(code);
    if (ok) _codeController.clear();
  }
}
