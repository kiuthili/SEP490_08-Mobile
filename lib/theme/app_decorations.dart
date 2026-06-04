import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

class AppDecorations {
  AppDecorations._();

  static BoxDecoration card({Color? color}) => BoxDecoration(
        color: color ?? AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppShadows.card,
      );

  static BoxDecoration glass({
    double opacity = 0.78,
    BorderRadius? radius,
  }) =>
      BoxDecoration(
        color: AppColors.glassFill.withValues(alpha: opacity),
        borderRadius: radius ?? AppRadius.navBar,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 0.5,
        ),
        boxShadow: AppShadows.navBar,
      );

  static Widget glassPanel({
    required Widget child,
    BorderRadius? radius,
    EdgeInsetsGeometry? padding,
    double blur = 24,
  }) {
    final r = radius ?? AppRadius.navBar;
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: glass(radius: r),
          child: child,
        ),
      ),
    );
  }

  static BoxDecoration inputField({bool focused = false}) => BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: AppRadius.input,
        border: Border.all(
          color: focused ? AppColors.brand : AppColors.separator,
          width: focused ? 1.5 : 1,
        ),
      );

  static BoxDecoration get primaryButton => BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: AppRadius.button,
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );
}
