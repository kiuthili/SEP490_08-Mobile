import 'package:flutter/material.dart';
import '../models/explore_filters.dart';
import '../services/catalog_service.dart';
import '../theme/app_colors.dart';

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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      _filters = isStart
          ? _filters.copyWith(startDate: picked)
          : _filters.copyWith(endDate: picked);
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
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    Text('Bộ lọc',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
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
                      child: const Text('Xóa lọc'),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Thành phố',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      controller: _cityController,
                      onChanged: (v) =>
                          _filters = _filters.copyWith(city: v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Quốc gia',
                        prefixIcon: Icon(Icons.public_outlined),
                      ),
                      controller: _countryController,
                      onChanged: (v) =>
                          _filters = _filters.copyWith(country: v),
                    ),
                    const SizedBox(height: 16),
                    Text('Danh mục',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Tất cả'),
                          selected: _filters.categoryId == null,
                          onSelected: (_) => setState(
                            () => _filters =
                                _filters.copyWith(clearCategory: true),
                          ),
                        ),
                        ...widget.categories.map(
                          (c) => FilterChip(
                            label: Text(c.name),
                            selected: _filters.categoryId == c.id,
                            onSelected: (_) => setState(
                              () => _filters =
                                  _filters.copyWith(categoryId: c.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Khoảng giá (VNĐ)',
                        style: Theme.of(context).textTheme.titleSmall),
                    RangeSlider(
                      values: RangeValues(
                        _filters.minPrice.toDouble(),
                        _filters.maxPriceValue.toDouble(),
                      ),
                      min: 0,
                      max: ExploreFilters.maxPrice.toDouble(),
                      divisions: 40,
                      labels: RangeLabels(
                        '${(_filters.minPrice / 1000000).toStringAsFixed(0)}M',
                        _filters.maxPriceValue >= ExploreFilters.maxPrice
                            ? 'Tối đa'
                            : '${(_filters.maxPriceValue / 1000000).toStringAsFixed(0)}M',
                      ),
                      onChanged: (v) => setState(() {
                        _filters = _filters.copyWith(
                          minPrice: v.start.round(),
                          maxPriceValue: v.end.round(),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text('Số ngày tour tối đa: ${_filters.durationDays == 0 ? 'Bất kỳ' : '${_filters.durationDays} ngày'}',
                        style: Theme.of(context).textTheme.bodySmall),
                    Slider(
                      value: _filters.durationDays.toDouble(),
                      min: 0,
                      max: ExploreFilters.maxDurationDays.toDouble(),
                      divisions: ExploreFilters.maxDurationDays,
                      label: _filters.durationDays == 0
                          ? 'Bất kỳ'
                          : '${_filters.durationDays}',
                      onChanged: (v) => setState(
                        () => _filters =
                            _filters.copyWith(durationDays: v.round()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: true),
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _filters.startDate != null
                                  ? _filters.startDateIso!
                                  : 'Từ ngày',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: false),
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _filters.endDate != null
                                  ? _filters.endDateIso!
                                  : 'Đến ngày',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Sắp xếp',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...exploreSortOptions.entries.map(
                      (e) => RadioListTile<String?>(
                        title: Text(e.value),
                        value: e.key,
                        groupValue: _filters.sortBy,
                        onChanged: (v) =>
                            setState(() => _filters = _filters.copyWith(
                                  sortBy: v,
                                  clearSort: v == null,
                                )),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton(
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
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Áp dụng bộ lọc'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
