import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/search_result_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class FilterBottomSheet extends StatelessWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SearchResultController>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceGrouped,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'filter'.tr,
                    style: AppTextStyles.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () => Get.back(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      shape: const CircleBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('filter_destination'.tr),
                  const SizedBox(height: 8),
                  _buildCityDropdown(controller),
                  const SizedBox(height: 16),
                  _buildSectionTitle('filter_date_range'.tr),
                  const SizedBox(height: 8),
                  _buildDateRangePicker(context, controller),
                  const SizedBox(height: 16),
                  _buildSectionTitle('filter_category'.tr),
                  const SizedBox(height: 8),
                  _buildCategoryDropdown(controller),
                  const SizedBox(height: 16),
                  _buildSectionTitle('filter_price'.tr),
                  const SizedBox(height: 8),
                  _buildPriceSlider(controller),
                  const SizedBox(height: 16),
                  _buildSectionTitle('filter_duration'.tr),
                  const SizedBox(height: 8),
                  _buildDurationSlider(controller),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding:
                const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 26),
            decoration: const BoxDecoration(
              color: AppColors.surfaceGrouped,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      controller.clearFilters();
                      Get.back();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('filter_clear'.tr,
                        style: const TextStyle(color: AppColors.textPrimary)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      controller.applyFilters();
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Text('filter_apply'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13),
    );
  }

  Widget _buildCityDropdown(SearchResultController controller) {
    return Obx(() {
      if (controller.isLoadingProvinces.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return DropdownButtonFormField<String>(
        value: controller.city.value.isEmpty ? null : controller.city.value,
        style: AppTextStyles.textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
          ),
        ),
        hint: Text('filter_select_city'.tr),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary),
        items: controller.provinces.map((city) {
          return DropdownMenuItem(
            value: city,
            child: Text(city),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) controller.city.value = val;
        },
      );
    });
  }

  Widget _buildCategoryDropdown(SearchResultController controller) {
    return Obx(() {
      return DropdownButtonFormField<int>(
        value: controller.categoryId.value,
        style: AppTextStyles.textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
          ),
        ),
        hint: Text('filter_all_categories'.tr),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary),
        items: controller.categories.map((cat) {
          return DropdownMenuItem<int>(
            value: cat.id,
            child: Text(cat.name),
          );
        }).toList(),
        onChanged: (val) {
          controller.categoryId.value = val;
        },
      );
    });
  }

  Widget _buildDateRangePicker(
      BuildContext context, SearchResultController controller) {
    return Obx(() {
      final start = controller.startDate.value;
      final end = controller.endDate.value;
      String displayText = 'filter_select_date_range'.tr;

      if (start.isNotEmpty && end.isNotEmpty) {
        displayText = '$start ${'to'.tr} $end';
      }

      return InkWell(
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.brand,
                    onPrimary: Colors.white,
                    onSurface: AppColors.textPrimary,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null) {
            final format = DateFormat('yyyy-MM-dd');
            controller.startDate.value = format.format(picked.start);
            controller.endDate.value = format.format(picked.end);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayText,
                style: AppTextStyles.textTheme.bodySmall?.copyWith(
                  color: (start.isNotEmpty && end.isNotEmpty)
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
              const Icon(Icons.calendar_today_outlined,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPriceSlider(SearchResultController controller) {
    return Obx(() {
      final minP = controller.minPrice.value.toDouble();
      final maxP = controller.maxPrice.value.toDouble();

      final formatCurrency =
          NumberFormat.compactCurrency(symbol: 'đ', locale: 'vi_VN');

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatCurrency.format(minP),
                    style: AppTextStyles.textTheme.bodySmall),
                Text(maxP >= 100000000 ? 'filter_max'.tr : formatCurrency.format(maxP),
                    style: AppTextStyles.textTheme.bodySmall),
              ],
            ),
            RangeSlider(
              values: RangeValues(minP, maxP),
              min: 0,
              max: 100000000,
              divisions: 200,
              activeColor: AppColors.brand,
              inactiveColor: Colors.grey[300],
              onChanged: (values) {
                controller.minPrice.value = values.start.round();
                controller.maxPrice.value = values.end.round();
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDurationSlider(SearchResultController controller) {
    return Obx(() {
      final val = controller.duration.value.toDouble();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(val == 0 ? 'filter_any'.tr : 'filter_up_to_days'.trParams({'days': val.round().toString()}),
                    style: AppTextStyles.textTheme.bodySmall),
                Text('filter_days'.trParams({'days': '30'}), style: AppTextStyles.textTheme.bodySmall),
              ],
            ),
            Slider(
              value: val,
              min: 0,
              max: 30,
              divisions: 30,
              activeColor: AppColors.brand,
              inactiveColor: Colors.grey[300],
              onChanged: (value) {
                controller.duration.value = value.round();
              },
            ),
          ],
        ),
      );
    });
  }
}
