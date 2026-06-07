import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/api_response.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/ios_grouped.dart';

class BankPaymentDemoScreen extends StatefulWidget {
  const BankPaymentDemoScreen({super.key});

  @override
  State<BankPaymentDemoScreen> createState() => _BankPaymentDemoScreenState();
}

class _BankPaymentDemoScreenState extends State<BankPaymentDemoScreen> {
  static const _demoOtp = '123456';

  final _orderService = Get.find<OrderService>();
  final _formKey = GlobalKey<FormState>();
  final _holderController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _otpController = TextEditingController();

  late final int _orderId;
  late final int _amount;
  String _bank = 'Vietcombank';
  bool _otpRequested = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _orderId = args['orderId'] as int? ?? 0;
    _amount = args['amount'] as int? ?? 0;
  }

  @override
  void dispose() {
    _holderController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _continuePayment() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_otpRequested) {
      setState(() => _otpRequested = true);
      SnackbarHelper.info('Mã OTP demo của bạn là $_demoOtp');
      return;
    }

    if (_otpController.text.trim() != _demoOtp) {
      SnackbarHelper.error('OTP demo không đúng. Vui lòng nhập $_demoOtp');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await _orderService.markOrderPaid(_orderId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      SnackbarHelper.success('Thanh toán demo thành công');
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: AppScreen(
        title: 'Thanh toán ngân hàng',
        bottomBar: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng thanh toán',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    CurrencyFormatter.format(_amount),
                    style: AppTextStyles.textTheme.titleMedium?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: CustomButton(
                label: _otpRequested ? 'Xác nhận thanh toán' : 'Nhận mã OTP',
                compact: true,
                isLoading: _isProcessing,
                onPressed: _continuePayment,
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DemoNotice(orderId: _orderId),
                const SizedBox(height: 16),
                _BankCardPreview(
                  bank: _bank,
                  holder: _holderController.text,
                  cardNumber: _cardController.text,
                ),
                const SizedBox(height: 20),
                Text(
                  'Thông tin thanh toán',
                  style: AppTextStyles.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                IosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _bank,
                        decoration: const InputDecoration(
                          labelText: 'Ngân hàng',
                          prefixIcon: Icon(Icons.account_balance_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Vietcombank',
                            child: Text('Vietcombank'),
                          ),
                          DropdownMenuItem(
                            value: 'Techcombank',
                            child: Text('Techcombank'),
                          ),
                          DropdownMenuItem(
                            value: 'BIDV',
                            child: Text('BIDV'),
                          ),
                          DropdownMenuItem(
                            value: 'MB Bank',
                            child: Text('MB Bank'),
                          ),
                        ],
                        onChanged: _otpRequested
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _bank = value);
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _holderController,
                        label: 'Tên chủ thẻ',
                        hint: 'NGUYEN VAN A',
                        prefixIcon: Icons.person_outline_rounded,
                        textCapitalization: TextCapitalization.characters,
                        enabled: !_otpRequested,
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Nhập tên chủ thẻ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _cardController,
                        label: 'Số thẻ',
                        hint: '9704 1234 5678 9012',
                        prefixIcon: Icons.credit_card_rounded,
                        keyboardType: TextInputType.number,
                        maxLength: 19,
                        enabled: !_otpRequested,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(19),
                        ],
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final digits = value?.replaceAll(' ', '') ?? '';
                          if (digits.length < 12) {
                            return 'Số thẻ phải có ít nhất 12 chữ số';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _expiryController,
                              label: 'Hiệu lực',
                              hint: 'MM/YY',
                              keyboardType: TextInputType.datetime,
                              maxLength: 5,
                              enabled: !_otpRequested,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9/]'),
                                ),
                              ],
                              validator: (value) {
                                if (!RegExp(r'^(0[1-9]|1[0-2])/\d{2}$')
                                    .hasMatch(value?.trim() ?? '')) {
                                  return 'Dùng MM/YY';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _cvvController,
                              label: 'CVV',
                              hint: '•••',
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              enabled: !_otpRequested,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) =>
                                  value?.length == 3 ? null : 'Nhập 3 số',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_otpRequested) ...[
                  const SizedBox(height: 16),
                  IosSurfaceCard(
                    color: AppColors.brandLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Xác thực giao dịch demo',
                                style: AppTextStyles.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhập mã $_demoOtp để mô phỏng xác thực từ ngân hàng.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: _otpController,
                          label: 'Mã OTP',
                          hint: _demoOtp,
                          prefixIcon: Icons.password_rounded,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (!_otpRequested) return null;
                            return value?.length == 6
                                ? null
                                : 'OTP gồm 6 chữ số';
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const _SecurityNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_rounded, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chế độ demo cho đơn #$orderId. Không có giao dịch ngân hàng '
              'hay khoản tiền thật nào được phát sinh.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.navy,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankCardPreview extends StatelessWidget {
  const _BankCardPreview({
    required this.bank,
    required this.holder,
    required this.cardNumber,
  });

  final String bank;
  final String holder;
  final String cardNumber;

  String get _maskedNumber {
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '••••  ••••  ••••  9012';
    final tail =
        digits.length > 4 ? digits.substring(digits.length - 4) : digits;
    return '••••  ••••  ••••  $tail';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.72,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF061A40), Color(0xFF0068E0), Color(0xFF42A5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.3),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  bank,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.contactless_rounded, color: Colors.white),
              ],
            ),
            const Spacer(),
            const Icon(Icons.memory_rounded,
                color: Color(0xFFFFD37A), size: 34),
            const SizedBox(height: 12),
            Text(
              _maskedNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              holder.trim().isEmpty ? 'CARD HOLDER' : holder.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          'Dữ liệu chỉ dùng để mô phỏng trong phiên này',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
