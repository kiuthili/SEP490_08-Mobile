import 'package:flutter/material.dart';

/// StayHub + nền iOS hiện đại (sáng, glass, depth).
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFF0068E0);
  static const Color brandHover = Color(0xFF0058D0);
  static const Color brandDeep = Color(0xFF0048B0);
  static const Color brandLight = Color(0xFFE8F2FF);

  static const Color accent = Color(0xFFEB662B);
  static const Color accentHover = Color(0xFFD95A22);
  static const Color accentLight = Color(0xFFFFF1EB);

  static const Color navy = Color(0xFF05073C);

  static const Color primary = brand;
  static const Color primaryDark = brandDeep;
  static const Color secondary = accent;

  /// Nền app — xám xanh nhạt kiểu iOS Settings.
  static const Color background = Color(0xFFF2F4F8);
  static const Color backgroundSecondary = Color(0xFFE8ECF4);

  static const Color surface = Colors.white;
  static const Color surfaceElevated = Color(0xFFFCFDFF);
  static const Color surfaceGrouped = Color(0xFFF7F8FC);

  static const Color glassFill = Color(0xF5FFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);

  static const Color inputFill = Color(0xFFF5F6FA);
  static const Color separator = Color(0x1F3C3C43);
  static const Color fillTertiary = Color(0x1E767680);

  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFFAEAEB2);

  static const Color error = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);

  static const Color border = Color(0x1405073C);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF1A7AFF), brand, brandDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient homeHeroGradient = LinearGradient(
    colors: [Color(0xFF05073C), Color(0xFF0048B0), Color(0xFF1485FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0, 0.58, 1],
  );

  static const LinearGradient authHeroGradient = LinearGradient(
    colors: [
      Color(0xFF05073C),
      Color(0xFF0A1628),
      Color(0xFF0048B0),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pageGradient = LinearGradient(
    colors: [Color(0xFFF8FAFF), background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
