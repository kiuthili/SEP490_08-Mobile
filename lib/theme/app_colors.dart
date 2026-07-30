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

  /// Nền app — xám nhạt đặc trưng của iOS.
  static const Color background = Color(0xFFF2F2F7);
  static const Color backgroundSecondary = Color(0xFFE5E5EA);

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

/// Dark palette — iOS-style dark mode colors.
class AppColorsDark {
  AppColorsDark._();

  static const Color brand = AppColors.brand;
  static const Color brandHover = Color(0xFF3D8FFF);
  static const Color brandDeep = Color(0xFF1A7AFF);
  static const Color brandLight = Color(0xFF1C3A6E);

  static const Color accent = AppColors.accent;
  static const Color accentLight = Color(0xFF3D2010);

  static const Color navy = Color(0xFF05073C);

  /// iOS dark: nền hoàn toàn đen
  static const Color background = Color(0xFF000000);
  static const Color backgroundSecondary = Color(0xFF1C1C1E);

  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceElevated = Color(0xFF2C2C2E);
  static const Color surfaceGrouped = Color(0xFF000000);

  static const Color glassFill = Color(0xD91C1C1E);
  static const Color glassBorder = Color(0x33FFFFFF);

  static const Color inputFill = Color(0xFF2C2C2E);
  static const Color separator = Color(0x5C545458);
  static const Color fillTertiary = Color(0x3D767680);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);

  static const Color error = Color(0xFFFF453A);
  static const Color success = Color(0xFF30D158);

  static const Color border = Color(0x33FFFFFF);

  static const LinearGradient brandGradient = AppColors.brandGradient;

  static const LinearGradient homeHeroGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF0A1628), Color(0xFF003399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0, 0.58, 1],
  );

  static const LinearGradient authHeroGradient = AppColors.authHeroGradient;

  static const LinearGradient pageGradient = LinearGradient(
    colors: [Color(0xFF0A0A0F), background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
