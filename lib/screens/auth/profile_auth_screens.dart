import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../controllers/auth_controller.dart';
import '../../models/api_response.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/auth_page_layout.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/ios_grouped.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _picker = ImagePicker();
  File? _avatarFile;
  String? _gender;
  DateTime? _dateOfBirth;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser.value;
    _nameController = TextEditingController(text: user?.fullName);
    _emailController = TextEditingController(text: user?.email);
    _phoneController = TextEditingController(text: user?.phoneNumber);
    _gender = user?.gender?.isNotEmpty == true ? user!.gender : 'Male';
    _dateOfBirth = DateTime.tryParse(user?.dateOfBirth ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 90,
    );
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final phone = _phoneController.text.trim();
      await _auth.updateProfile(
        fullName: _nameController.text.trim(),
        phoneNumber: phone.isEmpty ? null : phone,
        gender: _gender,
        dateOfBirth: _dateOfBirth == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_dateOfBirth!),
        avatarPath: _avatarFile?.path,
      );
      SnackbarHelper.success('profile_updated_success'.tr);
      Get.offAllNamed(AppRoutes.profile);
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (_) {
      SnackbarHelper.error(
        'profile_update_failed'.tr,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ImageProvider? _avatarImage(UserModel? user) {
    if (_avatarFile != null) return FileImage(_avatarFile!);
    if (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(user.avatarUrl!);
    }
    return null;
  }

  Widget _buildRow({
    required BuildContext context,
    required String label,
    Widget? trailing,
    String? value,
    VoidCallback? onTap,
    bool isAction = false,
    bool showBorder = true,
    Color? valueColor,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1))
              : null,
        ),
        child: Row(
          children: [
            Text(label,
                style: textTheme.bodyMedium?.copyWith(color: Colors.black87)),
            const SizedBox(width: 16),
            Expanded(
              child: trailing ??
                  (value != null
                      ? Text(
                          value,
                          textAlign: TextAlign.right,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: valueColor ?? Colors.black87),
                        )
                      : const SizedBox()),
            ),
            if (isAction) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.black38),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser.value;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('edit_profile'.tr,
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          _loading
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))))
              : TextButton(
                  onPressed: _submit,
                  child: Text('save'.tr,
                      style: textTheme.titleMedium
                          ?.copyWith(color: AppColors.brand)),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            _buildSection(
              [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.transparent,
                          backgroundImage: _avatarImage(user),
                          child: _avatarImage(user) == null
                              ? const Icon(Icons.person,
                                  color: AppColors.brand, size: 40)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_square,
                                size: 16, color: AppColors.brand),
                            const SizedBox(width: 6),
                            Text('edit'.tr,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.brand)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSection(
              [
                _buildRow(
                  context: context,
                  label: 'name'.tr,
                  showBorder: true,
                  isAction: true,
                  trailing: TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.right,
                    style:
                        textTheme.bodyMedium?.copyWith(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'set_now'.tr,
                      hintStyle: TextStyle(color: Colors.black38),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      filled: false,
                    ),
                    validator: Validators.fullName,
                  ),
                ),
                _buildRow(
                  context: context,
                  label: 'username'.tr,
                  value: user?.email ?? '',
                  valueColor: Colors.black54,
                  showBorder: false,
                  isAction: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSection(
              [
                _buildRow(
                  context: context,
                  label: 'gender'.tr,
                  showBorder: true,
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _gender,
                      isDense: true,
                      alignment: Alignment.centerRight,
                      icon: const Icon(Icons.chevron_right_rounded,
                          size: 18, color: Colors.black38),
                      style:
                          textTheme.bodyMedium?.copyWith(color: Colors.black87),
                      items: [
                        DropdownMenuItem(value: 'Male', child: Text('male'.tr)),
                        DropdownMenuItem(value: 'Female', child: Text('female'.tr)),
                        DropdownMenuItem(value: 'Other', child: Text('other'.tr)),
                      ],
                      onChanged: (value) => setState(() => _gender = value),
                    ),
                  ),
                ),
                _buildRow(
                  context: context,
                  label: 'date_of_birth'.tr,
                  value: _dateOfBirth == null
                      ? 'set_now'.tr
                      : DateFormat('dd/MM/yyyy').format(_dateOfBirth!),
                  valueColor:
                      _dateOfBirth == null ? AppColors.brand : Colors.black87,
                  isAction: true,
                  showBorder: false,
                  onTap: _pickBirthDate,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSection(
              [
                _buildRow(
                  context: context,
                  label: 'phone_number'.tr,
                  showBorder: true,
                  isAction: true,
                  trailing: TextFormField(
                    controller: _phoneController,
                    textAlign: TextAlign.right,
                    style:
                        textTheme.bodyMedium?.copyWith(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'set_now'.tr,
                      hintStyle: TextStyle(color: Colors.black38),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      filled: false,
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return Validators.phone(value);
                    },
                  ),
                ),
                _buildRow(
                  context: context,
                  label: 'Email',
                  value: user?.email ?? 'set_now'.tr,
                  valueColor: (user?.email?.isEmpty ?? true)
                      ? AppColors.brand
                      : Colors.black87,
                  isAction: true,
                  showBorder: true,
                ),
                _buildRow(
                  context: context,
                  label: 'change_password'.tr,
                  value: '********',
                  isAction: true,
                  showBorder: false,
                  onTap: () => Get.toNamed(AppRoutes.changePassword),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  var _loading = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Get.find<AuthController>().currentUser.value;
    return AppScreen(
      title: 'change_password'.tr,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (user?.requirePasswordChange == true) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade200),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'require_password_change'.tr,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              IosSurfaceCard(
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _oldController,
                      label: 'current_password'.tr,
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: (v) => Validators.requiredField(
                        v,
                        label: 'current_password'.tr,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _newController,
                      label: 'new_password'.tr,
                      obscureText: true,
                      prefixIcon: Icons.lock_reset_rounded,
                      validator: Validators.strongPassword,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _confirmController,
                      label: 'confirm_new_password'.tr,
                      obscureText: true,
                      prefixIcon: Icons.lock_reset_rounded,
                      validator: (v) =>
                          Validators.confirmPassword(v, _newController.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: 'change_password'.tr,
                isLoading: _loading,
                onPressed: () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() => _loading = true);
                  try {
                    await Get.find<AuthController>().changePassword(
                      oldPassword: _oldController.text,
                      newPassword: _newController.text,
                    );
                    SnackbarHelper.success('change_password_success'.tr);
                    _oldController.clear();
                    _newController.clear();
                    _confirmController.clear();
                    Get.offAllNamed(AppRoutes.home);
                  } on ApiError catch (e) {
                    SnackbarHelper.error(e.message);
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  var _loading = false;
  var _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCountdown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _countdown = seconds);
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

  Future<void> _submit() async {
    if (_loading || _countdown > 0) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    setState(() => _loading = true);
    try {
      final result = await Get.find<AuthService>().forgotPassword(email);
      if (result.retryAfterSeconds != null) {
        _startCountdown(result.retryAfterSeconds!);
        SnackbarHelper.error(
          result.message ??
              '${'please_wait'.tr} ${result.retryAfterSeconds}s',
        );
        return;
      }
      _startCountdown();
      SnackbarHelper.success(
        result.message ?? 'if_email_registered'.tr,
      );
      Get.offNamed(AppRoutes.resetPassword, arguments: email);
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      showBack: true,
      headerSubtitle: 'YOUR JOURNEY · YOUR VALUE',
      title: '${'forgot_password_title'.tr} 🔑',
      subtitle: 'forgot_password_subtitle'.tr,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Icon minh hoạ ──────────────────────────
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 40,
                  color: AppColors.brand,
                ),
              ),
            ),
            const SizedBox(height: 24),

            AuthInputField(
              controller: _emailController,
              label: 'email_address_label'.tr,
              hint: 'email_address_hint'.tr,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: Validators.email,
            ),
            const SizedBox(height: 24),

            AuthPrimaryButton(
              label: _countdown > 0
                  ? '${'please_wait'.tr} ${_countdown}s...'
                  : (_loading ? 'sending'.tr : 'send_recovery_code'.tr),
              isLoading: _loading,
              onPressed: _countdown > 0 ? null : _submit,
            ),
            const SizedBox(height: 16),

            // ── Back to login ───────────────────────────
            TextButton.icon(
              onPressed: Get.back,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
              label: Text('back_to_login'.tr),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ResetPasswordStep { verifyOtp, setNewPassword }

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  var _loading = false;
  var _verifyingOtp = false;
  var _resending = false;
  var _countdown = 60;
  Timer? _timer;
  late final String _email;
  var _step = _ResetPasswordStep.verifyOtp;
  var _resetToken = '';

  @override
  void initState() {
    super.initState();
    _email = Get.arguments as String? ?? '';
    _emailController = TextEditingController(text: _email);
    _startCountdown();
    if (_email.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offNamed(AppRoutes.forgotPassword);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _resendCode() async {
    if (_email.isEmpty ||
        _resending ||
        _loading ||
        _verifyingOtp ||
        _countdown > 0) {
      return;
    }
    setState(() => _resending = true);
    try {
      final result = await Get.find<AuthService>().forgotPassword(_email);
      final seconds = result.retryAfterSeconds ?? 60;
      _startCountdown(seconds);
      if (result.retryAfterSeconds != null) {
        SnackbarHelper.error(
          result.message ?? '${'please_wait'.tr} $seconds s',
        );
      } else {
        SnackbarHelper.success(
          result.message ?? 'if_email_registered'.tr,
        );
      }
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_verifyingOtp || !(_formKey.currentState?.validate() ?? false)) return;
    if (_codeController.text.trim().isEmpty) return;
    setState(() => _verifyingOtp = true);
    try {
      final token = await Get.find<AuthService>().verifyResetOtp(
        email: _email,
        code: _codeController.text.trim(),
      );
      SnackbarHelper.success(
        'verify_otp_success'.tr,
      );
      if (mounted) {
        setState(() {
          _resetToken = token;
          _step = _ResetPasswordStep.setNewPassword;
          _verifyingOtp = false;
        });
      }
    } on ApiError catch (e) {
      if (e.message == 'InvalidOrExpiredOtp' ||
          e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('expired') ||
          e.message.toLowerCase().contains('otp')) {
        SnackbarHelper.error(
            'otp_invalid_or_expired'.tr);
      } else {
        SnackbarHelper.error(e.message);
      }
      if (mounted) setState(() => _verifyingOtp = false);
    } catch (e) {
      SnackbarHelper.error(
        'otp_invalid_or_expired'.tr,
      );
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  Future<void> _submitReset() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      SnackbarHelper.error('password_mismatch'.tr);
      return;
    }
    setState(() => _loading = true);
    try {
      await Get.find<AuthService>().resetPassword(
        email: _email,
        resetToken: _resetToken,
        newPassword: _passwordController.text,
      );
      SnackbarHelper.success('reset_password_success'.tr);
      Get.offAllNamed(AppRoutes.login);
    } on ApiError catch (e) {
      if (e.message == 'InvalidOrExpiredOtp' ||
          e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('expired') ||
          e.message.toLowerCase().contains('otp')) {
        SnackbarHelper.error(
            'otp_invalid_or_expired'.tr);
      } else {
        SnackbarHelper.error(e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      showBack: true,
      headerSubtitle: 'YOUR JOURNEY · YOUR VALUE',
      title: _step == _ResetPasswordStep.verifyOtp
          ? '${'enter_otp_title'.tr} 📩'
          : '${'new_password_title'.tr} 🔐',
      subtitle: _step == _ResetPasswordStep.verifyOtp
          ? 'enter_6_digit_sent'.tr
          : 'otp_verified_create_password'.tr,
      body: Form(
        key: _formKey,
        child: _step == _ResetPasswordStep.verifyOtp
            ? _buildVerifyOtpForm()
            : _buildSetNewPasswordForm(),
      ),
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

        // ── OTP banner ──────────────────────────────────
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
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'check_email_spam'.tr,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.brand, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── OTP input large ─────────────────────────────
        Text(
          'otp_code'.tr,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _codeController,
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
            onPressed: (_countdown > 0 || _resending || _verifyingOtp)
                ? null
                : _resendCode,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              disabledForegroundColor: AppColors.textSecondary,
            ),
            child: Text(
              _resending
                  ? 'resending_code'.tr
                  : _countdown > 0
                      ? '${'resend_code_later'.tr} ${_countdown}s'
                      : 'resend_code'.tr,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 20),

        AuthPrimaryButton(
          label: _verifyingOtp ? 'verifying'.tr : 'verify_otp'.tr,
          isLoading: _verifyingOtp,
          onPressed: _verifyingOtp ? null : _verifyOtp,
        ),
      ],
    );
  }

  Widget _buildSetNewPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Success banner ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: Color(0xFF065F46), fontSize: 13, height: 1.4),
                    children: [
                      TextSpan(text: 'otp_verified_for_email'.tr),
                      TextSpan(
                        text: _email,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        AuthInputField(
          controller: _passwordController,
          label: 'new_password'.tr,
          hint: 'password_register_hint'.tr,
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.next,
          validator: Validators.strongPassword,
        ),
        const SizedBox(height: 14),

        AuthInputField(
          controller: _confirmPasswordController,
          label: 'confirm_new_password'.tr,
          hint: 'confirm_password_hint'.tr,
          icon: Icons.lock_reset_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          validator: (value) =>
              Validators.confirmPassword(value, _passwordController.text),
        ),
        const SizedBox(height: 24),

        AuthPrimaryButton(
          label: _loading ? 'resetting'.tr : 'reset_password'.tr,
          isLoading: _loading,
          onPressed: _loading ? null : _submitReset,
        ),
      ],
    );
  }
}
