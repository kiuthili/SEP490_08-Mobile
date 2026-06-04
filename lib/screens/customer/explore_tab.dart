import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/shell_controller.dart';
import '../../models/explore_filters.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../services/catalog_service.dart';
import '../../services/tour_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/explore_filter_sheet.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/tour_card.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _tourService = Get.find<TourService>();
  final _catalog = Get.find<CatalogService>();
  final _shell = Get.find<ShellController>();
  final _aiController = Get.find<AiController>();

  ExploreFilters _filters = ExploreFilters();
  List<CategoryModel> _categories = [];
  List<TourModel> _tours = [];
  var _page = 1;
  var _totalPages = 1;
  var _isLoading = false;
  var _isLoadingMore = false;
  Worker? _searchSeedWorker;
  Worker? _filterOpenWorker;

  @override
  void initState() {
    super.initState();
    _catalog.getCategories().then((c) {
      if (mounted) setState(() => _categories = c);
    });
    _scrollController.addListener(_onScroll);
    _searchSeedWorker = ever(_shell.exploreSearchTerm, (term) {
      if (term != null && term.toString().isNotEmpty) {
        _searchController.text = term.toString();
        _filters = _filters.copyWith(searchTerm: term.toString());
        _shell.exploreSearchTerm.value = null;
        _runSearch(refresh: true);
      }
    });
    _filterOpenWorker = ever(_shell.exploreOpenFilters, (open) {
      if (open == true) {
        _shell.exploreOpenFilters.value = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openFilters();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final seed = _shell.exploreSearchTerm.value;
      if (seed != null && seed.isNotEmpty) {
        _searchController.text = seed;
        _filters = _filters.copyWith(searchTerm: seed);
        _shell.exploreSearchTerm.value = null;
      }
      _runSearch(refresh: true);
      _aiController.fetchRecommendations();
    });
  }

  @override
  void dispose() {
    _searchSeedWorker?.dispose();
    _filterOpenWorker?.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 200 ||
        _isLoadingMore ||
        _page >= _totalPages) {
      return;
    }
    _loadMore();
  }

  Future<void> _runSearch({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _totalPages = 1;
    }
    setState(() => _isLoading = refresh);
    try {
      final result = await _tourService.searchTours(
        page: _page,
        searchTerm: _filters.searchTerm.trim().isEmpty
            ? null
            : _filters.searchTerm.trim(),
        city: _filters.city.trim().isEmpty ? null : _filters.city.trim(),
        country:
            _filters.country.trim().isEmpty ? null : _filters.country.trim(),
        categoryId: _filters.categoryId,
        minPrice: _filters.minPrice > 0 ? _filters.minPrice : null,
        maxPrice: _filters.maxPriceValue < ExploreFilters.maxPrice
            ? _filters.maxPriceValue
            : null,
        startDate: _filters.startDateIso,
        endDate: _filters.endDateIso,
        duration: _filters.durationDays > 0 ? _filters.durationDays : null,
        sortBy: _filters.sortBy,
      );
      setState(() {
        if (refresh) {
          _tours = result.data;
        } else {
          _tours = [..._tours, ...result.data];
        }
        _totalPages = result.totalPages;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_page >= _totalPages) return;
    setState(() => _isLoadingMore = true);
    _page++;
    try {
      final result = await _tourService.searchTours(
        page: _page,
        searchTerm: _filters.searchTerm.trim().isEmpty
            ? null
            : _filters.searchTerm.trim(),
        city: _filters.city.trim().isEmpty ? null : _filters.city.trim(),
        country:
            _filters.country.trim().isEmpty ? null : _filters.country.trim(),
        categoryId: _filters.categoryId,
        minPrice: _filters.minPrice > 0 ? _filters.minPrice : null,
        maxPrice: _filters.maxPriceValue < ExploreFilters.maxPrice
            ? _filters.maxPriceValue
            : null,
        startDate: _filters.startDateIso,
        endDate: _filters.endDateIso,
        duration: _filters.durationDays > 0 ? _filters.durationDays : null,
        sortBy: _filters.sortBy,
      );
      setState(() {
        _tours = [..._tours, ...result.data];
        _totalPages = result.totalPages;
      });
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _submitSearch() {
    _filters = _filters.copyWith(searchTerm: _searchController.text.trim());
    _runSearch(refresh: true);
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExploreFilterSheet(
        initial: _filters,
        categories: _categories,
        onApply: (f) {
          setState(() => _filters = f);
          _runSearch(refresh: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterBadge = _filters.activeFilterCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Khám phá tour'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sắp xếp',
            onSelected: (sort) {
              setState(() {
                _filters = _filters.copyWith(
                  sortBy: sort,
                  clearSort: sort == null,
                );
              });
              _runSearch(refresh: true);
            },
            itemBuilder: (_) => exploreSortOptions.entries
                .map(
                  (e) => PopupMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _runSearch(refresh: true);
          await _aiController.fetchRecommendations();
        },
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            ShellLayout.bottomInset(context),
          ),
          children: [
            IosSurfaceCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Tìm tour, điểm đến...',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _submitSearch(),
                    ),
                  ),
                  IconButton(
                    onPressed: _openFilters,
                    icon: Badge(
                      isLabelVisible: filterBadge > 0,
                      label: Text('$filterBadge'),
                      child: const Icon(Icons.tune_rounded),
                    ),
                  ),
                  FilledButton(
                    onPressed: _submitSearch,
                    child: const Text('Tìm'),
                  ),
                ],
              ),
            ),
            if (_categories.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('Tất cả'),
                      selected: _filters.categoryId == null,
                      onSelected: (_) {
                        setState(
                          () => _filters =
                              _filters.copyWith(clearCategory: true),
                        );
                        _runSearch(refresh: true);
                      },
                    ),
                    ..._categories.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(c.name),
                          selected: _filters.categoryId == c.id,
                          onSelected: (_) {
                            setState(
                              () => _filters =
                                  _filters.copyWith(categoryId: c.id),
                            );
                            _runSearch(refresh: true);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_isLoading && _tours.isEmpty)
              const LoadingWidget(message: 'Đang tải tour...')
            else if (_tours.isEmpty)
              const EmptyStateWidget(
                title: 'Không tìm thấy tour',
                subtitle: 'Thử đổi bộ lọc hoặc từ khóa khác',
              )
            else ...[
              Text(
                '${_tours.length} tour',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              ..._tours.map(
                (tour) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TourCard(
                    tour: tour,
                    onTap: () => Get.toNamed(
                      AppRoutes.tourDetail,
                      arguments: tour.id,
                    ),
                  ),
                ),
              ),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20, color: AppColors.brand),
                const SizedBox(width: 8),
                Text('Gợi ý từ AI',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => Get.toNamed(AppRoutes.aiQuestionnaire),
                  child: const Text('Khảo sát AI'),
                ),
                TextButton(
                  onPressed: () => Get.toNamed(AppRoutes.aiRecommendations),
                  child: const Text('Gợi ý'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (_aiController.isLoading.value &&
                  _aiController.recommendations.isEmpty) {
                return const LoadingWidget();
              }
              if (_aiController.recommendations.isEmpty) {
                return TextButton(
                  onPressed: () => Get.toNamed(AppRoutes.aiQuestionnaire),
                  child: const Text('Bắt đầu khảo sát AI →'),
                );
              }
              return Column(
                children: _aiController.recommendations.take(4).map((rec) {
                  return IosSurfaceCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => Get.toNamed(
                        AppRoutes.tourDetail,
                        arguments: rec.tourId,
                      ),
                      leading: rec.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                rec.imageUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.tour_rounded),
                              ),
                            )
                          : const Icon(Icons.tour_rounded),
                      title: Text(rec.name),
                      subtitle: Text(rec.reason ?? rec.city ?? ''),
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }
}
