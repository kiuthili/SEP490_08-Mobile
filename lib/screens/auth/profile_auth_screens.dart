import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/auth_controller.dart';
import '../../models/api_response.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/validators.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/ios_grouped.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _picker = ImagePicker();
  File? _avatarFile;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser.value;
    _nameController = TextEditingController(text: user?.fullName);
    _phoneController = TextEditingController(text: user?.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  ImageProvider? _avatarImage(UserModel? user) {
    if (_avatarFile != null) return FileImage(_avatarFile!);
    if (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(user.avatarUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser.value;
    return AppScreen(
      title: 'Cập nhật hồ sơ',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              IosSurfaceCard(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.brandLight,
                        backgroundImage: _avatarImage(user),
                        child: _avatarImage(user) == null
                            ? const Icon(Icons.camera_alt_rounded, size: 32)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Chạm để đổi avatar'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              IosSurfaceCard(
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      label: 'Họ tên',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: Validators.fullName,
                      maxLength: 60,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _phoneController,
                      label: 'Số điện thoại',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone,
                      maxLength: 12,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: 'Lưu',
                isLoading: _loading,
                onPressed: _loading
                    ? null
                    : () async {
                        if (!(_formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setState(() => _loading = true);
                        try {
                          final phone = _phoneController.text.trim();
                          final updated =
                              await Get.find<AuthService>().updateProfile(
                            fullName: _nameController.text.trim(),
                            phoneNumber: phone.isEmpty ? null : phone,
                            gender: user?.gender,
                            dateOfBirth: user?.dateOfBirth,
                            avatarPath: _avatarFile?.path,
                          );
                          _auth.currentUser.value = updated;
                          SnackbarHelper.success('Cập nhật hồ sơ thành công');
                          if (mounted) Get.back();
                        } on ApiError catch (e) {
                          SnackbarHelper.error(e.message);
                        } catch (e) {
                          SnackbarHelper.error(
                            'Không cập nhật được hồ sơ. Vui lòng thử lại.',
                          );
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
    return AppScreen(
      title: 'Đổi mật khẩu',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              IosSurfaceCard(
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _oldController,
                      label: 'Mật khẩu cũ',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: (v) => Validators.requiredField(
                        v,
                        label: 'Mật khẩu cũ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _newController,
                      label: 'Mật khẩu mới',
                      obscureText: true,
                      prefixIcon: Icons.lock_reset_rounded,
                      validator: Validators.strongPassword,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _confirmController,
                      label: 'Xác nhận mật khẩu mới',
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
                label: 'Đổi mật khẩu',
                isLoading: _loading,
                onPressed: () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() => _loading = true);
                  try {
                    await Get.find<AuthService>().changePassword(
                      oldPassword: _oldController.text,
                      newPassword: _newController.text,
                    );
                    SnackbarHelper.success('Đổi mật khẩu thành công');
                    Get.back();
                  } catch (e) {
                    SnackbarHelper.error(e.toString());
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      heroTitle: 'Khôi phục mật khẩu',
      heroSubtitle: 'Chúng tôi sẽ gửi mã xác nhận đến email của bạn.',
      title: 'Quên mật khẩu',
      subtitle: 'Nhập email đã đăng ký',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CustomTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              validator: Validators.email,
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Gửi mã xác nhận',
              isLoading: _loading,
              onPressed: () async {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                setState(() => _loading = true);
                try {
                  await Get.find<AuthService>()
                      .forgotPassword(_emailController.text.trim());
                  SnackbarHelper.success('Kiểm tra email của bạn');
                  Get.offNamed(
                    AppRoutes.resetPassword,
                    arguments: _emailController.text.trim(),
                  );
                } catch (e) {
                  SnackbarHelper.error(e.toString());
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  var _loading = false;
  late final String _email;

  @override
  void initState() {
    super.initState();
    _email = Get.arguments as String? ?? '';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      heroTitle: 'Mật khẩu mới',
      heroSubtitle: 'Nhập mã từ email và chọn mật khẩu mới.',
      title: 'Đặt lại mật khẩu',
      subtitle: _email.isNotEmpty ? _email : 'Nhập mã xác nhận',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CustomTextField(
              controller: _codeController,
              label: 'Mã xác nhận',
              prefixIcon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              validator: Validators.code,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: 'Mật khẩu mới',
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: Validators.strongPassword,
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Đặt lại mật khẩu',
              isLoading: _loading,
              onPressed: () async {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                setState(() => _loading = true);
                try {
                  await Get.find<AuthService>().resetPassword(
                    email: _email,
                    code: _codeController.text.trim(),
                    newPassword: _passwordController.text,
                  );
                  SnackbarHelper.success('Đặt lại mật khẩu thành công');
                  Get.offAllNamed(AppRoutes.login);
                } catch (e) {
                  SnackbarHelper.error(e.toString());
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
