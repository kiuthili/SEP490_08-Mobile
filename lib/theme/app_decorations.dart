import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

class AppDecorations {
  AppDecorations._();

  static BoxDecoration card({Color? color, bool isDark = false}) => BoxDecoration(
        color: color ??
            (isDark ? AppColorsDark.surfaceElevated : AppColors.surfaceElevated),
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isDark ? AppColorsDark.glassBorder : AppColors.glassBorder,
        ),
        boxShadow: isDark ? [] : AppShadows.card,
      );

  static BoxDecoration cardFromContext(BuildContext context, {Color? color}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return card(color: color, isDark: dark);
  }

  static BoxDecoration glass({
    double opacity = 0.78,
    BorderRadius? radius,
    bool isDark = false,
  }) =>
      BoxDecoration(
        color: isDark
            ? AppColorsDark.glassFill.withValues(alpha: opacity)
            : AppColors.glassFill.withValues(alpha: opacity),
        borderRadius: radius ?? AppRadius.navBar,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.65),
          width: 0.5,
        ),
        boxShadow: isDark ? AppShadows.navBarDark : AppShadows.navBar,
      );

  static BoxDecoration glassFromContext(
    BuildContext context, {
    double opacity = 0.78,
    BorderRadius? radius,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return glass(opacity: opacity, radius: radius, isDark: dark);
  }

  static Widget glassPanel({
    required Widget child,
    BorderRadius? radius,
    EdgeInsetsGeometry? padding,
    double blur = 24,
    bool isDark = false,
  }) {
    final r = radius ?? AppRadius.navBar;
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: glass(radius: r, isDark: isDark),
          child: child,
        ),
      ),
    );
  }

  static Widget glassPanelFromContext(
    BuildContext context, {
    required Widget child,
    BorderRadius? radius,
    EdgeInsetsGeometry? padding,
    double blur = 24,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return glassPanel(
        child: child, radius: radius, padding: padding, blur: blur, isDark: dark);
  }

  static BoxDecoration inputField({
    bool focused = false,
    bool isDark = false,
  }) =>
      BoxDecoration(
        color: isDark ? AppColorsDark.inputFill : AppColors.inputFill,
        borderRadius: AppRadius.input,
        border: Border.all(
          color: focused
              ? AppColors.brand
              : (isDark ? AppColorsDark.separator : AppColors.separator),
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
