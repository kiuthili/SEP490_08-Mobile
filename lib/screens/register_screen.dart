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
import 'package:stayhub_mobile/theme/app_radius.dart';

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
        SnackBar(
          content: Text('agree_terms_required'.tr),
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    if (phone.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('phone_max_length'.tr)),
      );
      return;
    }
    if (!RegExp(r'^[0-9+()\- ]{8,15}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('phone_invalid'.tr)),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('password_mismatch'.tr)),
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
        SnackBar(content: Text('otp_required'.tr)),
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
      headerSubtitle: 'app_tagline'.tr,
      title: _step == _RegisterStep.info
          ? 'register_title_info'.tr
          : 'register_title_otp'.tr,
      subtitle: _step == _RegisterStep.info
          ? 'register_subtitle_info'.tr
          : 'register_subtitle_otp'.tr,
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
          label: 'fullname_label'.tr,
          hint: 'fullname_hint'.tr,
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          maxLength: 100,
          validator: Validators.fullName,
        ),
        const SizedBox(height: 14),
        AuthInputField(
          controller: _emailController,
          label: 'email_label'.tr,
          hint: 'email_hint'.tr,
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          maxLength: 255,
          validator: Validators.email,
        ),
        const SizedBox(height: 14),
        _PhoneInputField(controller: _phoneController),
        const SizedBox(height: 14),
        AuthInputField(
          controller: _passwordController,
          label: 'password_label'.tr,
          hint: 'password_register_hint'.tr,
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.next,
          maxLength: 100,
          validator: Validators.strongPassword,
        ),
        const SizedBox(height: 14),
        AuthInputField(
          controller: _confirmPasswordController,
          label: 'confirm_password_label'.tr,
          hint: 'confirm_password_hint'.tr,
          icon: Icons.lock_reset_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          maxLength: 100,
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
          label: _sendingOtp ? 'sending_otp'.tr : 'continue'.tr,
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
                'or'.tr,
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
            label: 'register_with_google'.tr,
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
          label: 'email_label'.tr,
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
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.brand, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'check_email_spam'.tr,
                  style: const TextStyle(
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
        Text(
          'otp_code'.tr,
          style: const TextStyle(
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
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: Colors.grey.shade200),
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
          ),
        ),
        const SizedBox(height: 12),

        // ── Resend button ───────────────────────────────
        Center(
          child: TextButton(
            onPressed: (_countdown > 0 || _sendingOtp || _auth.isLoading.value)
                ? null
                : _resendCode,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              disabledForegroundColor: AppColors.textSecondary,
            ),
            child: Text(
              _sendingOtp
                  ? 'resending_code'.tr
                  : _countdown > 0
                      ? '${'resend_code_later'.tr} ${_countdown}s'
                      : 'resend_code'.tr,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Complete register ───────────────────────────
        Obx(
          () => AuthPrimaryButton(
            label: _auth.isLoading.value
                ? 'completing_register'.tr
                : 'complete_register'.tr,
            isLoading: _auth.isLoading.value,
            onPressed: _completeRegister,
          ),
        ),
        const SizedBox(height: 12),

        // ── Back ────────────────────────────────────────
        TextButton.icon(
          onPressed: () => setState(() => _step = _RegisterStep.info),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          label: Text('back_to_edit_info'.tr),
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
    return TextFormField(
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
        labelText: 'phone_label'.tr,
        counterText: '',
        hintText: 'phone_hint'.tr,
        alignLabelWithHint: true,
        hintStyle: TextStyle(fontSize: 15, color: Colors.grey.shade400),
        prefixIcon: const Icon(Icons.phone_outlined,
            size: 22, color: AppColors.textSecondary),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          maxWidth: 52,
          minHeight: 48,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
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
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            children: [
              Text(
                'agree_to'.tr,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.terms),
                child: Text(
                  'terms_of_service'.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'and'.tr,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.privacy),
                child: Text(
                  'privacy_policy'.tr,
                  style: const TextStyle(
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
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                    borderRadius: BorderRadius.circular(AppRadius.sm),
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
                      Text(
                        'have_account_stayhub'.tr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'login_now_continue'.tr,
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
                borderRadius: BorderRadius.circular(100),
                side: const BorderSide(color: AppColors.brand, width: 1.2),
              ),
            ),
            child: Text(
              'login_btn'.tr,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
