import 'package:get/get.dart';

/// Tập hợp validator dùng chung cho mọi form.
class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
  // VN: 0xxxxxxxxx (10 số) hoặc +84xxxxxxxxx.
  static final _phoneRegex = RegExp(r'^(0\d{9}|\+84\d{9})$');

  /// Khớp RegisterDTO / ChangePasswordDTO / ResetPasswordDTO trên AuthAPI.
  static final _backendPasswordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
  );

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'val_email_req'.tr;
    if (!_emailRegex.hasMatch(v)) return 'val_email_invalid'.tr;
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'val_pass_req'.tr;
    if (v.length < 8) return 'val_pass_min'.tr;
    return null;
  }

  /// Mật khẩu theo backend: ≥8 ký tự, hoa + thường + số + ký tự đặc biệt (@$!%*?&).
  static String? strongPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'val_pass_req'.tr;
    if (!_backendPasswordRegex.hasMatch(v)) {
      return 'val_pass_strong'.tr;
    }
    return null;
  }

  static String? requiredField(String? value, {String label = 'Trường này'}) {
    if (value == null || value.trim().isEmpty) {
      return 'val_req_field'.trParams({'label': label});
    }
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'val_name_req'.tr;
    if (v.length < 2) return 'val_name_short'.tr;
    if (v.length > 100) return 'val_name_long'.tr;
    return null;
  }

  static String? nationality(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'val_nat_req'.tr;
    return null;
  }

  /// Mã voucher khách: 3–50 ký tự, [A-Za-z0-9_-].
  static String? voucherCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'val_voucher_req'.tr;
    if (v.length < 3 || v.length > 50) {
      return 'val_voucher_len'.tr;
    }
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v)) {
      return 'val_voucher_fmt'.tr;
    }
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'val_phone_req'.tr;
    if (!_phoneRegex.hasMatch(v)) {
      return 'val_phone_invalid'.tr;
    }
    return null;
  }

  /// CMND/CCCD/Passport, tối đa 20 ký tự.
  static String? idCard(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'val_id_req'.tr;
    if (v.length > 20) {
      return 'val_id_long'.tr;
    }
    return null;
  }

  static String? code(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'val_code_req'.tr;
    if (v.length < 4) return 'val_code_invalid'.tr;
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
    if (value == null || value.isEmpty) {
      return 'val_pass_conf_req'.tr;
    }
    if (value != password) return 'val_pass_conf_unmatch'.tr;
    return null;
  }
}
}
