import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../services/system_setting_service.dart';
import '../constants/api_constants.dart';

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
    return Obx(() {
      final service = Get.isRegistered<SystemSettingService>() 
          ? Get.find<SystemSettingService>() 
          : null;
      
      // Force Obx to rebuild when settings finish loading
      final _ = service?.isLoading.value;
      
      final appLogoPath = service?.getSettingSync('AppLogo');
      
      Widget iconWidget;
      if (appLogoPath != null && appLogoPath.isNotEmpty) {
        final path = appLogoPath.startsWith('/') ? appLogoPath : '/$appLogoPath';
        final url = '${ApiConstants.baseUrl}$path';
        iconWidget = CachedNetworkImage(
          imageUrl: url,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => _buildFallbackIcon(),
        );
      } else {
        iconWidget = Image.asset(
          _iconAsset,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
        );
      }

      if (variant == StayHubLogoVariant.compact) {
        return iconWidget;
      }

      final stayColor =
          theme == StayHubLogoTheme.light ? Colors.white : AppColors.navy;
      final hubColor = theme == StayHubLogoTheme.light
          ? const Color(0xFF7DD3FC)
          : AppColors.brand;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
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
    });
  }

  Widget _buildFallbackIcon() {
    return Icon(
      Icons.travel_explore,
      size: iconSize,
      color: theme == StayHubLogoTheme.light ? Colors.white : AppColors.brand,
    );
  }
}
