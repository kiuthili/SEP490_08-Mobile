import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/shell_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class _BankOption {
  const _BankOption({
    required this.name,
    this.shortName,
    this.code,
  });

  final String name;
  final String? shortName;
  final String? code;

  String get label {
    final prefix = shortName?.trim().isNotEmpty == true
        ? shortName!.trim()
        : code?.trim().isNotEmpty == true
            ? code!.trim()
            : null;
    return prefix == null ? name : '$prefix - $name';
  }
}

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
  var _loadingBanks = true;
  var _bankLoadFailed = false;
  var _submitting = false;
  List<_BankOption> _bankOptions = const [
    _BankOption(
      name: 'Ngân hàng TMCP Ngoại thương Việt Nam',
      shortName: 'Vietcombank',
    ),
    _BankOption(
      name: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam',
      shortName: 'BIDV',
    ),
    _BankOption(
      name: 'Ngân hàng TMCP Công thương Việt Nam',
      shortName: 'VietinBank',
    ),
    _BankOption(
      name: 'Ngân hàng TMCP Kỹ thương Việt Nam',
      shortName: 'Techcombank',
    ),
    _BankOption(
      name: 'Ngân hàng TMCP Quân đội',
      shortName: 'MB Bank',
    ),
    _BankOption(
      name: 'Ngân hàng TMCP Á Châu',
      shortName: 'ACB',
    ),
  ];
  String? _selectedBank;

  @override
  void initState() {
    super.initState();
    final routeOrderId = _readOrderId(Get.parameters['orderId']);
    _orderId = routeOrderId > 0 ? routeOrderId : _readOrderId(Get.arguments);
    _loadBanks();
  }

  int _readOrderId(Object? arguments) {
    if (arguments is int) return arguments;
    if (arguments is String) return int.tryParse(arguments) ?? 0;
    if (arguments is Map) {
      final id = arguments['orderId'] ?? arguments['id'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id) ?? 0;
      if (id is num) return id.toInt();
    }
    return 0;
  }

  Future<void> _loadBanks() async {
    try {
      setState(() {
        _loadingBanks = true;
        _bankLoadFailed = false;
      });
      final res = await Dio().get<Map<String, dynamic>>(
        'https://api.vietqr.io/v2/banks',
      );
      final data = res.data?['data'];
      if (data is List && data.isNotEmpty) {
        final banks = <_BankOption>[];
        for (final item in data) {
          if (item is Map) {
            final name = item['name']?.toString().trim();
            if (name != null && name.isNotEmpty) {
              banks.add(
                _BankOption(
                  name: name,
                  shortName: item['shortName']?.toString(),
                  code: item['code']?.toString(),
                ),
              );
            }
          }
        }
        if (banks.isNotEmpty && mounted) {
          banks.sort((a, b) => a.label.compareTo(b.label));
          setState(() => _bankOptions = banks);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _bankLoadFailed = true);
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  @override
  void dispose() {
    _accountController.dispose();
    _holderController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_orderId <= 0) {
      SnackbarHelper.error('rc_error_invalid_order'.tr);
      return;
    }
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bank = _selectedBank;
    if (bank == null || bank.isEmpty) {
      SnackbarHelper.error('rc_error_select_bank'.tr);
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
      final controller = Get.find<OrderController>();
      await controller.fetchOrders(refresh: true);

      if (mounted) Get.back(result: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'rc_title'.tr,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CancellationIntro(orderId: _orderId),
              if (_bankLoadFailed) ...[
                const SizedBox(height: 16),
                const _BankFallbackNotice(),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.card,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'rc_bank'.tr,
                        hintText: _loadingBanks
                            ? 'rc_loading_banks'.tr
                            : 'rc_select_bank'.tr,
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                      ),
                      initialValue: _selectedBank,
                      isExpanded: true,
                      items: _bankOptions
                          .map(
                            (bank) => DropdownMenuItem(
                              value: bank.name,
                              child: Text(
                                bank.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _selectedBank = value),
                      validator: (value) => value == null || value.isEmpty
                          ? 'rc_error_select_bank'.tr
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _accountController,
                      label: 'rc_account_number'.tr,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      enabled: !_submitting,
                      validator: _validateAccountNumber,
                      prefixIcon: Icons.credit_card_outlined,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _holderController,
                      label: 'rc_account_holder'.tr,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.words,
                      validator: Validators.fullName,
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _reasonController,
                      label: 'rc_reason'.tr,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      validator: _validateReason,
                      prefixIcon: Icons.notes_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'rc_submit'.tr,
                isLoading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateAccountNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'rc_val_acc_empty'.tr;
    if (text.length < 6) return 'rc_val_acc_short'.tr;
    if (text.length > 30) return 'rc_val_acc_long'.tr;
    return null;
  }

  String? _validateReason(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'rc_val_reason_empty'.tr;
    if (text.length < 10) return 'rc_val_reason_short'.tr;
    if (text.length > 500) return 'rc_val_reason_long'.tr;
    return null;
  }
}

class _CancellationIntro extends StatelessWidget {
  const _CancellationIntro({required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.assignment_return_outlined,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'rc_intro_title'.trParams({'id': orderId.toString()}),
                  style: AppTextStyles.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'rc_intro_desc'.tr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: AppColors.textSecondary,
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

class _BankFallbackNotice extends StatelessWidget {
  const _BankFallbackNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'rc_bank_fallback'.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.navy,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
