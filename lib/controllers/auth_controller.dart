import 'dart:async';

import 'package:get/get.dart';
import '../models/api_response.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/signalr_service.dart';
import '../services/storage_service.dart';
import '../services/push_notification_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/auth_gate.dart';
import '../widgets/auth_widgets.dart';
import 'feature_controllers.dart';
import 'shell_controller.dart';
import 'notification_controller.dart';

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
      await _syncPushTokenAfterLogin();
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

  Future<ForgotPasswordResult?> sendRegisterOtp({
    required String email,
    required String fullName,
  }) async {
    isLoading.value = true;
    try {
      final result = await _authService.sendRegisterOtp(
        email: email,
        fullName: fullName,
      );
      if (result.retryAfterSeconds != null) {
        SnackbarHelper.error(
          result.message ??
              'Vui lòng đợi ${result.retryAfterSeconds} giây trước khi gửi lại mã.',
        );
      } else {
        SnackbarHelper.success(
          result.message ?? 'Mã xác nhận đăng ký đã được gửi đến email của bạn.',
        );
      }
      return result;
    } on ApiError catch (e) {
      if (e.message == 'FullNameCannotContainSpecialCharacters') {
        SnackbarHelper.error('Họ và tên không được chứa ký tự đặc biệt hoặc biểu tượng');
      } else if (e.message == 'PhoneNumberExists') {
        SnackbarHelper.error('Số điện thoại này đã được sử dụng. Vui lòng sử dụng số khác.');
      } else {
        SnackbarHelper.error(e.message);
      }
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
    required String otpCode,
  }) async {
    if (fullName.trim().isEmpty ||
        email.trim().isEmpty ||
        phoneNumber.trim().isEmpty ||
        password.isEmpty ||
        otpCode.trim().isEmpty) {
      SnackbarHelper.error('Vui lòng điền đầy đủ thông tin');
      return false;
    }
    if (password != confirmPassword) {
      SnackbarHelper.error('Mật khẩu xác nhận không khớp');
      return false;
    }
    isLoading.value = true;
    try {
      await _authService.register(
        RegisterRequest(
          email: email.trim(),
          password: password,
          fullName: fullName.trim(),
          phoneNumber: phoneNumber.trim(),
          otpCode: otpCode.trim(),
        ),
      );
      SnackbarHelper.success('Đăng ký thành công. Vui lòng đăng nhập.');
      Get.offAllNamed(AppRoutes.login, arguments: Get.arguments);
      return true;
    } on ApiError catch (e) {
      if (e.message == 'FullNameCannotContainSpecialCharacters') {
        SnackbarHelper.error('Họ và tên không được chứa ký tự đặc biệt hoặc biểu tượng');
      } else if (e.message == 'PhoneNumberExists') {
        SnackbarHelper.error('Số điện thoại này đã được sử dụng. Vui lòng sử dụng số khác.');
      } else if (e.message == 'InvalidOrExpiredOtp' ||
          e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('expired') ||
          e.message.toLowerCase().contains('otp')) {
        SnackbarHelper.error('Mã xác nhận OTP không chính xác hoặc đã hết hạn.');
      } else {
        SnackbarHelper.error(e.message);
      }
      return false;
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
      await Get.find<SignalRService>().disconnectAll();
    }
    if (Get.isRegistered<SocialController>()) {
      Get.find<SocialController>().clearSocialState();
    }
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().notifications.clear();
    }
    if (Get.isRegistered<WishlistController>()) {
      Get.find<WishlistController>().items.clear();
    }
    await _authService.logout();
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.home);
  }

  Future<void> handleSessionExpiredCleanly() async {
    if (Get.isRegistered<SignalRService>()) {
      await Get.find<SignalRService>().disconnectAll();
    }
    if (Get.isRegistered<SocialController>()) {
      Get.find<SocialController>().clearSocialState();
    }
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().notifications.clear();
    }
    if (Get.isRegistered<WishlistController>()) {
      Get.find<WishlistController>().items.clear();
    }
    await _storage.clearSession();
    currentUser.value = null;
    if (Get.isRegistered<ShellController>()) {
      final shell = Get.find<ShellController>();
      if (shell.selectedIndex.value >= 2 || shell.isStaff) {
        shell.selectedIndex.value = 0;
      }
    }
  }

  Future<void> _syncPushTokenAfterLogin() async {
    if (Get.isRegistered<PushNotificationService>()) {
      await Get.find<PushNotificationService>().syncTokenToBackend();
    }
    if (Get.isRegistered<SocialController>()) {
      final social = Get.find<SocialController>();
      unawaited(social.fetchChatRooms());
    }
  }

  Future<void> loginWithGoogle() async {
    isLoading.value = true;
    try {
      final response = await _authService.googleLogin();
      if (response.requirePhoneNumber) {
        isLoading.value = false;
        _showGooglePhoneBottomSheet(
          idToken: response.idToken ?? '',
          user: response.user,
        );
        return;
      }
      currentUser.value = response.user;
      SnackbarHelper.success('Đăng nhập Google thành công');
      await _syncPushTokenAfterLogin();
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

  void _showGooglePhoneBottomSheet({
    required String idToken,
    required UserModel user,
  }) {
    Get.bottomSheet(
      GooglePhoneBottomSheet(
        user: user,
        onSubmit: (phone) => _confirmGooglePhoneNumber(
          idToken: idToken,
          phoneNumber: phone,
        ),
        onCancel: () {
          Get.back();
          SnackbarHelper.info('Đã hủy đăng ký tài khoản mới bằng Google.');
        },
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
    );
  }

  Future<void> _confirmGooglePhoneNumber({
    required String idToken,
    required String phoneNumber,
  }) async {
    if (Get.isBottomSheetOpen == true) {
      Get.back();
    }
    isLoading.value = true;
    try {
      final response = await _authService.googleLogin(
        idToken: idToken,
        phoneNumber: phoneNumber,
      );
      currentUser.value = response.user;
      SnackbarHelper.success('Đăng nhập Google thành công');
      await _syncPushTokenAfterLogin();
      if (response.user.requirePasswordChange) {
        Get.offAllNamed(AppRoutes.changePassword);
      } else {
        final destination = Get.arguments;
        AuthGate.completeLogin(
          destination is LoginDestination ? destination : null,
        );
      }
    } on ApiError catch (e) {
      if (e.message == 'PhoneNumberExists') {
        SnackbarHelper.error(
          'Số điện thoại này đã được sử dụng. Vui lòng sử dụng số khác.',
        );
      } else if (e.message == 'PhoneNumberMax15Chars') {
        SnackbarHelper.error('Số điện thoại tối đa 15 chữ số.');
      } else {
        SnackbarHelper.error(e.message);
      }
    } catch (_) {
      SnackbarHelper.error(
        'Không thể hoàn tất đăng ký Google. Vui lòng thử lại.',
      );
    } finally {
      isLoading.value = false;
    }
  }
}
