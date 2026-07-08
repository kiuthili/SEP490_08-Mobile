/// Tập hợp validator dùng chung cho mọi form (tiếng Việt).
class Validators {
  Validators._();

  static final _emailRegex =
      RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
  // VN: 0xxxxxxxxx (10 số) hoặc +84xxxxxxxxx.
  static final _phoneRegex = RegExp(r'^(0\d{9}|\+84\d{9})$');

  /// Khớp RegisterDTO / ChangePasswordDTO / ResetPasswordDTO trên AuthAPI.
  static final _backendPasswordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
  );

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập email';
    if (!_emailRegex.hasMatch(v)) return 'Email không hợp lệ';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    return null;
  }

  /// Mật khẩu theo backend: ≥8 ký tự, hoa + thường + số + ký tự đặc biệt (@$!%*?&).
  static String? strongPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (!_backendPasswordRegex.hasMatch(v)) {
      return r'Mật khẩu cần ≥8 ký tự, có chữ hoa, chữ thường, số và ký tự @$!%*?&';
    }
    return null;
  }

  static String? requiredField(String? value, {String label = 'Trường này'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label không được để trống';
    }
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập họ tên';
    if (v.length < 2) return 'Họ tên quá ngắn';
    if (v.length > 100) return 'Họ tên tối đa 100 ký tự';
    return null;
  }

  static String? nationality(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập quốc tịch';
    return null;
  }

  /// Mã voucher khách: 3–50 ký tự, [A-Za-z0-9_-].
  static String? voucherCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mã voucher';
    if (v.length < 3 || v.length > 50) {
      return 'Mã voucher phải từ 3–50 ký tự';
    }
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v)) {
      return 'Mã chỉ gồm chữ, số, _ hoặc -';
    }
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập số điện thoại';
    if (!_phoneRegex.hasMatch(v)) {
      return 'SĐT không hợp lệ (vd: 0901234567)';
    }
    return null;
  }

  /// CMND/CCCD/Passport, tối đa 20 ký tự.
  static String? idCard(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập CMND/CCCD/Passport';
    if (v.length > 20) {
      return 'Số giấy tờ không được vượt quá 20 ký tự';
    }
    return null;
  }

  static String? code(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mã xác nhận';
    if (v.length < 4) return 'Mã xác nhận không hợp lệ';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu';
    }
    if (value != password) return 'Mật khẩu xác nhận không khớp';
    return null;
  }
}
