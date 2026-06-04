import 'package:get/get.dart';
import '../models/api_response.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/snackbar_helper.dart';

class AuthController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final StorageService _storage = Get.find<StorageService>();

  final isLoading = false.obs;
  final currentUser = Rxn<UserModel>();
  final selectedGender = 'Male'.obs;
  final dateOfBirth = DateTime(2000, 1, 1).obs;

  @override
  void onInit() {
    super.onInit();
    currentUser.value = _storage.user;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      SnackbarHelper.error('Vui lòng nhập email và mật khẩu');
      return;
    }
    isLoading.value = true;
    try {
      final response = await _authService.login(
        LoginRequest(email: trimmedEmail, password: password),
      );
      currentUser.value = response.user;
      SnackbarHelper.success('Đăng nhập thành công');
      Get.offAllNamed(AppRoutes.home);
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) async {
    if (fullName.trim().isEmpty ||
        email.trim().isEmpty ||
        phoneNumber.trim().isEmpty ||
        password.isEmpty) {
      SnackbarHelper.error('Vui lòng điền đầy đủ thông tin');
      return;
    }
    if (password != confirmPassword) {
      SnackbarHelper.error('Mật khẩu xác nhận không khớp');
      return;
    }
    isLoading.value = true;
    try {
      final response = await _authService.register(
        RegisterRequest(
          email: email.trim(),
          password: password,
          fullName: fullName.trim(),
          phoneNumber: phoneNumber.trim(),
          gender: selectedGender.value,
          dateOfBirth:
              '${dateOfBirth.value.year}-${dateOfBirth.value.month.toString().padLeft(2, '0')}-${dateOfBirth.value.day.toString().padLeft(2, '0')}',
        ),
      );
      currentUser.value = response.user;
      SnackbarHelper.success('Đăng ký thành công');
      Get.offAllNamed(AppRoutes.home);
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadProfile() async {
    isLoading.value = true;
    try {
      currentUser.value = await _authService.getProfile();
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> loginWithGoogle() async {
    isLoading.value = true;
    try {
      final response = await _authService.googleLogin();
      currentUser.value = response.user;
      SnackbarHelper.success('Đăng nhập Google thành công');
      Get.offAllNamed(AppRoutes.home);
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } finally {
      isLoading.value = false;
    }
  }
}
