import 'package:get/get.dart';
import '../models/api_response.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/signalr_service.dart';
import '../services/storage_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/auth_gate.dart';
import 'feature_controllers.dart';

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
      if (response.user.requirePasswordChange) {
        Get.offAllNamed(AppRoutes.changePassword);
      } else {
        final destination = Get.arguments;
        AuthGate.completeLogin(
          destination is LoginDestination ? destination : null,
        );
      }
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
      await _authService.register(
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
      SnackbarHelper.success('Đăng ký thành công. Vui lòng đăng nhập.');
      Get.offAllNamed(AppRoutes.login, arguments: Get.arguments);
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

  Future<UserModel> updateProfile({
    required String fullName,
    String? phoneNumber,
    String? gender,
    String? dateOfBirth,
    String? avatarPath,
  }) async {
    final user = await _authService.updateProfile(
      fullName: fullName,
      phoneNumber: phoneNumber,
      gender: gender,
      dateOfBirth: dateOfBirth,
      avatarPath: avatarPath,
    );
    currentUser.value = user;
    return user;
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    currentUser.value = await _authService.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    if (Get.isRegistered<SignalRService>()) {
      await Get.find<SignalRService>().disconnectChat();
      await Get.find<SignalRService>().disconnectFriendship();
    }
    if (Get.isRegistered<SocialController>()) {
      Get.find<SocialController>().clearSocialState();
    }
    await _authService.logout();
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.home);
  }

  Future<void> loginWithGoogle() async {
    isLoading.value = true;
    try {
      final response = await _authService.googleLogin();
      currentUser.value = response.user;
      SnackbarHelper.success('Đăng nhập Google thành công');
      if (response.user.requirePasswordChange) {
        Get.offAllNamed(AppRoutes.changePassword);
      } else {
        final destination = Get.arguments;
        AuthGate.completeLogin(
          destination is LoginDestination ? destination : null,
        );
      }
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (_) {
      SnackbarHelper.error('Không thể đăng nhập Google. Vui lòng thử lại.');
    } finally {
      isLoading.value = false;
    }
  }
}
