import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/shell_controller.dart';
import '../../models/feature_models.dart';
import '../../routes/app_routes.dart';
import '../../utils/booking_args.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';
import '../../theme/app_colors.dart';
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
  String _payProvider = 'vnpay';
  var _initDone = false;
  var _initFailed = false;

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

    final result = await Get.toNamed(
      AppRoutes.payment,
      arguments: {
        'orderId': order.id,
        'amount': order.finalAmount,
        'provider': _payProvider,
      },
    );
    if (!mounted) return;
    final paid = result == true;
    Get.offAllNamed(AppRoutes.home);
    Get.find<ShellController>().changeTab(3);
    await Get.find<OrderController>().fetchOrders(refresh: true);
    if (paid == true) {
      SnackbarHelper.success('Thanh toán thành công');
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Voucher', style: AppTextStyles.textTheme.titleSmall),
          if (saved.isNotEmpty) ...[
            const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _voucherCodeController,
                  label: 'Mã voucher',
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _applyVoucherCode(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _booking.isApplyingVoucher.value
                      ? null
                      : () => _applyVoucherCode(),
                  child: _booking.isApplyingVoucher.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Áp dụng'),
                ),
              ),
            ],
          ),
          if (_booking.discountAmount.value > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Đã áp dụng ${_booking.voucherCode.value}: '
                    '-${CurrencyFormatter.format(_booking.discountAmount.value)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
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
        title: 'Thanh toán',
        body: LoadingWidget(message: 'Đang tải thông tin đặt tour...'),
      );
    }

    if (_initFailed || _booking.activeTickets.isEmpty) {
      return AppScreen(
        title: 'Thanh toán',
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
      title: 'Thanh toán',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CheckoutSummaryCard(
                tourName: _booking.checkoutTourName,
                imageUrl: _booking.checkoutTourImageUrl,
                location: _booking.checkoutTourLocation,
                departure: schedule.departureDate,
                returnDate: schedule.returnDate,
              ),
              const SizedBox(height: 20),
              Text('Chọn số lượng vé',
                  style: AppTextStyles.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_booking.ticketsLoading.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                ..._booking.activeTickets.map((t) {
                  final qty = _booking.ticketQty(t.id);
                  return IosSurfaceCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Loại vé #${t.ticketTypeId}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${CurrencyFormatter.format(t.price)} • Còn ${t.availableQuantity}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: qty > 0
                              ? () => _booking.decrementTicket(t.id)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$qty',
                          style: AppTextStyles.textTheme.titleMedium,
                        ),
                        IconButton(
                          onPressed: qty < t.availableQuantity
                              ? () => _booking.incrementTicket(t.id)
                              : null,
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppColors.brand),
                        ),
                      ],
                    ),
                  );
                }),
              if (_booking.totalPassengers > 0) ...[
                const SizedBox(height: 20),
                Text(
                  'Thông tin hành khách (${_booking.totalPassengers})',
                  style: AppTextStyles.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ..._passengers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return IosSurfaceCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Khách ${i + 1} • ${p.slot.ticketLabel}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: p.nameController,
                          label: 'Họ tên',
                          prefixIcon: Icons.person_outline_rounded,
                          validator: Validators.fullName,
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: p.dobController,
                          label: 'Ngày sinh (YYYY-MM-DD)',
                          prefixIcon: Icons.cake_outlined,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Nhập ngày sinh';
                            }
                            final d = DateTime.tryParse(v.trim());
                            if (d == null) return 'Định dạng không hợp lệ';
                            if (d.isAfter(DateTime.now())) {
                              return 'Ngày sinh không được ở tương lai';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: p.gender,
                          decoration:
                              const InputDecoration(labelText: 'Giới tính'),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Nam')),
                            DropdownMenuItem(
                                value: 'Female', child: Text('Nữ')),
                            DropdownMenuItem(
                                value: 'Other', child: Text('Khác')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => p.gender = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: p.nationalityController,
                          label: 'Quốc tịch',
                          hint: 'Vietnam',
                          prefixIcon: Icons.flag_outlined,
                          validator: Validators.nationality,
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              CustomTextField(
                controller: _noteController,
                label: 'Ghi chú đơn hàng (tuỳ chọn)',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildVoucherSection(),
              if (_booking.subtotal > 0) ...[
                const SizedBox(height: 12),
                IosSurfaceCard(
                  color: AppColors.brandLight,
                  child: Column(
                    children: [
                      _SummaryRow('Tạm tính',
                          CurrencyFormatter.format(_booking.subtotal)),
                      if (_booking.discountAmount.value > 0)
                        _SummaryRow(
                          'Giảm giá',
                          '-${CurrencyFormatter.format(_booking.discountAmount.value)}',
                        ),
                      const Divider(height: 20),
                      _SummaryRow(
                        'Tổng thanh toán',
                        CurrencyFormatter.format(_booking.finalAmount),
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Phương thức thanh toán',
                  style: AppTextStyles.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'vnpay', label: Text('VNPay')),
                  ButtonSegment(value: 'momo', label: Text('MoMo')),
                ],
                selected: {_payProvider},
                onSelectionChanged: (s) =>
                    setState(() => _payProvider = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn sẽ được chuyển sang cổng thanh toán (giống website). '
                'Chưa trừ tiền cho đến khi thanh toán thành công.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: 'Thanh toán ngay',
                isLoading: _booking.isLoading.value,
                onPressed: _booking.totalPassengers == 0 ? null : _submit,
              ),
            ],
          ),
        ),
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
    return IosSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tour, color: AppColors.brand),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tourName, style: AppTextStyles.textTheme.titleMedium),
                if (location != null && location!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(location!, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month,
                        size: 16, color: AppColors.brand),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${departure.toString().substring(0, 10)} → '
                        '${returnDate.toString().substring(0, 10)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? AppTextStyles.textTheme.titleMedium?.copyWith(color: AppColors.brand)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}
