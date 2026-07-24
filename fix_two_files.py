import os
import re

files_to_fix = [
    "/home/kiuthi/Storage/Projects/Mobile/SEP490_08-Mobile/lib/screens/customer/social_map_screen.dart",
    "/home/kiuthi/Storage/Projects/Mobile/SEP490_08-Mobile/lib/widgets/moment_card.dart"
]

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    original_content = content
    
    # Colors
    content = re.sub(r'Colors\.red', 'AppColors.error', content)
    content = re.sub(r'Colors\.green', 'AppColors.success', content)
    content = re.sub(r'Color\(0xFF0068E0\)', 'AppColors.brand', content)
    content = re.sub(r'Color\(0xFF10B981\)', 'AppColors.success', content) 
    content = re.sub(r'Color\(0xFF059669\)', 'AppColors.success', content)
    content = re.sub(r'Color\(0xFF34D399\)', 'AppColors.success', content)
    content = re.sub(r'Color\(0xFF1E1E1E\)', 'AppColors.textPrimary', content)
    content = re.sub(r'Color\(0xFF111111\)', 'AppColors.textPrimary', content)
    content = re.sub(r'Color\(0xFFBAE6FF\)', 'AppColors.brandLight', content)
    content = re.sub(r'Color\(0xFFF5F5F5\)', 'AppColors.backgroundSecondary', content)
    
    # BorderRadius
    content = re.sub(r'BorderRadius\.circular\((4|8|8\.0|4\.0)\)', r'BorderRadius.circular(AppRadius.xs)', content)
    content = re.sub(r'BorderRadius\.circular\((10|12|10\.0|12\.0)\)', r'BorderRadius.circular(AppRadius.sm)', content)
    content = re.sub(r'BorderRadius\.circular\((14|16|14\.0|16\.0)\)', r'BorderRadius.circular(AppRadius.md)', content)
    content = re.sub(r'BorderRadius\.circular\((20|24|20\.0|24\.0)\)', r'BorderRadius.circular(AppRadius.lg)', content)
    content = re.sub(r'BorderRadius\.circular\((999|999\.0)\)', r'BorderRadius.circular(AppRadius.pill)', content)

    # Typography
    content = re.sub(r'GoogleFonts\.outfit\(', 'AppTextStyles.bodyMedium.copyWith(', content)

    # Fix const AppColors
    content = re.sub(r'const\s+AppColors\.', 'AppColors.', content)

    # Specific manual fixes from earlier
    content = content.replace('AppColors.errorAccent', 'AppColors.error')
    content = content.replace('AppColors.error.shade600', 'AppColors.error')
    content = content.replace('AppColors.success.shade600', 'AppColors.success')
    content = content.replace('AppColors.success.shade700', 'AppColors.success')
    content = content.replace('AppColors.success.shade50', 'AppColors.success.withValues(alpha: 0.1)')
    content = content.replace('AppColors.error.shade300', 'AppColors.error')

    if content != original_content:
        imports_needed = []
        if 'AppColors' in content and 'app_colors.dart' not in content:
            imports_needed.append("import 'package:stayhub_mobile/theme/app_colors.dart';")
        if 'AppRadius' in content and 'app_radius.dart' not in content:
            imports_needed.append("import 'package:stayhub_mobile/theme/app_radius.dart';")
        if 'AppTextStyles' in content and 'app_text_styles.dart' not in content:
            imports_needed.append("import 'package:stayhub_mobile/theme/app_text_styles.dart';")
            
        if imports_needed:
            lines = content.split('\n')
            last_import_idx = -1
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    last_import_idx = i
            
            if last_import_idx != -1:
                lines[last_import_idx:last_import_idx+1] = [lines[last_import_idx]] + imports_needed
                content = '\n'.join(lines)
            else:
                content = '\n'.join(imports_needed) + '\n\n' + content

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Refactored: {filepath}")

for f in files_to_fix:
    process_file(f)
