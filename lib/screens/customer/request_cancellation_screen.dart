import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class RequestCancellationScreen extends StatefulWidget {
  const RequestCancellationScreen({super.key});

  @override
  State<RequestCancellationScreen> createState() =>
      _RequestCancellationScreenState();
}

class _RequestCancellationScreenState extends State<RequestCancellationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _holderController = TextEditingController();
  final _reasonController = TextEditingController();
  late final int _orderId;
  var _submitting = false;
  List<String> _bankOptions = const [
    'Ngân hàng TMCP Ngoại thương Việt Nam',
    'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam',
    'Ngân hàng TMCP Công thương Việt Nam',
    'Ngân hàng TMCP Kỹ thương Việt Nam',
    'Ngân hàng TMCP Quân đội',
    'Ngân hàng TMCP Á Châu',
  ];
  String? _selectedBank;

  @override
  void initState() {
    super.initState();
    _orderId = Get.arguments as int? ?? 0;
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      final res = await Dio().get<Map<String, dynamic>>(
        'https://api.vietqr.io/v2/banks',
      );
      final data = res.data?['data'];
      if (data is List && data.isNotEmpty) {
        final names = <String>[];
        for (final item in data) {
          if (item is Map && item['name'] is String) {
            names.add(item['name'] as String);
          }
        }
        if (names.isNotEmpty && mounted) {
          setState(() => _bankOptions = names);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _accountController.dispose();
    _holderController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bank = _selectedBank;
    if (bank == null || bank.isEmpty) {
      SnackbarHelper.error('Chọn ngân hàng nhận hoàn tiền');
      return;
    }
    setState(() => _submitting = true);
    final ok = await Get.find<OrderController>().requestCancellation(
      orderId: _orderId,
      reason: _reasonController.text.trim(),
      bankName: bank,
      accountNumber: _accountController.text.trim(),
      accountHolderName: _holderController.text.trim(),
    );
    if (mounted) setState(() => _submitting = false);
    if (ok) {
      Get.back(result: true);
      await Get.find<OrderController>().fetchOrderDetail(_orderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Yêu cầu hủy tour',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Đơn #$_orderId — thông tin hoàn tiền (theo form web).',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Ngân hàng',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                initialValue: _selectedBank,
                isExpanded: true,
                items: _bankOptions
                    .map(
                      (b) => DropdownMenuItem(
                        value: b,
                        child: Text(
                          b,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedBank = v),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Chọn ngân hàng' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _accountController,
                label: 'Số tài khoản',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    Validators.requiredField(v, label: 'Số tài khoản'),
                prefixIcon: Icons.credit_card_outlined,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _holderController,
                label: 'Tên chủ tài khoản',
                validator: Validators.fullName,
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _reasonController,
                label: 'Lý do hủy',
                maxLines: 4,
                validator: (v) => Validators.requiredField(v, label: 'Lý do'),
                prefixIcon: Icons.notes_outlined,
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: 'Gửi yêu cầu',
                isLoading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
