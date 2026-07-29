import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Widget avatar an toàn: tự động fallback sang initial-letter placeholder
/// khi URL là SVG (dicebear, v.v.) hoặc khi load ảnh thất bại.
///
/// Dùng thay thế cho mọi nơi hiển thị [CachedNetworkImage] cho avatar.
class SafeAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const SafeAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 22,
    this.backgroundColor,
    this.textColor,
    this.border,
    this.boxShadow,
  });

  bool get _isSvg {
    if (imageUrl == null || imageUrl!.isEmpty) return false;
    final lower = imageUrl!.toLowerCase();
    return lower.endsWith('.svg') ||
        lower.contains('/svg?') ||
        lower.contains('/svg/') ||
        lower.contains('dicebear.com');
  }

  String get _initial {
    if (name == null || name!.trim().isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final bgColor = backgroundColor ?? AppColors.brand;

    Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: border,
        boxShadow: boxShadow,
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );

    final hasValidUrl = imageUrl != null && imageUrl!.isNotEmpty && !_isSvg;

    if (!hasValidUrl) return placeholder;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
        boxShadow: boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: (_, __) => Container(color: bgColor),
        errorWidget: (_, __, ___) => Container(
          color: bgColor,
          alignment: Alignment.center,
          child: Text(
            _initial,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.7,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tương tự [SafeAvatar] nhưng trả về [ImageProvider] để dùng với
/// [CircleAvatar.backgroundImage] hoặc [DecorationImage].
/// Nếu URL là SVG hoặc null, trả về null (dùng child thay thế).
ImageProvider? safeAvatarImageProvider(String? url) {
  if (url == null || url.isEmpty) return null;
  final lower = url.toLowerCase();
  final isSvg = lower.endsWith('.svg') ||
      lower.contains('/svg?') ||
      lower.contains('/svg/') ||
      lower.contains('dicebear.com');
  if (isSvg) return null;
  return CachedNetworkImageProvider(url);
}
