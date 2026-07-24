import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/platform_ui.dart';

/// Tiêu đề section kiểu iOS Settings.
class IosSectionHeader extends StatelessWidget {
  const IosSectionHeader(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Nhóm ô trong một card bo góc (Settings-style).
class IosGroupedSection extends StatelessWidget {
  const IosGroupedSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  });

  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final visible = children.where((c) => c is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            IosSectionHeader(header!, padding: EdgeInsets.zero),
          if (header != null) const SizedBox(height: 8),
          ClipRRect(
            borderRadius: AppRadius.card,
            child: Container(
              decoration: AppDecorations.card(),
              child: Column(
                children: _withDividers(visible),
              ),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                footer!,
                style: AppTextStyles.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i < items.length - 1) {
        out.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
    }
    return out;
  }
}

/// Hàng có thể bấm — desktop dùng GestureDetector (tránh lỗi semantics).
class IosPickRow extends StatelessWidget {
  const IosPickRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry margin;

  Widget _buildContent() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle(
                    style: AppTextStyles.textTheme.titleSmall!,
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style: AppTextStyles.textTheme.bodySmall!,
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.brandLight : AppColors.surfaceElevated;
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadius.card,
      side: const BorderSide(color: AppColors.border),
    );

    if (useSimpleTap) {
      return Padding(
        padding: margin,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: bg,
            shape: shape,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: _buildContent(),
          ),
        ),
      );
    }

    return Padding(
      padding: margin,
      child: Material(
        color: bg,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: _buildContent(),
        ),
      ),
    );
  }
}

/// Card nền trắng (nội dung tĩnh).
class IosSurfaceCard extends StatelessWidget {
  const IosSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.color,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;
  final bool selected;

  Color get _background =>
      selected ? AppColors.brandLight : (color ?? AppColors.surfaceElevated);

  @override
  Widget build(BuildContext context) {
    final innerPadding = padding ?? const EdgeInsets.all(16);

    if (onTap != null) {
      if (useSimpleTap) {
        return Padding(
          padding: margin,
          child: DecoratedBox(
            decoration: AppDecorations.card(color: _background),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: innerPadding,
                child: child,
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: margin,
        child: Material(
          color: _background,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.card,
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: innerPadding,
              child: child,
            ),
          ),
        ),
      );
    }

    if (child is ListTile) {
      final tile = child as ListTile;
      return Padding(
        padding: margin,
        child: Material(
          color: _background,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.card,
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding:
                innerPadding == EdgeInsets.zero ? EdgeInsets.zero : null,
            leading: tile.leading,
            title: tile.title,
            subtitle: tile.subtitle,
            trailing: tile.trailing,
            isThreeLine: tile.isThreeLine,
            dense: tile.dense,
            visualDensity: tile.visualDensity,
            onTap: tile.onTap,
          ),
        ),
      );
    }

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: AppDecorations.card(color: _background),
        child: Padding(
          padding: innerPadding,
          child: child,
        ),
      ),
    );
  }
}

/// Mục menu trong grouped section.
class IosMenuTile extends StatelessWidget {
  const IosMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return IosPickRow(
      margin: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.brand).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? AppColors.brand),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded, size: 20)
              : null),
    );
  }
}
