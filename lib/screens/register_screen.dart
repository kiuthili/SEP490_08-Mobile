import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import '../widgets/auth_page_layout.dart';
import '../widgets/auth_widgets.dart';

enum _RegisterStep { info, verifyOtp }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  late final AuthController _auth;
  var _acceptedTerms = false;
  var _step = _RegisterStep.info;
  var _sendingOtp = false;
  var _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown([int seconds = 60]) {
    _timer?.cancel();
    if (mounted) setState(() => _countdown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_sendingOtp || _auth.isLoading.value) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý điều khoản trước khi đăng ký'),
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();

    final fullNameRegex = RegExp(
      r'^[a-zA-Z0-9\sÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚĂĐĨŨƠàáâãèéêìíòóôõùúăđĩũơƯĂẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼỀỀỂưăạảấầẩẫậắằẳẵặẹẻẽềềểỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪễệỉịọỏốồổỗộớờởỡợụủứừỬỮỰỲỴÝỶỸửữựỳỵỷỹ]+$',
    );
    if (!fullNameRegex.hasMatch(fullName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Họ và tên không được chứa ký tự đặc biệt hoặc biểu tượng'),
        ),
      );
      return;
    }
    if (phone.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số điện thoại tối đa 15 chữ số')),
      );
      return;
    }
    if (!RegExp(r'^[0-9+()\- ]{8,15}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Định dạng số điện thoại không hợp lệ')),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu không khớp!')),
      );
      return;
    }

    setState(() => _sendingOtp = true);
    try {
      final result = await _auth.sendRegisterOtp(
        email: _emailController.text.trim(),
        fullName: fullName,
      );
      if (result != null && result.retryAfterSeconds != null) {
        _startCountdown(result.retryAfterSeconds!);
        return;
      }
      if (result != null) {
        _startCountdown(60);
        if (mounted) setState(() => _step = _RegisterStep.verifyOtp);
      }
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _resendCode() async {
    if (_sendingOtp || _auth.isLoading.value || _countdown > 0) return;
    setState(() => _sendingOtp = true);
    try {
      final result = await _auth.sendRegisterOtp(
        email: _emailController.text.trim(),
        fullName: _fullNameController.text.trim(),
      );
      if (result != null) {
        final seconds = result.retryAfterSeconds ?? 60;
        _startCountdown(seconds);
      }
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _completeRegister() async {
    if (_auth.isLoading.value) return;
    if (_otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã xác minh')),
      );
      return;
    }
    await _auth.register(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      otpCode: _otpController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      showBack: true,
      headerSubtitle: 'YOUR JOURNEY · YOUR VALUE',
      title: _step == _RegisterStep.info ? 'Tạo tài khoản 🎉' : 'Xác nhận OTP',
      subtitle: _step == _RegisterStep.info
          ? 'Điền thông tin bên dưới để tham gia StayHub.'
          : 'Mã xác nhận 6 chữ số đã được gửi đến email của bạn.',
      footer: _step == _RegisterStep.info ? _LoginFooter() : null,
      body: Form(
        key: _formKey,
        child: _step == _RegisterStep.info
            ? _buildInfoForm()
            : _buildVerifyOtpForm(),
      ),
    );
  }

  Widget _buildInfoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthInputField(
          controller: _fullNameController,
          label: 'Họ và tên',
          hint: 'Nhập họ và tên đầy đủ',
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          validator: Validators.fullName,
        ),
        const SizedBox(height: 14),
        AuthInputField(
          controller: _emailController,
          label: 'Email',
          hint: 'Nhập địa chỉ email',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: Validators.email,
        ),
        const SizedBox(height: 14),
        _PhoneInputField(controller: _phoneController),
        const SizedBox(height: 14),
        AuthInputField(
          controller: _passwordController,
          label: 'Mật khẩu',
          hint: 'Tối thiểu 8 ký tự, chữ hoa, số và ký tự đặc biệt',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.next,
          validator: Validators.strongPassword,
        ),
        const SizedBox(height: 14),
        AuthInputField(
          controller: _confirmPasswordController,
          label: 'Xác nhận mật khẩu',
          hint: 'Nhập lại mật khẩu',
          icon: Icons.lock_reset_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          validator: (v) =>
              Validators.confirmPassword(v, _passwordController.text),
        ),
        const SizedBox(height: 16),

        // ── Terms checkbox ──────────────────────────────
        _TermsCheckbox(
          value: _acceptedTerms,
          onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
        ),
        const SizedBox(height: 18),

        // ── Send OTP button ─────────────────────────────
        AuthPrimaryButton(
          label: _sendingOtp ? 'Đang gửi mã xác nhận...' : 'Tiếp tục',
          isLoading: _sendingOtp || _auth.isLoading.value,
          onPressed: _sendOtp,
        ),
        const SizedBox(height: 14),

        // ── Divider ─────────────────────────────────────
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Hoặc',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),

        // ── Google register ─────────────────────────────
        Obx(
          () => AuthGoogleButton(
            label: 'Đăng ký với Google',
            isLoading: _sendingOtp || _auth.isLoading.value,
            onPressed: _auth.loginWithGoogle,
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Email (disabled) ────────────────────────────
        AuthInputField(
          controller: _emailController,
          label: 'Email',
          hint: '',
          icon: Icons.mail_outline_rounded,
          enabled: false,
        ),
        const SizedBox(height: 20),

        // ── OTP info banner ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.brandLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.brand, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kiểm tra hộp thư (kể cả thư rác) để lấy mã xác nhận 6 chữ số.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.brand,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── OTP input ───────────────────────────────────
        const Text(
          'Mã xác minh OTP',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: Validators.code,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 10,
            color: AppColors.textPrimary,
          ),
          cursorColor: AppColors.brand,
          decoration: InputDecoration(
            counterText: '',
            hintText: '• • • • • •',
            hintStyle: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade300,
              letterSpacing: 10,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FF),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Resend button ───────────────────────────────
        Center(
          child: TextButton(
            onPressed:
                (_countdown > 0 || _sendingOtp || _auth.isLoading.value)
                    ? null
                    : _resendCode,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              disabledForegroundColor: AppColors.textSecondary,
            ),
            child: Text(
              _sendingOtp
                  ? 'Đang gửi lại...'
                  : _countdown > 0
                      ? 'Gửi lại mã sau ${_countdown}s'
                      : 'Gửi lại mã OTP',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Complete register ───────────────────────────
        Obx(
          () => AuthPrimaryButton(
            label: _auth.isLoading.value
                ? 'Đang hoàn tất đăng ký...'
                : 'Hoàn tất đăng ký',
            isLoading: _auth.isLoading.value,
            onPressed: _completeRegister,
          ),
        ),
        const SizedBox(height: 12),

        // ── Back ────────────────────────────────────────
        TextButton.icon(
          onPressed: () => setState(() => _step = _RegisterStep.info),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          label: const Text('Quay lại chỉnh sửa thông tin'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Phone input field ─────────────────────────────────────────────

class _PhoneInputField extends StatelessWidget {
  const _PhoneInputField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Số điện thoại',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          maxLength: 15,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\- ]')),
          ],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: Validators.phone,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          cursorColor: AppColors.brand,
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Nhập số điện thoại',
            hintStyle: TextStyle(fontSize: 15, color: Colors.grey.shade400),
            prefixIcon:
                Icon(Icons.phone_outlined, size: 20, color: Colors.grey.shade400),
            filled: true,
            fillColor: const Color(0xFFF8F9FF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Terms checkbox ────────────────────────────────────────────────

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.brand,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            children: [
              const Text(
                'Tôi đồng ý với ',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.terms),
                child: const Text(
                  'Điều khoản dịch vụ',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                ' và ',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.privacy),
                child: const Text(
                  'Chính sách bảo mật',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────

class _LoginFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.login_rounded,
                    color: AppColors.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đã có tài khoản StayHub?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đăng nhập ngay để tiếp tục',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Get.offAllNamed(AppRoutes.login),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.brand, width: 1.2),
              ),
            ),
            child: const Text(
              'Đăng nhập',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
