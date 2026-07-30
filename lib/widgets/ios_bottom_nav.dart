import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radius.dart';
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

    final nav = Container(
      height: 72,
      decoration: useGlassBlur
          ? AppDecorations.glass(opacity: 0.85)
          : AppDecorations.card(),
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
                transform: Matrix4.identity()..scale(selected ? 1.05 : 1.0),
                transformAlignment: Alignment.center,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: selected ? 0.5 : 0.3),
                      blurRadius: selected ? 16 : 8,
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
                    ? AppColors.brand.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
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
                          : AppColors.textSecondary,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, (bottom > 0 ? bottom : 16) + 10),
      child: useGlassBlur
          ? ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: nav,
              ),
            )
          : ClipRRect(borderRadius: BorderRadius.circular(36), child: nav),
    );
  }
}
