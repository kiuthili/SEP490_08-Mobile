import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/stayhub_logo.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthController _auth;

  void _goHome() => Get.offAllNamed(AppRoutes.home);

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding:
            EdgeInsets.fromLTRB(24, topPadding + 24, 24, 24 + bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Phần trên cùng: Logo & Tagline nhỏ gọn ─────────────
            GestureDetector(
              onTap: _goHome,
              child: const Column(
                children: [
                  StayHubLogo(
                    variant: StayHubLogoVariant.full,
                    theme: StayHubLogoTheme.defaultTheme,
                    iconSize: 44,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'YOUR JOURNEY · YOUR VALUE',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Tiêu đề & Lời chào ───────────────────────────────
            const Text(
              'Đăng nhập',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vui lòng nhập thông tin tài khoản của bạn',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // ── Phần chính: Form đăng nhập ───────────────────────
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Email/Phone input
                  AuthInputField(
                    controller: _emailController,
                    label: 'Tài khoản',
                    hint: 'Số điện thoại hoặc Email',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 14),

                  // Password input
                  AuthInputField(
                    controller: _passwordController,
                    label: 'Mật khẩu',
                    hint: 'Nhập mật khẩu',
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 2),

                  // Forgot password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Primary Login Button
                  Obx(
                    () => AuthPrimaryButton(
                      label: 'Đăng nhập',
                      isLoading: _auth.isLoading.value,
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          _auth.login(
                            email: _emailController.text,
                            password: _passwordController.text,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Divider "Hoặc"
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.grey.shade200, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'Hoặc tiếp tục với',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.grey.shade200, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Button
                  Obx(
                    () => AuthGoogleButton(
                      label: 'Đăng nhập với Google',
                      isLoading: _auth.isLoading.value,
                      onPressed: _auth.loginWithGoogle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Phân cách khu vực phía dưới bằng Container nổi bật ─────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppColors.brand,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bạn chưa có tài khoản?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đăng ký thành viên để nhận ưu đãi từ StayHub',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Get.toNamed(
                        AppRoutes.register,
                        arguments: Get.arguments,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.brand, width: 1.5),
                        foregroundColor: AppColors.brand,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      child: const Text(
                        'Đăng ký tài khoản mới',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Go home link
            Center(
              child: TextButton.icon(
                onPressed: _goHome,
                icon: const Icon(Icons.home_outlined, size: 16),
                label: const Text('Trở về trang chủ'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
