import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_constants.dart';
import '../routes/app_routes.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/stayhub_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _navigateNext();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(
      const Duration(milliseconds: AppConstants.splashDelayMs),
    );
    final storage = Get.find<StorageService>();
    final user = storage.user;
    if (storage.isLoggedIn && user?.isCustomerOnly == true) {
      if (user!.requirePasswordChange) {
        Get.offAllNamed(AppRoutes.changePassword);
      } else {
        Get.offAllNamed(AppRoutes.home, arguments: {'initialTab': 2}); // 2 is nav_home for customers
      }
    } else {
      if (storage.isLoggedIn) {
        await storage.clearSession();
      }
      Get.offAllNamed(AppRoutes.home); // 0 is nav_home for guests
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.authHeroGradient,
        ),
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const StayHubLogo(
                  theme: StayHubLogoTheme.light,
                  iconSize: 72,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                AppConstants.appName,
                style: AppTextStyles.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'splash_subtitle'.tr,
                style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 56),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
