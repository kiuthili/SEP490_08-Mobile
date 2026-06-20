import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../routes/app_routes.dart';
import '../utils/validators.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

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
    return AuthScaffold(
      onLogoTap: _goHome,
      heroTitle: 'Khám phá hành trình của bạn',
      heroSubtitle:
          'Đặt tour, kết nối bạn bè và chia sẻ khoảnh khắc — mọi thứ trong một ứng dụng.',
      title: 'Chào mừng trở lại',
      subtitle: 'Đăng nhập để tiếp tục với StayHub',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Chưa có tài khoản? '),
          TextButton(
            onPressed: () => Get.toNamed(
              AppRoutes.register,
              arguments: Get.arguments,
            ),
            child: const Text(
              'Đăng ký miễn phí',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: 'Mật khẩu',
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: Validators.password,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                child: const Text('Quên mật khẩu?'),
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => CustomButton(
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
            const SizedBox(height: 12),
            Obx(
              () => OutlinedButton.icon(
                onPressed: _auth.isLoading.value ? null : _auth.loginWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Đăng nhập với Google'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _goHome,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Trở về trang chủ'),
            ),
          ],
        ),
      ),
    );
  }
}
