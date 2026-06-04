import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base {
    try {
      return GoogleFonts.inter(
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );
    } catch (_) {
      return const TextStyle(
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );
    }
  }

  static TextTheme get textTheme => TextTheme(
        displaySmall: _base.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        headlineLarge: _base.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: _base.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleLarge: _base.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: _base.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: _base.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: _base.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        bodyMedium: _base.copyWith(
          fontSize: 15,
          height: 1.4,
        ),
        bodySmall: _base.copyWith(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.35,
        ),
        labelLarge: _base.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: _base.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelSmall: _base.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textTertiary,
          letterSpacing: 0.2,
        ),
      );

  static TextStyle get headlineLarge => textTheme.headlineLarge!;
  static TextStyle get headlineMedium => textTheme.headlineMedium!;
  static TextStyle get titleMedium => textTheme.titleMedium!;
  static TextStyle get bodyMedium => textTheme.bodyMedium!;
  static TextStyle get bodySmall => textTheme.bodySmall!;
}
