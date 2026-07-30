import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'stayhub_logo.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

/// Layout trắng, gọn nhẹ cho Register, ForgotPassword, ResetPassword.
/// Header nhỏ (back + logo), form bên dưới cuộn tự do.
class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.footer,
    this.showBack = false,
    this.onLogoTap,
    this.headerSubtitle,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Widget? footer;
  final bool showBack;
  final VoidCallback? onLogoTap;
  final String? headerSubtitle;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(24, topPadding + 16, 24, 24 + bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top bar: back + logo ──────────────────────
              Row(
                children: [
                  if (showBack)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      onTap: Get.back,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  if (showBack) const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onLogoTap,
                    child: const StayHubLogo(
                      variant: StayHubLogoVariant.full,
                      theme: StayHubLogoTheme.defaultTheme,
                      iconSize: 36,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Title + subtitle ──────────────────────────
              Text(
                title,
                style: AppTextStyles.textTheme.headlineMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // ── Form body ─────────────────────────────────
              body,

              // ── Footer ────────────────────────────────────
              if (footer != null) ...[
                const SizedBox(height: 20),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
