import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/auth_controller.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

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
  late final AuthController _auth;
  var _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _auth.dateOfBirth.value,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) _auth.dateOfBirth.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      scrollable: true,
      heroTitle: 'Gia nhập StayHub',
      heroSubtitle: 'Tạo tài khoản để đặt tour và tham gia cộng đồng du lịch.',
      title: 'Đăng ký',
      subtitle: 'Điền thông tin để bắt đầu',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Đã có tài khoản? '),
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Đăng nhập',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CustomTextField(
              controller: _fullNameController,
              label: 'Họ và tên',
              prefixIcon: Icons.person_outline_rounded,
              maxLength: 60,
              textInputAction: TextInputAction.next,
              validator: Validators.fullName,
            ),
            const SizedBox(height: 16),
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
              controller: _phoneController,
              label: 'Số điện thoại',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              maxLength: 12,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
              validator: Validators.phone,
            ),
            const SizedBox(height: 16),
            Obx(
              () => ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ngày sinh'),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy').format(_auth.dateOfBirth.value),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickBirthDate,
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => DropdownButtonFormField<String>(
                initialValue: _auth.selectedGender.value,
                decoration: const InputDecoration(labelText: 'Giới tính'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Nam')),
                  DropdownMenuItem(value: 'Female', child: Text('Nữ')),
                  DropdownMenuItem(value: 'Other', child: Text('Khác')),
                ],
                onChanged: (v) {
                  if (v != null) _auth.selectedGender.value = v;
                },
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: 'Mật khẩu',
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: Validators.strongPassword,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _confirmPasswordController,
              label: 'Xác nhận mật khẩu',
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (v) => Validators.confirmPassword(
                v,
                _passwordController.text,
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Tôi đồng ý với ', style: TextStyle(fontSize: 13)),
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
                  const Text(' và ', style: TextStyle(fontSize: 13)),
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
            const SizedBox(height: 8),
            Obx(
              () => CustomButton(
                label: 'Đăng ký',
                isLoading: _auth.isLoading.value,
                onPressed: () {
                  if (!_acceptedTerms) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Vui lòng đồng ý điều khoản trước khi đăng ký',
                        ),
                      ),
                    );
                    return;
                  }
                  if (_formKey.currentState?.validate() ?? false) {
                    _auth.register(
                      fullName: _fullNameController.text,
                      email: _emailController.text,
                      phoneNumber: _phoneController.text,
                      password: _passwordController.text,
                      confirmPassword: _confirmPasswordController.text,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
