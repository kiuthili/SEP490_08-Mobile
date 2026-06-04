import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
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
                FilledButton(
                  onPressed: _save,
                  child: const Text('Lưu'),
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

    return ListView.separated(
      physics: physics,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _controller.vouchers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final v = _controller.vouchers[index];
        return IosSurfaceCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.brandLight,
              child: Icon(
                Icons.percent_rounded,
                color: AppColors.brand,
                size: 20,
              ),
            ),
            title: Text(
              v.code,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(v.description ?? v.status ?? ''),
            trailing: v.discountValue != null
                ? Text(
                    '-${CurrencyFormatter.format(v.discountValue!)}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        );
      },
    );
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
