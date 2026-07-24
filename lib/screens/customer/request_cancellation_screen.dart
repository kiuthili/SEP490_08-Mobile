import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
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
      SnackbarHelper.error('Không xác định được đơn cần hủy');
      return;
    }
    if (_submitting) return;
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
      final controller = Get.find<OrderController>();
      await controller.fetchOrders(refresh: true);
      if (mounted) Get.back(result: true);
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
              _CancellationIntro(orderId: _orderId),
              if (_bankLoadFailed) ...[
                const SizedBox(height: 12),
                const _BankFallbackNotice(),
              ],
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Ngân hàng',
                  hintText: _loadingBanks
                      ? 'Đang tải danh sách ngân hàng...'
                      : 'Chọn ngân hàng',
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
                validator: (value) =>
                    value == null || value.isEmpty ? 'Chọn ngân hàng' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _accountController,
                label: 'Số tài khoản',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !_submitting,
                validator: _validateAccountNumber,
                prefixIcon: Icons.credit_card_outlined,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _holderController,
                label: 'Tên chủ tài khoản',
                enabled: !_submitting,
                textCapitalization: TextCapitalization.words,
                validator: Validators.fullName,
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _reasonController,
                label: 'Lý do hủy',
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                enabled: !_submitting,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                validator: _validateReason,
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

  String? _validateAccountNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Số tài khoản không được để trống';
    if (text.length < 6) return 'Số tài khoản quá ngắn';
    if (text.length > 30) return 'Số tài khoản tối đa 30 chữ số';
    return null;
  }

  String? _validateReason(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Lý do không được để trống';
    if (text.length < 10) return 'Lý do cần ít nhất 10 ký tự';
    if (text.length > 500) return 'Lý do tối đa 500 ký tự';
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
                  'Yêu cầu hủy đơn #$orderId',
                  style: AppTextStyles.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhập thông tin tài khoản nhận hoàn tiền. StayHub sẽ xét duyệt và cập nhật trạng thái trong chi tiết đơn.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.45,
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
              'Không tải được danh sách ngân hàng trực tuyến, đang dùng danh sách dự phòng.',
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
