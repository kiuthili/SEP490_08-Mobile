import 'dart:io';

void main() {
  final enKeys = {
    'sc_bk_select_schedule': 'Please select a departure schedule before booking',
    'sc_bk_select_ticket': 'Please select at least one ticket',
    'sc_bk_fill_passenger_info': 'Please fill in all passenger information',
    'sc_bk_agree_terms': 'Please agree to the Booking & Cancellation Policy',
    'sc_bk_this_ticket': 'this ticket type',
    'sc_bk_select_dob': 'SELECT DATE OF BIRTH',
    'sc_bk_cancel': 'Cancel',
    'sc_bk_select': 'Select',
    'sc_bk_select_ticket_first': 'Select tickets before applying a voucher',
    'sc_bk_book_tour': 'Book Tour',
    'sc_bk_loading_info': 'Loading booking information...',
    'sc_bk_no_tickets': 'No tickets available for this schedule',
    'sc_bk_back_to_tour': 'Back to tour',
    'sc_bk_total_price': 'Total price:',
    'sc_bk_book_now': 'Book now',
    'sc_bk_ticket_type': 'Ticket Type',
    'sc_bk_passenger_info': 'Passenger Information',
    'sc_bk_tap_to_fill': 'Tap to fill information',
    'sc_bk_note': 'Note',
    'sc_bk_note_hint': 'Enter note for order (optional)...',
    'sc_bk_payment_method': 'Payment Method',
    'sc_bk_vnpay': 'Pay via VNPay',
    'sc_bk_vnpay_desc': 'Supports domestic & international cards',
    'sc_bk_order_summary': 'Order Summary',
    'sc_bk_customer_caps': 'CUSTOMER',
    'sc_bk_discount_code': 'Discount Code',
    'sc_bk_add_discount': 'Add discount code',
    'sc_bk_i_agree_with': 'I agree with the ',
    'sc_bk_policy': 'Policy',
    'sc_bk_data_protection_and': ' on data protection and ',
    'sc_bk_terms': 'terms.',
    'sc_bk_your_voucher': 'Your Voucher',
    'sc_bk_enter_voucher': 'Enter voucher code',
    'sc_bk_voucher_example': 'Example: SUMMER2024',
    'sc_bk_apply': 'Apply',
    'sc_bk_selected_schedule': 'Selected Schedule',
    'sc_bk_full_name': 'Full Name',
    'sc_bk_enter_name': 'Enter passenger name',
    'sc_bk_id_card': 'ID Card/Passport',
    'sc_bk_enter_id': 'Enter ID number',
    'sc_bk_dob': 'Date of Birth',
    'sc_bk_required': 'Required',
    'sc_bk_invalid_format': 'Invalid format',
    'sc_bk_error': 'Error',
    'sc_bk_gender': 'Gender',
    'sc_bk_female': 'Female',
    'sc_bk_other_gender': 'Other',
    'sc_bk_nationality': 'Nationality',
    'sc_bk_select_country': 'Select country',
    'sc_bk_save_info': 'Save Information',
    'sc_bk_people_ebill': 'people • used for e-ticket issuance',
    'sc_bk_passenger_num': 'Passenger @num',
    'sc_bk_age_too_young': 'Passenger @num (@name) is under @minAge, cannot buy @type',
    'sc_bk_age_too_old': 'Passenger @num (@name) is over @maxAge, cannot buy @type',
  };

  final viKeys = {
    'sc_bk_select_schedule': 'Vui lòng chọn lịch khởi hành trước khi đặt tour',
    'sc_bk_select_ticket': 'Chọn ít nhất một vé',
    'sc_bk_fill_passenger_info': 'Vui lòng điền đầy đủ thông tin hành khách',
    'sc_bk_agree_terms': 'Vui lòng đồng ý với Quy định đặt tour & Hủy vé',
    'sc_bk_this_ticket': 'loại vé này',
    'sc_bk_select_dob': 'CHỌN NGÀY SINH',
    'sc_bk_cancel': 'Hủy',
    'sc_bk_select': 'Chọn',
    'sc_bk_select_ticket_first': 'Chọn vé trước khi áp dụng voucher',
    'sc_bk_book_tour': 'Đặt tour',
    'sc_bk_loading_info': 'Đang tải thông tin đặt tour...',
    'sc_bk_no_tickets': 'Lịch này chưa có vé bán',
    'sc_bk_back_to_tour': 'Quay lại tour',
    'sc_bk_total_price': 'Tổng tiền:',
    'sc_bk_book_now': 'Đặt ngay',
    'sc_bk_ticket_type': 'Loại vé',
    'sc_bk_passenger_info': 'Thông tin hành khách',
    'sc_bk_tap_to_fill': 'Chạm để điền thông tin',
    'sc_bk_note': 'Ghi chú',
    'sc_bk_note_hint': 'Nhập ghi chú cho đơn hàng (tuỳ chọn)...',
    'sc_bk_payment_method': 'Phương thức thanh toán',
    'sc_bk_vnpay': 'Thanh toán qua VNPay',
    'sc_bk_vnpay_desc': 'Hỗ trợ thẻ nội địa & quốc tế',
    'sc_bk_order_summary': 'Tóm tắt đơn hàng',
    'sc_bk_customer_caps': 'KHÁCH HÀNG',
    'sc_bk_discount_code': 'Mã giảm giá',
    'sc_bk_add_discount': 'Thêm mã giảm giá',
    'sc_bk_i_agree_with': 'Tôi đồng ý với ',
    'sc_bk_policy': 'Chính sách',
    'sc_bk_data_protection_and': ' bảo vệ dữ liệu cá nhân và ',
    'sc_bk_terms': 'các điều khoản.',
    'sc_bk_your_voucher': 'Voucher của bạn',
    'sc_bk_enter_voucher': 'Nhập mã voucher',
    'sc_bk_voucher_example': 'Ví dụ: SUMMER2024',
    'sc_bk_apply': 'Áp dụng',
    'sc_bk_selected_schedule': 'Lịch đã chọn',
    'sc_bk_full_name': 'Họ và tên',
    'sc_bk_enter_name': 'Nhập họ tên hành khách',
    'sc_bk_id_card': 'CMND/CCCD/Hộ chiếu',
    'sc_bk_enter_id': 'Nhập số giấy tờ tuỳ thân',
    'sc_bk_dob': 'Ngày sinh',
    'sc_bk_required': 'Bắt buộc',
    'sc_bk_invalid_format': 'Sai Đ/dạng',
    'sc_bk_error': 'Lỗi',
    'sc_bk_gender': 'Giới tính',
    'sc_bk_female': 'Nữ',
    'sc_bk_other_gender': 'Khác',
    'sc_bk_nationality': 'Quốc tịch',
    'sc_bk_select_country': 'Chọn quốc gia',
    'sc_bk_save_info': 'Lưu thông tin',
    'sc_bk_people_ebill': 'người • dùng để xuất vé điện tử',
    'sc_bk_passenger_num': 'Hành khách @num',
    'sc_bk_age_too_young': 'Hành khách @num (@name) chưa đủ @minAge tuổi để mua @type',
    'sc_bk_age_too_old': 'Hành khách @num (@name) vượt quá @maxAge tuổi, không thể mua @type',
  };

  final transFile = File('lib/utils/app_translations.dart');
  var trans = transFile.readAsStringSync();
  
  final enStr = enKeys.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Log out'", "          'pt_logout': 'Log out',\n$enStr");

  final viStr = viKeys.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Đăng xuất'", "          'pt_logout': 'Đăng xuất',\n$viStr");
  
  transFile.writeAsStringSync(trans);
  
  final file = File('lib/screens/customer/booking_screen.dart');
  var text = file.readAsStringSync();
  
  final replaceMap = {
    "'Vui lòng chọn lịch khởi hành trước khi đặt tour'": "'sc_bk_select_schedule'.tr",
    "'Chọn ít nhất một vé'": "'sc_bk_select_ticket'.tr",
    "'Vui lòng điền đầy đủ thông tin hành khách'": "'sc_bk_fill_passenger_info'.tr",
    "'Vui lòng đồng ý với Quy định đặt tour & Hủy vé'": "'sc_bk_agree_terms'.tr",
    "'loại vé này'": "'sc_bk_this_ticket'.tr",
    "'CHỌN NGÀY SINH'": "'sc_bk_select_dob'.tr",
    "'Hủy'": "'sc_bk_cancel'.tr",
    "'Chọn'": "'sc_bk_select'.tr",
    "'Chọn vé trước khi áp dụng voucher'": "'sc_bk_select_ticket_first'.tr",
    "'Đặt tour'": "'sc_bk_book_tour'.tr",
    "'Đang tải thông tin đặt tour...'": "'sc_bk_loading_info'.tr",
    "'Lịch này chưa có vé bán'": "'sc_bk_no_tickets'.tr",
    "'Quay lại tour'": "'sc_bk_back_to_tour'.tr",
    "'Tổng tiền:'": "'sc_bk_total_price'.tr",
    "'Đặt ngay'": "'sc_bk_book_now'.tr",
    "'Loại vé'": "'sc_bk_ticket_type'.tr",
    "'Thông tin hành khách'": "'sc_bk_passenger_info'.tr",
    "'Chạm để điền thông tin'": "'sc_bk_tap_to_fill'.tr",
    "'Ghi chú'": "'sc_bk_note'.tr",
    "'Nhập ghi chú cho đơn hàng (tuỳ chọn)...'": "'sc_bk_note_hint'.tr",
    "'Phương thức thanh toán'": "'sc_bk_payment_method'.tr",
    "'Thanh toán qua VNPay'": "'sc_bk_vnpay'.tr",
    "'Hỗ trợ thẻ nội địa & quốc tế'": "'sc_bk_vnpay_desc'.tr",
    "'Tóm tắt đơn hàng'": "'sc_bk_order_summary'.tr",
    "'KHÁCH HÀNG'": "'sc_bk_customer_caps'.tr",
    "'Mã giảm giá'": "'sc_bk_discount_code'.tr",
    "'Thêm mã giảm giá'": "'sc_bk_add_discount'.tr",
    "'Tôi đồng ý với '": "'sc_bk_i_agree_with'.tr",
    "'Chính sách'": "'sc_bk_policy'.tr",
    "' bảo vệ dữ liệu cá nhân và '": "'sc_bk_data_protection_and'.tr",
    "'các điều khoản.'": "'sc_bk_terms'.tr",
    "'Voucher của bạn'": "'sc_bk_your_voucher'.tr",
    "'Nhập mã voucher'": "'sc_bk_enter_voucher'.tr",
    "'Ví dụ: SUMMER2024'": "'sc_bk_voucher_example'.tr",
    "'Áp dụng'": "'sc_bk_apply'.tr",
    "'Lịch đã chọn'": "'sc_bk_selected_schedule'.tr",
    "'Họ và tên'": "'sc_bk_full_name'.tr",
    "'Nhập họ tên hành khách'": "'sc_bk_enter_name'.tr",
    "'CMND/CCCD/Hộ chiếu'": "'sc_bk_id_card'.tr",
    "'Nhập số giấy tờ tuỳ thân'": "'sc_bk_enter_id'.tr",
    "'Ngày sinh'": "'sc_bk_dob'.tr",
    "'Bắt buộc'": "'sc_bk_required'.tr",
    "'Sai Đ/dạng'": "'sc_bk_invalid_format'.tr",
    "'Lỗi'": "'sc_bk_error'.tr",
    "'Giới tính'": "'sc_bk_gender'.tr",
    "'Nữ'": "'sc_bk_female'.tr",
    "'Khác'": "'sc_bk_other_gender'.tr",
    "'Quốc tịch'": "'sc_bk_nationality'.tr",
    "'Chọn quốc gia'": "'sc_bk_select_country'.tr",
    "'Lưu thông tin'": "'sc_bk_save_info'.tr",
    
    // interpolated strings
    "'Hành khách \${i + 1} (\$name) chưa đủ \$minAge tuổi để mua \$type'": "'sc_bk_age_too_young'.trParams({'num': (i + 1).toString(), 'name': name, 'minAge': minAge.toString(), 'type': type})",
    "'Hành khách \${i + 1} (\$name) vượt quá \$maxAge tuổi, không thể mua \$type'": "'sc_bk_age_too_old'.trParams({'num': (i + 1).toString(), 'name': name, 'maxAge': maxAge.toString(), 'type': type})",
    "'\${_booking.totalPassengers} người • dùng để xuất vé điện tử'": "_booking.totalPassengers.toString() + ' ' + 'sc_bk_people_ebill'.tr",
    "'Hành khách \${i + 1}'": "'sc_bk_passenger_num'.trParams({'num': (i + 1).toString()})",
    "'Hành khách \${widget.passengerIndex + 1}'": "'sc_bk_passenger_num'.trParams({'num': (widget.passengerIndex + 1).toString()})",
  };
  
  for (final entry in replaceMap.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  
  // Try to clean up some common const_eval_extension_method errors by replacing const before elements that contain '.tr'
  // Actually, we'll run a regex that removes 'const ' if it's placed before 'Text(' and the text contains .tr
  text = text.replaceAll("const Text('sc_bk", "Text('sc_bk");
  
  // Specific consts that often wrap Text
  text = text.replaceAll("const LoadingWidget(message: 'sc_bk_loading_info'.tr)", "LoadingWidget(message: 'sc_bk_loading_info'.tr)");

  file.writeAsStringSync(text);
  print('Done translating booking_screen.dart.');
}
