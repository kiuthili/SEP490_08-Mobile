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
      height: 64,
      decoration: useGlassBlur
          ? AppDecorations.glass(opacity: 0.82)
          : AppDecorations.card(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final selected = i == selectedIndex;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: AppRadius.navBar,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.isProminent)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brand.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: 24,
                          color: Colors.white,
                        ),
                      )
                    else
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: selected
                            ? BoxDecoration(
                                color: AppColors.brandLight
                                    .withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              )
                            : null,
                        child: Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: 22,
                          color: selected
                              ? AppColors.brand
                              : AppColors.textSecondary,
                        ),
                      ),
                    if (!item.isProminent) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.brand
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom > 0 ? bottom : 16),
      child: useGlassBlur
          ? ClipRRect(
              borderRadius: AppRadius.navBar,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: nav,
              ),
            )
          : ClipRRect(borderRadius: AppRadius.navBar, child: nav),
    );
  }
}
