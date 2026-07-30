import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/platform_ui.dart';

class IosBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isProminent;

  const IosBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isProminent = false,
  });
}

/// Tab bar nổi kiểu iOS 26 — glass blur, bo góc lớn.
class IosBottomNav extends StatelessWidget {
  const IosBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<IosBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Nền đặc hơn để nổi bật khỏi content phía sau
    final navBgColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.97);

    final nav = Container(
      height: 72,
      decoration: BoxDecoration(
        color: navBgColor,
        // Border trên & toàn viền rõ hơn
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFF0068E0).withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, -8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF05073C).withValues(alpha: 0.10),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, -8),
                ),
                BoxShadow(
                  color: const Color(0xFF05073C).withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final selected = i == selectedIndex;

          if (item.isProminent) {
            return GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                transform: Matrix4.identity()
                  ..scale(selected ? 1.08 : 1.0),
                transformAlignment: Alignment.center,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand
                          .withValues(alpha: selected ? 0.55 : 0.30),
                      blurRadius: selected ? 20 : 10,
                      spreadRadius: selected ? 1 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            );
          }

          return GestureDetector(
            onTap: () => onSelect(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 16 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brand.withValues(alpha: isDark ? 0.20 : 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: selected
                    ? Border.all(
                        color: AppColors.brand
                            .withValues(alpha: isDark ? 0.30 : 0.15),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      key: ValueKey(selected),
                      size: 24,
                      color: selected
                          ? AppColors.brand
                          : (isDark
                              ? const Color(0xFF636366)
                              : const Color(0xFFAEAEB2)),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );

    final borderRadius = BorderRadius.circular(28);

    return Padding(
      padding:
          EdgeInsets.fromLTRB(12, 0, 12, (bottom > 0 ? bottom : 12) + 10),
      child: useGlassBlur
          ? ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: nav,
                ),
              ),
            )
          : ClipRRect(borderRadius: borderRadius, child: nav),
    );
  }
}
