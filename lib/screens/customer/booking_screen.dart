import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
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
  BookingPassengerInput slot;
  final nameController = TextEditingController();
  final idCardController = TextEditingController();
  final dobController = TextEditingController();
  String gender = 'Male';
  final nationalityController = TextEditingController(text: 'Vietnam');
  bool isFilled = false;

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
  bool _agreedToTerms = false;
  bool _isSummaryExpanded = true;

  @override
  void initState() {
    super.initState();
    final args = parseBookingArgs(Get.arguments);
    if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.error('sc_bk_select_schedule'.tr);
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

    // Tạo nhóm các form hiện tại theo ID vé
    final pool = <int, List<_PassengerForm>>{};
    for (final p in _passengers) {
      pool.putIfAbsent(p.slot.tourScheduleTicketId, () => []).add(p);
    }

    for (final slot in slots) {
      final matchingList = pool[slot.tourScheduleTicketId];
      if (matchingList != null && matchingList.isNotEmpty) {
        // Tái sử dụng form nếu cùng ID vé
        final form = matchingList.removeAt(0);
        form.slot = slot; // Cập nhật slot mới nhất
        next.add(form);
      } else {
        // Không có form cũ thì tạo mới
        next.add(_PassengerForm(slot));
      }
    }

    // Hủy các form bị thừa
    for (final list in pool.values) {
      for (final p in list) {
        p.dispose();
      }
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
      SnackbarHelper.error('sc_bk_select_ticket'.tr);
      return;
    }
    final allFilled = _passengers.every((p) => p.isFilled);
    if (!allFilled) {
      SnackbarHelper.error('sc_bk_fill_passenger_info'.tr);
      return;
    }
    if (!_agreedToTerms) {
      SnackbarHelper.error('sc_bk_agree_terms'.tr);
      return;
    }

    // Validate ages
    for (int i = 0; i < _passengers.length; i++) {
      final p = _passengers[i];
      final dob = DateTime.tryParse(p.dobController.text.trim());
      if (dob == null) continue;

      final ticket = _booking.tickets
          .firstWhereOrNull((t) => t.id == p.slot.tourScheduleTicketId);
      if (ticket == null) continue;

      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }

      final minAge = ticket.minAge ?? 0;
      final maxAge = ticket.maxAge ?? 0;
      final name = p.nameController.text.trim();
      final type = ticket.ticketTypeName ?? 'sc_bk_this_ticket'.tr;

      if (minAge > 0 && age < minAge) {
        SnackbarHelper.error(
            'sc_bk_age_too_young'.trParams({'num': (i + 1).toString(), 'name': name, 'minAge': minAge.toString(), 'type': type}));
        return;
      }
      if (maxAge > 0 && age > maxAge) {
        SnackbarHelper.error(
            'sc_bk_age_too_old'.trParams({'num': (i + 1).toString(), 'name': name, 'maxAge': maxAge.toString(), 'type': type}));
        return;
      }
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
      helpText: 'sc_bk_select_dob'.tr,
      cancelText: 'sc_bk_cancel'.tr,
      confirmText: 'sc_bk_select'.tr,
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
      SnackbarHelper.error('sc_bk_select_ticket_first'.tr);
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

  String _voucherDiscountText(VoucherModel voucher) {
    final value = voucher.discountValue ?? 0;
    final type = voucher.discountType?.toLowerCase() ?? '';
    if (type.contains('percent')) return '-$value%';
    return '-${CurrencyFormatter.format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone) {
      return AppScreen(
        title: 'sc_bk_book_tour'.tr,
        body: LoadingWidget(message: 'sc_bk_loading_info'.tr),
      );
    }

    if (_initFailed || _booking.activeTickets.isEmpty) {
      return AppScreen(
        title: 'sc_bk_book_tour'.tr,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_busy,
                    size: 48, color: AppColors.textSecondary),
                SizedBox(height: 12),
                Text(
                  'sc_bk_no_tickets'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  label: 'sc_bk_back_to_tour'.tr,
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
      title: 'sc_bk_book_tour'.tr,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOrderSummaryHeader(),
              if (_isSummaryExpanded) _buildOrderSummaryContent(),
              _buildVoucherRow(),
              _buildTermsCheckbox(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'sc_bk_total_price'.tr,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          CurrencyFormatter.format(_booking.finalAmount),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE31837),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE31837),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                      onPressed: _booking.totalPassengers == 0 ? null : _submit,
                      child: _booking.isLoading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'sc_bk_book_now'.tr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Tour summary card ---
              _CheckoutSummaryCard(
                tourName: _booking.checkoutTourName,
                imageUrl: _booking.checkoutTourImageUrl,
                location: _booking.checkoutTourLocation,
                departure: schedule.departureDate,
                returnDate: schedule.returnDate,
              ),
              const SizedBox(height: 20),

              // --- Section label: Chọn vé ---
              Text(
                'sc_bk_ticket_type'.tr,
                style: AppTextStyles.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 10),
              if (_booking.ticketsLoading.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0;
                          i < _booking.activeTickets.length;
                          i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.border),
                        Builder(builder: (ctx) {
                          final t = _booking.activeTickets[i];
                          final qty = _booking.ticketQty(t.id);

                          String fullName =
                              _booking.ticketTypeName(t.ticketTypeId);
                          String name = fullName;
                          String subtitle = '';
                          if (fullName.contains(' (')) {
                            final parts = fullName.split(' (');
                            name = parts[0];
                            subtitle = parts
                                .sublist(1)
                                .join(' (')
                                .replaceAll(')', '')
                                .trim();
                          }

                          return _TicketQuantityRow(
                            name: name,
                            subtitle: subtitle,
                            price: t.effectivePrice,
                            originalPrice: t.price,
                            available: t.availableQuantity,
                            quantity: qty,
                            onDecrease: qty > 0
                                ? () => _booking.decrementTicket(t.id)
                                : null,
                            onIncrease: qty < t.availableQuantity
                                ? () => _booking.incrementTicket(t.id)
                                : null,
                          );
                        }),
                      ],
                    ],
                  ),
                ),

              // --- Section label: Hành khách ---
              if (_booking.totalPassengers > 0) ...[
                const SizedBox(height: 20),
                _buildSectionLabel(
                  'sc_bk_passenger_info'.tr,
                  subtitle:
                      _booking.totalPassengers.toString() + ' ' + 'sc_bk_people_ebill'.tr,
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _passengers.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.border),
                        Builder(
                          builder: (ctx) {
                            final p = _passengers[i];
                            return InkWell(
                              borderRadius: i == 0
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(16))
                                  : (i == _passengers.length - 1
                                      ? const BorderRadius.vertical(
                                          bottom: Radius.circular(16))
                                      : BorderRadius.zero),
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (context) => _PassengerFormSheet(
                                    passengerIndex: i,
                                    form: p,
                                    onPickDate: () => _pickDateOfBirth(p),
                                    onSave: () {
                                      setState(() {
                                        p.isFilled = true;
                                      });
                                    },
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: p.isFilled
                                            ? AppColors.brand
                                            : Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: p.isFilled
                                          ? const Icon(Icons.check_rounded,
                                              color: Colors.white, size: 18)
                                          : Text(
                                              '${i + 1}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.isFilled
                                                ? p.nameController.text
                                                    .toUpperCase()
                                                : 'sc_bk_passenger_num'.trParams({'num': (i + 1).toString()}),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: p.isFilled
                                                  ? AppColors.textPrimary
                                                  : Colors.orange,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            p.isFilled
                                                ? '${p.slot.ticketLabel} • ${p.idCardController.text}'
                                                : 'sc_bk_tap_to_fill'.tr,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: p.isFilled
                                          ? AppColors.textSecondary
                                          : Colors.orange,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // --- Ghi chú ---
              const SizedBox(height: 20),
              Text(
                'sc_bk_note'.tr,
                style: AppTextStyles.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'sc_bk_note_hint'.tr,
                  hintStyle: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        const BorderSide(color: AppColors.brand, width: 1.5),
                  ),
                ),
              ),

              // --- Phương thức thanh toán ---
              const SizedBox(height: 20),
              _buildSectionLabel('sc_bk_payment_method'.tr),
              const SizedBox(height: 10),
              /* MoMo Temporarily disabled
              SegmentedButton<PaymentProvider>(...);
              */
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border:
                      Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () {
                    // Currently VNPay is the only option, already selected.
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F5FF),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: const Icon(Icons.credit_card_rounded,
                              color: AppColors.brand),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'sc_bk_vnpay'.tr,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'sc_bk_vnpay_desc'.tr,
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.brand),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildOrderSummaryHeader() {
    return InkWell(
      onTap: () {
        setState(() {
          _isSummaryExpanded = !_isSummaryExpanded;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF0055A5),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'sc_bk_order_summary'.tr,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Icon(
              _isSummaryExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryContent() {
    final tickets = _booking.tickets;
    final quantities = _booking.ticketQuantities;
    final activeTickets =
        tickets.where((t) => (quantities[t.id] ?? 0) > 0).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline,
                      color: Color(0xFF0055A5), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'sc_bk_customer_caps'.tr,
                    style: TextStyle(
                      color: Color(0xFF0055A5),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                CurrencyFormatter.format(_booking.subtotal),
                style: const TextStyle(
                  color: Color(0xFFE31837),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activeTickets.map((t) {
            final q = quantities[t.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _booking.ticketTypeName(t.ticketTypeId),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$q x ${CurrencyFormatter.format(t.effectivePrice)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              150 ~/ 3,
              (index) => Expanded(
                child: Container(
                  color: index % 2 == 0 ? Colors.transparent : AppColors.border,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherRow() {
    // We can use _usableSavedVouchers if we add it back, but wait, the previous code had `_usableSavedVouchers` property.
    // I can just access it.
    final saved = _usableSavedVouchers;
    final selectedCode = _booking.voucherCode.value;
    return InkWell(
      onTap: () => _showVoucherSheet(saved, selectedCode),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.local_offer_outlined,
                size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'sc_bk_discount_code'.tr,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            _booking.discountAmount.value > 0
                ? Text(
                    '-${CurrencyFormatter.format(_booking.discountAmount.value)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  )
                : Row(
                    children: [
                      Text(
                        'sc_bk_add_discount'.tr,
                        style: TextStyle(
                          color: Color(0xFF0055A5),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.add_circle_outline,
                          color: Color(0xFF0055A5), size: 16),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreedToTerms,
              activeColor: const Color(0xFF0055A5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xs)),
              onChanged: (val) {
                setState(() {
                  _agreedToTerms = val ?? false;
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Colors.black87, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: 'sc_bk_i_agree_with'.tr),
                  TextSpan(
                    text: 'sc_bk_policy'.tr,
                    style: const TextStyle(
                        color: Color(0xFF0055A5), fontWeight: FontWeight.bold),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Get.toNamed(AppRoutes.bookingTerms),
                  ),
                  TextSpan(text: 'sc_bk_data_protection_and'.tr),
                  TextSpan(
                    text: 'sc_bk_terms'.tr,
                    style: const TextStyle(
                        color: Color(0xFF0055A5), fontWeight: FontWeight.bold),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Get.toNamed(AppRoutes.bookingTerms),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVoucherSheet(List<VoucherModel> saved, String selectedCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _KeyboardAvoidingPadding(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'sc_bk_discount_code'.tr,
                      style: AppTextStyles.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (saved.isNotEmpty) ...[
                Text('sc_bk_your_voucher'.tr,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: saved.map((voucher) {
                    final selected = selectedCode == voucher.code;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(
                          '${voucher.code} • ${_voucherDiscountText(voucher)}'),
                      onSelected: _booking.isApplyingVoucher.value
                          ? null
                          : (_) {
                              _selectSavedVoucher(voucher);
                              Navigator.pop(ctx);
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'sc_bk_enter_voucher'.tr,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _voucherCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _popupInputDecoration(
                      hint: 'sc_bk_voucher_example'.tr,
                      prefixIcon: Icons.confirmation_number_outlined,
                    ),
                    onFieldSubmitted: (_) {
                      _applyVoucherCode();
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  onPressed: _booking.isApplyingVoucher.value
                      ? null
                      : () {
                          _applyVoucherCode();
                          Navigator.pop(ctx);
                        },
                  child: _booking.isApplyingVoucher.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('sc_bk_apply'.tr,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color:
                valueColor ?? (isBold ? AppColors.navy : AppColors.textPrimary),
            fontSize: isBold ? 16 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TicketQuantityRow extends StatelessWidget {
  const _TicketQuantityRow({
    required this.name,
    required this.subtitle,
    required this.price,
    required this.originalPrice,
    required this.available,
    required this.quantity,
    this.onDecrease,
    this.onIncrease,
  });

  final String name;
  final String subtitle;
  final int price;
  final int originalPrice;
  final int available;
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                if (subtitle.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.info_outline_rounded,
                          size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    if (price < originalPrice)
                      Text(
                        '${CurrencyFormatter.format(originalPrice)} ',
                        style: const TextStyle(
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    Text(
                      CurrencyFormatter.format(price),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onDecrease,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Icon(Icons.remove_rounded,
                        size: 18,
                        color: onDecrease != null ? Colors.black : Colors.grey),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                InkWell(
                  onTap: onIncrease,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Icon(Icons.add_rounded,
                        size: 18,
                        color: onIncrease != null ? Colors.black : Colors.grey),
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
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'sc_bk_selected_schedule'.tr,
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
                    borderRadius: BorderRadius.circular(AppRadius.sm),
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

class _PassengerFormSheet extends StatefulWidget {
  const _PassengerFormSheet({
    required this.passengerIndex,
    required this.form,
    required this.onPickDate,
    required this.onSave,
  });

  final int passengerIndex;
  final _PassengerForm form;
  final VoidCallback onPickDate;
  final VoidCallback onSave;

  @override
  State<_PassengerFormSheet> createState() => _PassengerFormSheetState();
}

class _PassengerFormSheetState extends State<_PassengerFormSheet> {
  final _localFormKey = GlobalKey<FormState>();

  static List<String>? _cachedCountries;
  List<String> _countries = [];
  bool _isLoadingCountries = false;

  @override
  void initState() {
    super.initState();
    if (widget.form.nationalityController.text.isEmpty) {
      widget.form.nationalityController.text = 'Vietnam';
    }
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    if (_cachedCountries != null) {
      if (mounted) {
        setState(() {
          _countries = _cachedCountries!;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingCountries = true;
      });
    }

    try {
      final dio = Dio();
      final response =
          await dio.get('https://countriesnow.space/api/v0.1/countries/iso');
      final data = response.data['data'] as List;
      final List<String> list = data.map((e) => e['name'].toString()).toList();
      list.sort();
      _cachedCountries = list;
      if (mounted) {
        setState(() {
          _countries = list;
          _isLoadingCountries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCountries = false;
          _countries = [
            'Vietnam',
            'United States',
            'United Kingdom',
            'Japan',
            'South Korea',
            'China'
          ];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _KeyboardAvoidingPadding(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _localFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'sc_bk_passenger_num'.trParams({'num': (widget.passengerIndex + 1).toString()}),
                        style: AppTextStyles.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text(
                  widget.form.slot.ticketLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),
                _buildPopupTextField(
                  controller: widget.form.nameController,
                  label: 'sc_bk_full_name'.tr,
                  hint: 'sc_bk_enter_name'.tr,
                  prefixIcon: Icons.person_outline_rounded,
                  validator: Validators.fullName,
                ),
                const SizedBox(height: 16),
                _buildPopupTextField(
                  controller: widget.form.idCardController,
                  label: 'sc_bk_id_card'.tr,
                  hint: 'sc_bk_enter_id'.tr,
                  prefixIcon: Icons.badge_outlined,
                  keyboardType: TextInputType.text,
                  maxLength: 20,
                  validator: Validators.idCard,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildPopupTextField(
                        controller: widget.form.dobController,
                        label: 'sc_bk_dob'.tr,
                        hint: 'YYYY-MM-DD',
                        prefixIcon: Icons.cake_outlined,
                        readOnly: true,
                        onTap: widget.onPickDate,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'sc_bk_required'.tr;
                          }
                          final d = DateTime.tryParse(v.trim());
                          if (d == null) return 'sc_bk_invalid_format'.tr;
                          if (d.isAfter(DateTime.now())) return 'sc_bk_error'.tr;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'sc_bk_gender'.tr,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: widget.form.gender,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary),
                            decoration: _popupInputDecoration(
                              prefixIcon: Icons.wc_rounded,
                              hint: 'sc_bk_select'.tr,
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 'Male',
                                  child: Text('Nam',
                                      style: TextStyle(fontSize: 14))),
                              DropdownMenuItem(
                                  value: 'Female',
                                  child: Text('sc_bk_female'.tr,
                                      style: TextStyle(fontSize: 14))),
                              DropdownMenuItem(
                                  value: 'Other',
                                  child: Text('sc_bk_other_gender'.tr,
                                      style: TextStyle(fontSize: 14))),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => widget.form.gender = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'sc_bk_nationality'.tr,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingCountries
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ))
                        : DropdownButtonFormField<String>(
                            value: _countries.contains(
                                    widget.form.nationalityController.text)
                                ? widget.form.nationalityController.text
                                : (_countries.isNotEmpty
                                    ? _countries.first
                                    : null),
                            isExpanded: true,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textPrimary),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary),
                            decoration: _popupInputDecoration(
                              prefixIcon: Icons.flag_outlined,
                              hint: 'sc_bk_select_country'.tr,
                            ),
                            items: _countries
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                widget.form.nationalityController.text = v;
                              }
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'sc_bk_required'.tr;
                              return null;
                            },
                          ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  onPressed: () {
                    if (_localFormKey.currentState?.validate() ?? false) {
                      widget.onSave();
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    'sc_bk_save_info'.tr,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          onTap: onTap,
          readOnly: readOnly,
          decoration: _popupInputDecoration(hint: hint, prefixIcon: prefixIcon),
        ),
      ],
    );
  }
}

InputDecoration _popupInputDecoration({String? hint, IconData? prefixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, color: AppColors.textSecondary, size: 20)
        : null,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    counterText: '',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}

class _KeyboardAvoidingPadding extends StatelessWidget {
  const _KeyboardAvoidingPadding({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}