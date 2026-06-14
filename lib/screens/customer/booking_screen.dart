import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../routes/app_routes.dart';
import '../../services/payment_service.dart';
import '../../utils/booking_args.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class _PassengerForm {
  final BookingPassengerInput slot;
  final nameController = TextEditingController();
  final idCardController = TextEditingController();
  final dobController = TextEditingController();
  String gender = 'Male';
  final nationalityController = TextEditingController(text: 'Vietnam');

  _PassengerForm(this.slot);

  void dispose() {
    nameController.dispose();
    idCardController.dispose();
    dobController.dispose();
    nationalityController.dispose();
  }
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _booking = Get.find<BookingController>();
  final _voucher = Get.isRegistered<VoucherController>()
      ? Get.find<VoucherController>()
      : Get.put(VoucherController());
  final _formKey = GlobalKey<FormState>();
  final _voucherCodeController = TextEditingController();
  final _noteController = TextEditingController();
  final _passengers = <_PassengerForm>[];
  final _workers = <Worker>[];
  var _initDone = false;
  var _initFailed = false;
  PaymentProvider _paymentProvider = PaymentProvider.vnpay;

  @override
  void initState() {
    super.initState();
    final args = parseBookingArgs(Get.arguments);
    if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.error('Vui lòng chọn lịch khởi hành trước khi đặt tour');
        Get.back();
      });
      return;
    }
    _workers.addAll([
      ever(_booking.ticketQuantities, (_) => _syncPassengers()),
      ever(_booking.discountAmount, (_) {
        if (mounted) setState(() {});
      }),
      ever(_booking.voucherCode, (_) {
        if (mounted) setState(() {});
      }),
      ever(_booking.isApplyingVoucher, (_) {
        if (mounted) setState(() {});
      }),
      ever(_booking.isLoading, (_) {
        if (mounted) setState(() {});
      }),
      ever(_voucher.vouchers, (_) {
        if (mounted) setState(() {});
      }),
    ]);
    _voucher.fetchVouchers();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await _booking.initCheckout(
        tourId: args.tourId,
        tourName: args.tourName,
        tourImageUrl: args.tourImageUrl,
        tourLocation: args.tourLocation,
        scheduleId: args.scheduleId,
        departureDate: args.departureDate,
        returnDate: args.returnDate,
      );
      if (!mounted) return;
      setState(() {
        _initDone = true;
        _initFailed = !ok;
      });
      if (ok) _syncPassengers();
    });
  }

  void _syncPassengers() {
    final slots = _booking.buildPassengerSlots();
    final next = <_PassengerForm>[];
    for (var i = 0; i < slots.length; i++) {
      if (i < _passengers.length &&
          _passengers[i].slot.tourScheduleTicketId ==
              slots[i].tourScheduleTicketId) {
        next.add(_passengers[i]);
      } else {
        next.add(_PassengerForm(slots[i]));
      }
    }
    for (var i = slots.length; i < _passengers.length; i++) {
      _passengers[i].dispose();
    }
    _passengers
      ..clear()
      ..addAll(next);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    _voucherCodeController.dispose();
    _noteController.dispose();
    for (final p in _passengers) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_booking.totalPassengers == 0) {
      SnackbarHelper.error('Chọn ít nhất một vé');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      SnackbarHelper.error('Vui lòng điền đầy đủ thông tin hành khách');
      return;
    }

    final passengerPayload = _passengers
        .map(
          (p) => {
            'tourScheduleTicketId': p.slot.tourScheduleTicketId,
            'ticketTypeId': p.slot.ticketTypeId,
            'attendeeName': p.nameController.text.trim(),
            'idCard': p.idCardController.text.trim(),
            'dateOfBirth': p.dobController.text.trim(),
            'gender': p.gender,
            'nationality': p.nationalityController.text.trim(),
          },
        )
        .toList();

    final order = await _booking.bookTour(
      passengers: passengerPayload,
      orderNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    if (order == null || !mounted) return;

    await Get.toNamed(
      AppRoutes.payment,
      arguments: {
        'orderId': order.id,
        'amount': order.finalAmount,
        'provider': _paymentProvider == PaymentProvider.momo ? 'momo' : 'vnpay',
      },
    );
  }

  Future<void> _pickDateOfBirth(_PassengerForm passenger) async {
    final initial = DateTime.tryParse(passenger.dobController.text) ??
        DateTime(DateTime.now().year - 20);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'CHỌN NGÀY SINH',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) {
      passenger.dobController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  List<VoucherModel> get _usableSavedVouchers {
    final tourId = _booking.checkoutTourId;
    return _voucher.vouchers
        .where(
          (v) =>
              v.isAvailable &&
              (v.tourId == null || tourId == null || v.tourId == tourId),
        )
        .toList();
  }

  Future<void> _applyVoucherCode({bool saveBeforeApply = true}) async {
    final code = _voucherCodeController.text.trim().toUpperCase();
    final err = Validators.voucherCode(code);
    if (err != null) {
      SnackbarHelper.error(err);
      return;
    }
    if (_booking.subtotal <= 0) {
      SnackbarHelper.error('Chọn vé trước khi áp dụng voucher');
      return;
    }

    _booking.voucherCode.value = code;
    final ok = await _booking.applyVoucher(saveBeforeApply: saveBeforeApply);
    if (ok && saveBeforeApply) {
      await _voucher.fetchVouchers();
    }
  }

  void _selectSavedVoucher(VoucherModel voucher) {
    _voucherCodeController.text = voucher.code;
    _applyVoucherCode(saveBeforeApply: false);
  }

  Widget _buildVoucherSection() {
    final saved = _usableSavedVouchers;
    final selectedCode = _booking.voucherCode.value;

    return IosSurfaceCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  size: 20,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Voucher', style: AppTextStyles.textTheme.titleSmall),
                    Text(
                      'Chọn mã đã lưu hoặc nhập mã mới',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (saved.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: saved.map((voucher) {
                final selected = selectedCode == voucher.code;
                return ChoiceChip(
                  selected: selected,
                  label: Text(
                    '${voucher.code} • ${_voucherDiscountText(voucher)}',
                  ),
                  onSelected: _booking.isApplyingVoucher.value
                      ? null
                      : (_) => _selectSavedVoucher(voucher),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          CustomTextField(
            controller: _voucherCodeController,
            label: 'Mã voucher',
            prefixIcon: Icons.confirmation_number_outlined,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _applyVoucherCode(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: _booking.isApplyingVoucher.value
                  ? null
                  : () => _applyVoucherCode(),
              icon: _booking.isApplyingVoucher.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _booking.isApplyingVoucher.value
                    ? 'Đang kiểm tra...'
                    : 'Áp dụng ưu đãi',
              ),
            ),
          ),
          if (_booking.discountAmount.value > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Đã giảm ${CurrencyFormatter.format(_booking.discountAmount.value)} '
                      'với mã ${_booking.voucherCode.value}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _voucherDiscountText(VoucherModel voucher) {
    final value = voucher.discountValue ?? 0;
    final type = voucher.discountType?.toLowerCase() ?? '';
    if (type.contains('percent')) return '-$value%';
    return '-${CurrencyFormatter.format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone) {
      return const AppScreen(
        title: 'Đặt tour',
        body: LoadingWidget(message: 'Đang tải thông tin đặt tour...'),
      );
    }

    if (_initFailed || _booking.activeTickets.isEmpty) {
      return AppScreen(
        title: 'Đặt tour',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_busy,
                    size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text(
                  'Lịch này chưa có vé bán',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  label: 'Quay lại tour',
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final schedule = _booking.selectedSchedule.value!;

    return AppScreen(
      title: 'Đặt tour',
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 19,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_booking.totalPassengers} hành khách',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      CurrencyFormatter.format(_booking.finalAmount),
                      style: AppTextStyles.textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (_booking.discountAmount.value > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '-${CurrencyFormatter.format(_booking.discountAmount.value)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          CustomButton(
            label: 'Tiếp tục thanh toán',
            compact: true,
            isLoading: _booking.isLoading.value,
            onPressed: _booking.totalPassengers == 0 ? null : _submit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CheckoutProgress(),
              const SizedBox(height: 14),
              _CheckoutSummaryCard(
                tourName: _booking.checkoutTourName,
                imageUrl: _booking.checkoutTourImageUrl,
                location: _booking.checkoutTourLocation,
                departure: schedule.departureDate,
                returnDate: schedule.returnDate,
              ),
              const SizedBox(height: 24),
              const _SectionHeading(
                icon: Icons.confirmation_number_outlined,
                title: 'Chọn vé',
                subtitle: 'Giá và số lượng còn lại được cập nhật từ lịch tour',
              ),
              const SizedBox(height: 10),
              if (_booking.ticketsLoading.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                ..._booking.activeTickets.map((t) {
                  final qty = _booking.ticketQty(t.id);
                  return _TicketQuantityCard(
                    label: _booking.ticketTypeName(t.ticketTypeId),
                    price: t.price,
                    available: t.availableQuantity,
                    quantity: qty,
                    onDecrease:
                        qty > 0 ? () => _booking.decrementTicket(t.id) : null,
                    onIncrease: qty < t.availableQuantity
                        ? () => _booking.incrementTicket(t.id)
                        : null,
                  );
                }),
              if (_booking.totalPassengers > 0) ...[
                const SizedBox(height: 20),
                _SectionHeading(
                  icon: Icons.groups_2_outlined,
                  title: 'Thông tin hành khách',
                  subtitle:
                      '${_booking.totalPassengers} người • dùng để xuất vé điện tử',
                ),
                const SizedBox(height: 10),
                ..._passengers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return IosSurfaceCard(
                    padding: EdgeInsets.zero,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandLight.withValues(alpha: 0.65),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hành khách ${i + 1}',
                                      style: AppTextStyles.textTheme.titleSmall,
                                    ),
                                    Text(
                                      p.slot.ticketLabel,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.verified_outlined,
                                size: 20,
                                color: AppColors.brand,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              CustomTextField(
                                controller: p.nameController,
                                label: 'Họ tên',
                                prefixIcon: Icons.person_outline_rounded,
                                validator: Validators.fullName,
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: p.idCardController,
                                label: 'CMND/CCCD',
                                prefixIcon: Icons.badge_outlined,
                                keyboardType: TextInputType.number,
                                maxLength: 12,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: Validators.idCard,
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: p.dobController,
                                label: 'Ngày sinh',
                                hint: 'YYYY-MM-DD',
                                prefixIcon: Icons.cake_outlined,
                                suffixIcon: IconButton(
                                  tooltip: 'Chọn ngày sinh',
                                  onPressed: () => _pickDateOfBirth(p),
                                  icon:
                                      const Icon(Icons.calendar_month_rounded),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Nhập ngày sinh';
                                  }
                                  final d = DateTime.tryParse(v.trim());
                                  if (d == null) {
                                    return 'Định dạng không hợp lệ';
                                  }
                                  if (d.isAfter(DateTime.now())) {
                                    return 'Ngày sinh không được ở tương lai';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: p.gender,
                                decoration: const InputDecoration(
                                  labelText: 'Giới tính',
                                  prefixIcon: Icon(Icons.wc_rounded),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Male',
                                    child: Text('Nam'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Female',
                                    child: Text('Nữ'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Other',
                                    child: Text('Khác'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => p.gender = v);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: p.nationalityController,
                                label: 'Quốc tịch',
                                hint: 'Vietnam',
                                prefixIcon: Icons.flag_outlined,
                                validator: Validators.nationality,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 20),
              const _SectionHeading(
                icon: Icons.receipt_long_outlined,
                title: 'Ưu đãi & ghi chú',
                subtitle: 'Áp dụng voucher trước khi tạo đơn',
              ),
              const SizedBox(height: 10),
              CustomTextField(
                controller: _noteController,
                label: 'Ghi chú đơn hàng (tuỳ chọn)',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildVoucherSection(),
              if (_booking.subtotal > 0) ...[
                const SizedBox(height: 16),
                _PaymentSummaryCard(
                  subtotal: _booking.subtotal,
                  discount: _booking.discountAmount.value,
                  total: _booking.finalAmount,
                ),
              ],
              const SizedBox(height: 16),
              _PaymentMethodCard(
                provider: _paymentProvider,
                onChanged: (provider) {
                  setState(() => _paymentProvider = provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutProgress extends StatelessWidget {
  const _CheckoutProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _ProgressStep(
              number: '1',
              label: 'Chọn vé',
              active: true,
            ),
          ),
          _ProgressLine(),
          Expanded(
            child: _ProgressStep(
              number: '2',
              label: 'Thông tin',
              active: true,
            ),
          ),
          _ProgressLine(),
          Expanded(
            child: _ProgressStep(
              number: '3',
              label: 'Thanh toán',
              active: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.number,
    required this.label,
    required this.active,
  });

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.brand : AppColors.surfaceGrouped,
            shape: BoxShape.circle,
            border: active ? null : Border.all(color: AppColors.separator),
          ),
          child: Text(
            number,
            style: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 2,
      margin: const EdgeInsets.only(bottom: 21),
      color: AppColors.brand.withValues(alpha: 0.25),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.brandLight,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 21, color: AppColors.brand),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _TicketQuantityCard extends StatelessWidget {
  const _TicketQuantityCard({
    required this.label,
    required this.price,
    required this.available,
    required this.quantity,
    this.onDecrease,
    this.onIncrease,
  });

  final String label;
  final int price;
  final int available;
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return IosSurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: quantity > 0 ? AppColors.brand : AppColors.surfaceGrouped,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.local_activity_outlined,
              color: quantity > 0 ? Colors.white : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  CurrencyFormatter.format(price),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Còn $available vé',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceGrouped,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDecrease,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onIncrease,
                  icon: const Icon(Icons.add_rounded),
                  color: AppColors.brand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSummaryCard extends StatelessWidget {
  const _CheckoutSummaryCard({
    required this.tourName,
    this.imageUrl,
    this.location,
    required this.departure,
    required this.returnDate,
  });

  final String tourName;
  final String? imageUrl;
  final String? location;
  final DateTime departure;
  final DateTime returnDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      clipBehavior: Clip.antiAlias,
      decoration: AppDecorations.card(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.brandLight),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.brandLight,
                child: const Icon(
                  Icons.landscape_rounded,
                  size: 48,
                  color: AppColors.brand,
                ),
              ),
            )
          else
            Container(
              color: AppColors.brandLight,
              child: const Icon(
                Icons.landscape_rounded,
                size: 48,
                color: AppColors.brand,
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x1805073C),
                  Color(0x5505073C),
                  Color(0xE605073C),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Lịch đã chọn',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tourName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                  ),
                ),
                if (location != null && location!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        DateFormat('dd/MM/yyyy').format(departure),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 7),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(returnDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  final int subtotal;
  final int discount;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071A3D), Color(0xFF073B78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 20,
                color: Colors.white70,
              ),
              SizedBox(width: 8),
              Text(
                'CHI TIẾT THANH TOÁN',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DarkSummaryRow(
            label: 'Tạm tính',
            value: CurrencyFormatter.format(subtotal),
          ),
          if (discount > 0) ...[
            const SizedBox(height: 9),
            _DarkSummaryRow(
              label: 'Ưu đãi',
              value: '-${CurrencyFormatter.format(discount)}',
              valueColor: const Color(0xFF70E59A),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Tổng thanh toán',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                CurrencyFormatter.format(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkSummaryRow extends StatelessWidget {
  const _DarkSummaryRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.provider,
    required this.onChanged,
  });

  final PaymentProvider provider;
  final ValueChanged<PaymentProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Phương thức thanh toán',
            style: AppTextStyles.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<PaymentProvider>(
            segments: const [
              ButtonSegment(
                value: PaymentProvider.vnpay,
                icon: Icon(Icons.credit_card_rounded),
                label: Text('VNPay'),
              ),
              ButtonSegment(
                value: PaymentProvider.momo,
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: Text('MoMo'),
              ),
            ],
            selected: {provider},
            onSelectionChanged: (values) => onChanged(values.first),
          ),
          const SizedBox(height: 10),
          Text(
            provider == PaymentProvider.vnpay
                ? 'Thanh toán qua cổng VNPay sandbox.'
                : 'Thanh toán theo luồng ứng dụng MoMo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
