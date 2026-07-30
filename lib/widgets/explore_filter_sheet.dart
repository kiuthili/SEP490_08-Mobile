import 'package:flutter/material.dart';
import '../models/explore_filters.dart';
import '../services/catalog_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class ExploreFilterSheet extends StatefulWidget {
  const ExploreFilterSheet({
    super.key,
    required this.initial,
    required this.categories,
    required this.onApply,
  });

  final ExploreFilters initial;
  final List<CategoryModel> categories;
  final ValueChanged<ExploreFilters> onApply;

  @override
  State<ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<ExploreFilterSheet> {
  late ExploreFilters _filters;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
    _cityController = TextEditingController(text: _filters.city);
    _countryController = TextEditingController(text: _filters.country);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = isStart ? today : (_filters.startDate ?? today);
    final current = isStart ? _filters.startDate : _filters.endDate;
    final initialDate =
        current != null && !current.isBefore(firstDate) ? current : firstDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _filters = _filters.copyWith(
          startDate: picked,
          clearEndDate: _filters.endDate?.isBefore(picked) ?? false,
        );
      } else {
        _filters = _filters.copyWith(endDate: picked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: AppColors.background,
          borderRadius: AppRadius.sheet,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bộ lọc tour',
                            style: AppTextStyles.textTheme.titleLarge,
                          ),
                          Text(
                            'Tùy chỉnh chuyến đi phù hợp nhất',
                            style: AppTextStyles.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filters = ExploreFilters(
                            searchTerm: _filters.searchTerm,
                          );
                          _cityController.clear();
                          _countryController.clear();
                        });
                      },
                      child: const Text('Đặt lại'),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  children: [
                    _FilterSection(
                      icon: Icons.location_on_rounded,
                      title: 'Điểm đến',
                      subtitle: 'Bạn muốn khám phá nơi nào?',
                      child: Column(
                        children: [
                          TextField(
                            decoration: _inputDecoration(
                              label: 'Thành phố',
                              icon: Icons.location_city_rounded,
                            ),
                            controller: _cityController,
                            onChanged: (value) =>
                                _filters = _filters.copyWith(city: value),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: _inputDecoration(
                              label: 'Quốc gia',
                              icon: Icons.public_rounded,
                            ),
                            controller: _countryController,
                            onChanged: (value) =>
                                _filters = _filters.copyWith(country: value),
                          ),
                        ],
                      ),
                    ),
                    _FilterSection(
                      icon: Icons.category_rounded,
                      title: 'Danh mục',
                      subtitle: 'Chọn phong cách chuyến đi',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: _filters.categoryId == null,
                            onSelected: (_) => setState(
                              () => _filters =
                                  _filters.copyWith(clearCategory: true),
                            ),
                          ),
                          ...widget.categories.map(
                            (category) => ChoiceChip(
                              label: Text(category.name),
                              selected: _filters.categoryId == category.id,
                              onSelected: (_) => setState(
                                () => _filters = _filters.copyWith(
                                  categoryId: category.id,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FilterSection(
                      icon: Icons.payments_rounded,
                      title: 'Ngân sách',
                      subtitle: 'Khoảng giá cho mỗi khách',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _ValueTile(
                                  label: 'Từ',
                                  value: CurrencyFormatter.format(
                                    _filters.minPrice,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              Expanded(
                                child: _ValueTile(
                                  label: 'Đến',
                                  value: _filters.maxPriceValue >=
                                          ExploreFilters.maxPrice
                                      ? 'Không giới hạn'
                                      : CurrencyFormatter.format(
                                          _filters.maxPriceValue,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          RangeSlider(
                            values: RangeValues(
                              _filters.minPrice.toDouble(),
                              _filters.maxPriceValue.toDouble(),
                            ),
                            min: 0,
                            max: ExploreFilters.maxPrice.toDouble(),
                            divisions: 40,
                            onChanged: (value) => setState(() {
                              _filters = _filters.copyWith(
                                minPrice: value.start.round(),
                                maxPriceValue: value.end.round(),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    _FilterSection(
                      icon: Icons.calendar_month_rounded,
                      title: 'Thời gian',
                      subtitle: 'Ngày khởi hành và độ dài tour',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _DateButton(
                                  label: 'Từ ngày',
                                  value: DateFormatter.display(
                                    _filters.startDate,
                                  ),
                                  selected: _filters.startDate != null,
                                  onTap: () => _pickDate(isStart: true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DateButton(
                                  label: 'Đến ngày',
                                  value: DateFormatter.display(
                                    _filters.endDate,
                                  ),
                                  selected: _filters.endDate != null,
                                  onTap: () => _pickDate(isStart: false),
                                ),
                              ),
                            ],
                          ),
                          if (_filters.startDate != null ||
                              _filters.endDate != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setState(
                                  () => _filters = _filters.copyWith(
                                    clearStartDate: true,
                                    clearEndDate: true,
                                  ),
                                ),
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                label: const Text('Xóa ngày'),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Thời lượng tối đa',
                                style: AppTextStyles.textTheme.labelMedium,
                              ),
                              const Spacer(),
                              Text(
                                _filters.durationDays == 0
                                    ? 'Bất kỳ'
                                    : '${_filters.durationDays} ngày',
                                style: AppTextStyles.textTheme.titleSmall
                                    ?.copyWith(color: AppColors.brand),
                              ),
                            ],
                          ),
                          Slider(
                            value: _filters.durationDays.toDouble(),
                            min: 0,
                            max: ExploreFilters.maxDurationDays.toDouble(),
                            divisions: ExploreFilters.maxDurationDays,
                            label: _filters.durationDays == 0
                                ? 'Bất kỳ'
                                : '${_filters.durationDays} ngày',
                            onChanged: (value) => setState(
                              () => _filters = _filters.copyWith(
                                durationDays: value.round(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FilterSection(
                      icon: Icons.swap_vert_rounded,
                      title: 'Sắp xếp',
                      subtitle: 'Ưu tiên kết quả hiển thị',
                      child: RadioGroup<String?>(
                        groupValue: _filters.sortBy,
                        onChanged: (value) => setState(
                          () => _filters = _filters.copyWith(
                            sortBy: value,
                            clearSort: value == null,
                          ),
                        ),
                        child: Column(
                          children: exploreSortOptions.entries
                              .map(
                                (entry) => RadioListTile<String?>(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.value),
                                  value: entry.key,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: FilledButton.icon(
                    onPressed: () {
                      widget.onApply(
                        _filters.copyWith(
                          city: _cityController.text.trim(),
                          country: _countryController.text.trim(),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Áp dụng bộ lọc'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: AppColors.brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.textTheme.titleSmall),
                    Text(subtitle, style: AppTextStyles.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrouped,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandLight : AppColors.surfaceGrouped,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: selected ? AppColors.brand : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.textTheme.labelSmall),
                    Text(
                      selected ? value : 'Chọn ngày',
                      maxLines: 1,
                      style: AppTextStyles.textTheme.labelMedium?.copyWith(
                        color: selected
                            ? AppColors.brandDeep
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
