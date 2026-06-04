import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum StayHubLogoVariant { full, compact }

enum StayHubLogoTheme { defaultTheme, light }

/// Wordmark + transparent PNG — mirrors web `StayHubLogo.tsx`.
class StayHubLogo extends StatelessWidget {
  const StayHubLogo({
    super.key,
    this.variant = StayHubLogoVariant.full,
    this.theme = StayHubLogoTheme.defaultTheme,
    this.iconSize = 44,
  });

  final StayHubLogoVariant variant;
  final StayHubLogoTheme theme;
  final double iconSize;

  static const String _iconAsset = 'assets/images/stayhub_icon_transparent.png';

  @override
  Widget build(BuildContext context) {
    final icon = Image.asset(
      _iconAsset,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.travel_explore,
        size: iconSize,
        color: theme == StayHubLogoTheme.light ? Colors.white : AppColors.brand,
      ),
    );

    if (variant == StayHubLogoVariant.compact) {
      return icon;
    }

    final stayColor =
        theme == StayHubLogoTheme.light ? Colors.white : AppColors.navy;
    final hubColor = theme == StayHubLogoTheme.light
        ? const Color(0xFF7DD3FC)
        : AppColors.brand;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: iconSize * 0.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: stayColor,
            ),
            children: [
              const TextSpan(text: 'Stay'),
              TextSpan(
                text: 'Hub',
                style: TextStyle(color: hubColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
