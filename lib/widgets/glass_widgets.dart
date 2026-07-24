import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BoxBorder? border;
  final bool animate;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.55,
    this.color = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.border,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBorder = Border.all(
      color: Colors.white.withValues(alpha: 0.4),
      width: 1.0,
    );

    Widget innerContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: borderRadius,
        border: border ?? defaultBorder,
      ),
      child: child,
    );

    if (animate) {
      innerContent = AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: padding,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          borderRadius: borderRadius,
          border: border ?? defaultBorder,
        ),
        child: child,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: innerContent,
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color color;
  final Color iconColor;
  final double size;
  final double blur;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = Colors.white,
    this.iconColor = Colors.black87,
    this.size = 46.0,
    this.blur = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: () {
            onPressed();
          },
          child: GlassContainer(
            blur: blur,
            opacity: 0.7,
            color: color,
            borderRadius: BorderRadius.circular(size / 2),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Icon(icon, color: iconColor, size: size * 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
