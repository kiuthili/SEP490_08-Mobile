import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/shell_controller.dart';
import '../../models/api_response.dart';
import '../../models/explore_filters.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../services/base_service.dart';
import '../../services/catalog_service.dart';
import '../../services/tour_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/explore_filter_sheet.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../../widgets/tour_card.dart';
import '../../widgets/ai_floating_assistant.dart';
import '../../utils/snackbar_helper.dart';

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
  final _wishlistController = Get.find<WishlistController>();

  ExploreFilters _filters = ExploreFilters();
  List<CategoryModel> _categories = [];
  List<TourModel> _tours = [];
  var _page = 1;
  var _totalPages = 1;
  var _totalResults = 0;
  var _isLoading = false;
  var _isLoadingMore = false;
  String? _errorMessage;
  Timer? _searchDebounce;
  var _requestVersion = 0;
  Worker? _searchSeedWorker;
  Worker? _filterOpenWorker;
  Worker? _wishlistWorker;
  Worker? _wishlistProcessingWorker;
  bool _showScrollToTop = false;

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
    _wishlistWorker = ever(_wishlistController.items, (_) {
      if (mounted) setState(() {});
    });
    _wishlistProcessingWorker = ever(
      _wishlistController.processingTourIds,
      (_) {
        if (mounted) setState(() {});
      },
    );
    _wishlistController.fetchWishlist();
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
    _wishlistWorker?.dispose();
    _wishlistProcessingWorker?.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showScrollToTop = _scrollController.offset > 520;
    if (showScrollToTop != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = showScrollToTop);
    }
    if (_scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 200 ||
        _isLoadingMore ||
        _page >= _totalPages) {
      return;
    }
    _loadMore();
  }

  Future<void> _scrollToTop() {
    return _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _runSearch({bool refresh = false}) async {
    final requestVersion = ++_requestVersion;
    if (refresh) {
      _page = 1;
      _totalPages = 1;
      setState(() {
        _tours = [];
        _totalResults = 0;
        _errorMessage = null;
        _isLoading = true;
      });
    } else {
      setState(() => _errorMessage = null);
    }
    try {
      final result = await _searchPage(_page);
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        if (refresh) {
          _tours = result.data;
        } else {
          _tours = [..._tours, ...result.data];
        }
        _totalPages = result.totalPages;
        _totalResults = result.total;
        _page = result.currentPage;
      });
    } on ApiError catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() => _errorMessage = 'Không tải được danh sách tour');
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_page >= _totalPages || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final requestVersion = _requestVersion;
    try {
      final result = await _searchPage(nextPage);
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        final knownIds = _tours.map((tour) => tour.id).toSet();
        _tours = [
          ..._tours,
          ...result.data.where((tour) => knownIds.add(tour.id)),
        ];
        _page = result.currentPage;
        _totalPages = result.totalPages;
        _totalResults = result.total;
      });
    } on ApiError catch (error) {
      SnackbarHelper.error(error.message);
    } catch (_) {
      SnackbarHelper.error('Không tải thêm được tour');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<PaginationModel<TourModel>> _searchPage(int page) {
    return _tourService.searchTours(
      page: page,
      searchTerm: _filters.searchTerm.trim().isEmpty
          ? null
          : _filters.searchTerm.trim(),
      city: _filters.city.trim().isEmpty ? null : _filters.city.trim(),
      country: _filters.country.trim().isEmpty ? null : _filters.country.trim(),
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
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _filters = _filters.copyWith(searchTerm: value.trim());
      _runSearch(refresh: true);
    });
  }

  void _submitSearch() {
    _searchDebounce?.cancel();
    _filters = _filters.copyWith(searchTerm: _searchController.text.trim());
    FocusScope.of(context).unfocus();
    _runSearch(refresh: true);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _filters = _filters.copyWith(searchTerm: '');
    FocusScope.of(context).unfocus();
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
        title: const Text('Khám phá'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              onPressed: _openFilters,
              style: IconButton.styleFrom(
                foregroundColor: AppColors.brand,
                backgroundColor: AppColors.brandLight,
              ),
              tooltip: 'Bộ lọc',
              icon: Badge(
                isLabelVisible: filterBadge > 0,
                label: Text('$filterBadge'),
                backgroundColor: AppColors.brand,
                textColor: Colors.white,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.pageGradient),
            child: RefreshIndicator(
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
                  _buildExploreHero(filterBadge),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          'Khám phá theo phong cách',
                          style: AppTextStyles.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_categories.length} danh mục',
                          style: AppTextStyles.textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            avatar: _filters.categoryId == null
                                ? const Icon(Icons.apps_rounded, size: 17)
                                : null,
                            label: const Text('Tất cả tour'),
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
                              child: ChoiceChip(
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
                  if (filterBadge > 0) ...[
                    const SizedBox(height: 12),
                    _ActiveFilterBar(
                      filters: _filters,
                      onClear: () {
                        setState(() {
                          _filters = ExploreFilters(
                            searchTerm: _searchController.text.trim(),
                          );
                        });
                        _runSearch(refresh: true);
                      },
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (_isLoading && _tours.isEmpty)
                    const _TourListSkeleton()
                  else if (_errorMessage != null)
                    EmptyStateWidget(
                      icon: Icons.cloud_off_rounded,
                      title: 'Không tải được tour',
                      subtitle: _errorMessage,
                      onRetry: () => _runSearch(refresh: true),
                    )
                  else if (_tours.isEmpty)
                    const EmptyStateWidget(
                      icon: Icons.travel_explore_rounded,
                      title: 'Không tìm thấy tour',
                      subtitle: 'Thử đổi bộ lọc hoặc từ khóa khác',
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.brandLight,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.travel_explore_rounded,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tour dành cho bạn',
                                  style: AppTextStyles.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_totalResults lựa chọn phù hợp',
                                  style: AppTextStyles.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String?>(
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
                                  (entry) => PopupMenuItem(
                                    value: entry.key,
                                    child: Row(
                                      children: [
                                        if (_filters.sortBy == entry.key)
                                          const Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color: AppColors.brand,
                                          )
                                        else
                                          const SizedBox(width: 18),
                                        const SizedBox(width: 8),
                                        Text(entry.value),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.swap_vert_rounded, size: 18),
                                  SizedBox(width: 5),
                                  Text('Sắp xếp'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._tours.asMap().entries.map(
                          (entry) => TweenAnimationBuilder<double>(
                            key: ValueKey(entry.value.id),
                            duration: Duration(
                              milliseconds: 260 + (entry.key.clamp(0, 5) * 45),
                            ),
                            tween: Tween(begin: 0, end: 1),
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 14 * (1 - value)),
                                child: child,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: TourCard(
                                tour: entry.value,
                                isInWishlist: _wishlistController.containsTour(
                                  entry.value.id,
                                ),
                                wishlistBusy: _wishlistController.isProcessing(
                                  entry.value.id,
                                ),
                                onWishlistTap: () =>
                                    _wishlistController.toggleWishlist(
                                  entry.value.id,
                                  isInWishlist:
                                      _wishlistController.containsTour(
                                    entry.value.id,
                                  ),
                                ),
                                onTap: () => Get.toNamed(
                                  AppRoutes.tourDetail,
                                  arguments: entry.value.id,
                                ),
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
                  const SizedBox(height: 18),
                  _buildAiHeader(),
                  const SizedBox(height: 10),
                  Obx(() {
                    if (_aiController.isLoading.value &&
                        _aiController.recommendations.isEmpty) {
                      return const LoadingWidget();
                    }
                    if (_aiController.recommendations.isEmpty) {
                      return TextButton(
                        onPressed: () => showAiAssistantPanel(context),
                        child: const Text('Bắt đầu khảo sát AI →'),
                      );
                    }
                    return Column(
                      children:
                          _aiController.recommendations.take(4).map((rec) {
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
          ),
          ScrollToTopButton(
            visible: _showScrollToTop,
            onTap: _scrollToTop,
          ),
        ],
      ),
    );
  }

  Widget _buildExploreHero(int filterBadge) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF05073C), Color(0xFF0048B0), Color(0xFF1485FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -48,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: Color(0xFFFFD166),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'StayHub Discovery',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Chuyến đi tiếp theo\nđang chờ bạn.',
                style: AppTextStyles.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tìm hành trình phù hợp với lịch trình, sở thích và ngân sách.',
                style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Icon(Icons.search_rounded, color: AppColors.brand),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Bạn muốn đi đâu?',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: _onSearchChanged,
                        onSubmitted: (_) => _submitSearch(),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Xóa từ khóa',
                        onPressed: _clearSearch,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _submitSearch,
                          tooltip: 'Tìm kiếm',
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ExploreHeroStat(
                    icon: Icons.map_rounded,
                    label: _totalResults > 0
                        ? '$_totalResults hành trình'
                        : 'Nhiều hành trình',
                  ),
                  const SizedBox(width: 8),
                  _ExploreHeroStat(
                    icon: Icons.tune_rounded,
                    label: filterBadge > 0
                        ? '$filterBadge bộ lọc'
                        : 'Lọc thông minh',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiHeader() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showAiAssistantPanel(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F2FF), Color(0xFFFFF1EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gợi ý riêng từ AI Guide',
                      style: AppTextStyles.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Trả lời vài câu để tìm chuyến đi hợp gu nhất.',
                      style: AppTextStyles.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreHeroStat extends StatelessWidget {
  const _ExploreHeroStat({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({
    required this.filters,
    required this.onClear,
  });

  final ExploreFilters filters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 18, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${filters.activeFilterCount} bộ lọc đang áp dụng',
              style: AppTextStyles.textTheme.labelMedium?.copyWith(
                color: AppColors.brandDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                'Xóa',
                style: TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TourListSkeleton extends StatelessWidget {
  const _TourListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          height: 310,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
