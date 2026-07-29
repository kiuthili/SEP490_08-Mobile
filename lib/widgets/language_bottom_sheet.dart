import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_colors.dart';

class LanguageBottomSheet extends StatelessWidget {
  const LanguageBottomSheet({super.key, required this.selected, required this.onSelect});
  
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final languages = [
      ('vi', '🇻🇳', 'Tiếng Việt'),
      ('en', '🇺🇸', 'English'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'choose_language'.tr,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...languages.map((lang) => ListTile(
                  leading: Text(lang.$2, style: const TextStyle(fontSize: 26)),
                  title: Text(lang.$3,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: selected == lang.$1
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.brand)
                      : null,
                  onTap: () => onSelect(lang.$1),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
