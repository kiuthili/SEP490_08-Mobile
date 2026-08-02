import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/custom_tutorial_tooltip.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../services/tutorial_service.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthController _auth;
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _loginFieldKey = GlobalKey();
  final GlobalKey _loginButtonKey = GlobalKey();
  final GlobalKey _forgotPassKey = GlobalKey();
  final GlobalKey _googleLoginKey = GlobalKey();
  final GlobalKey _registerKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;

  void _goHome() => Get.offAllNamed(AppRoutes.home);

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<TutorialService>()) {
        if (!Get.find<TutorialService>().isLoginTutorialDone.value) {
          _showTutorial();
        }
      }
    });
  }

  void _showTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: AppColors.navy,
      hideSkip: true,
      paddingFocus: 10,
      opacityShadow: 0.85,
      onSkip: () {
        Get.find<TutorialService>().completeLoginTutorial();
        return true;
      },
      onFinish: () {
        Get.find<TutorialService>().completeLoginTutorial();
      },
    )..show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "loginField",
        keyTarget: _loginFieldKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        enableOverlayTab: false, // Bắt buộc user tương tác với card
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return CustomTutorialTooltip(
                title: 'tutorial_login_welcome'.tr,
                description: 'tutorial_login_welcome_desc'.tr,
                currentStep: 1,
                totalSteps: 5,
                onNext: () {
                  if (_loginButtonKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _loginButtonKey.currentContext!,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: 0.5,
                    ).then((_) {
                      controller.next();
                    });
                  } else {
                    controller.next();
                  }
                },
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "loginButton",
        keyTarget: _loginButtonKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return CustomTutorialTooltip(
                title: 'tutorial_login_btn'.tr,
                description: 'tutorial_login_btn_desc'.tr,
                currentStep: 2,
                totalSteps: 5,
                onNext: () {
                  if (_forgotPassKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _forgotPassKey.currentContext!,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: 0.5,
                    ).then((_) {
                      controller.next();
                    });
                  } else {
                    controller.next();
                  }
                },
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "forgotPass",
        keyTarget: _forgotPassKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return CustomTutorialTooltip(
                title: 'tutorial_login_forgot'.tr,
                description: 'tutorial_login_forgot_desc'.tr,
                currentStep: 3,
                totalSteps: 5,
                onNext: () {
                  if (_googleLoginKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _googleLoginKey.currentContext!,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: 0.5,
                    ).then((_) {
                      controller.next();
                    });
                  } else {
                    controller.next();
                  }
                },
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "googleLogin",
        keyTarget: _googleLoginKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return CustomTutorialTooltip(
                title: 'tutorial_login_google'.tr,
                description: 'tutorial_login_google_desc'.tr,
                currentStep: 4,
                totalSteps: 5,
                onNext: () {
                  if (_registerKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _registerKey.currentContext!,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: 0.5,
                    ).then((_) {
                      controller.next();
                    });
                  } else {
                    controller.next();
                  }
                },
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "register",
        keyTarget: _registerKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return CustomTutorialTooltip(
                title: 'tutorial_login_register'.tr,
                description: 'tutorial_login_register_desc'.tr,
                currentStep: 5,
                totalSteps: 5,
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
    ];
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              child: Column(
                children: [
                  const StayHubLogo(
                    variant: StayHubLogoVariant.full,
                    theme: StayHubLogoTheme.defaultTheme,
                    iconSize: 44,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'app_tagline'.tr,
                    style: const TextStyle(
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
            Text(
              'login_title'.tr,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'login_subtitle'.tr,
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
                  // Form fields (Email & Password)
                  Container(
                    key: _loginFieldKey,
                    child: Column(
                      children: [
                        AuthInputField(
                          controller: _emailController,
                          label: 'account_label'.tr,
                          hint: 'account_hint'.tr,
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 14),
                        AuthInputField(
                          controller: _passwordController,
                          label: 'password_label'.tr,
                          hint: 'password_hint'.tr,
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: Validators.password,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Forgot password link
                  Container(
                    key: _forgotPassKey,
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
                      child: Text(
                        'forgot_password_link'.tr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Primary Login Button
                  Container(
                    key: _loginButtonKey,
                    child: Obx(
                      () => AuthPrimaryButton(
                        label: 'login_btn'.tr,
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
                          'or_continue_with'.tr,
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
                  Container(
                    key: _googleLoginKey,
                    child: Obx(
                      () => AuthGoogleButton(
                        label: 'login_with_google'.tr,
                        isLoading: _auth.isLoading.value,
                        onPressed: _auth.loginWithGoogle,
                      ),
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
                            Text(
                              'no_account'.tr,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'register_now_desc'.tr,
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
                    key: _registerKey,
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
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        'register_new_account'.tr,
                        style: const TextStyle(
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
                label: Text('back_to_home'.tr),
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
