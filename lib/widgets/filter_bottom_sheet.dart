import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/search_result_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class FilterBottomSheet extends StatelessWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SearchResultController>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), // Balance
                Text(
                  'Bộ lọc',
                  style: AppTextStyles.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.back(),
                  child: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Điểm đến'),
                  const SizedBox(height: 8),
                  _buildCityDropdown(controller),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Ngày đi - Ngày về'),
                  const SizedBox(height: 8),
                  _buildDateRangePicker(context, controller),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Danh mục'),
                  const SizedBox(height: 8),
                  _buildCategoryDropdown(controller),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Mức giá'),
                  const SizedBox(height: 8),
                  _buildPriceSlider(controller),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Thời lượng (ngày)'),
                  const SizedBox(height: 8),
                  _buildDurationSlider(controller),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Xóa lọc'),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Áp dụng'),
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
      style: AppTextStyles.textTheme.labelLarge?.copyWith(
        color: AppColors.textPrimary,
      ),
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
          hintStyle: AppTextStyles.textTheme.bodySmall,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        hint: const Text('Chọn tỉnh/thành phố'),
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
          hintStyle: AppTextStyles.textTheme.bodySmall,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        hint: const Text('Tất cả danh mục'),
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

  Widget _buildDateRangePicker(BuildContext context, SearchResultController controller) {
    return Obx(() {
      final start = controller.startDate.value;
      final end = controller.endDate.value;
      String displayText = 'Chọn ngày đi - về';
      
      if (start.isNotEmpty && end.isNotEmpty) {
        displayText = '$start đến $end';
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
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayText,
                style: AppTextStyles.textTheme.bodySmall?.copyWith(
                  color: (start.isNotEmpty && end.isNotEmpty) ? AppColors.textPrimary : AppColors.textTertiary,
                ),
              ),
              const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textSecondary),
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

      final formatCurrency = NumberFormat.compactCurrency(symbol: 'đ', locale: 'vi_VN');

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatCurrency.format(minP), style: AppTextStyles.textTheme.bodySmall),
              Text(maxP >= 100000000 ? 'Tối đa' : formatCurrency.format(maxP), style: AppTextStyles.textTheme.bodySmall),
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
      );
    });
  }

  Widget _buildDurationSlider(SearchResultController controller) {
    return Obx(() {
      final val = controller.duration.value.toDouble();

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(val == 0 ? 'Bất kỳ' : 'Lên đến ${val.round()} ngày', style: AppTextStyles.textTheme.bodySmall),
              Text('30 ngày', style: AppTextStyles.textTheme.bodySmall),
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
      );
    });
  }
}
