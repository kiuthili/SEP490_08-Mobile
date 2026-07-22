import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/search_result_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/search_result_tour_card.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';

class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({super.key});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  final _controller = Get.put(SearchResultController());
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _controller.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light gray background for grid items
      appBar: AppBar(
        backgroundColor: AppColors.brand,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: GestureDetector(
          onTap: () => Get.back(), // Go back to suggestion screen to search again
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: AppColors.brand.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _controller.currentSearchTerm.isEmpty ? 'Tìm kiếm tour...' : _controller.currentSearchTerm,
                    style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            onPressed: () {
              Get.bottomSheet(
                const FilterBottomSheet(),
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sort Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(() => Text(
                  '${_controller.tours.length} kết quả',
                  style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                )),
                Row(
                  children: [
                    const Icon(Icons.sort_rounded, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Obx(() {
                      return DropdownButton<String>(
                        value: _controller.sortBy.value,
                        isDense: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Đề xuất')),
                          DropdownMenuItem(value: 'price_asc', child: Text('Giá: Thấp đến Cao')),
                          DropdownMenuItem(value: 'price_desc', child: Text('Giá: Cao đến Thấp')),
                          DropdownMenuItem(value: 'date_desc', child: Text('Mới nhất')),
                          DropdownMenuItem(value: 'date_asc', child: Text('Cũ nhất')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _controller.sortBy.value = val;
                            _controller.applyFilters();
                          }
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                );
              }

              if (_controller.tours.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'Không tìm thấy tour nào',
                        style: AppTextStyles.textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.65,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final tour = _controller.tours[index];
                          return SearchResultTourCard(
                            tour: tour,
                            onTap: () => Get.toNamed(AppRoutes.tourDetail, arguments: tour.id),
                          );
                        },
                        childCount: _controller.tours.length,
                      ),
                    ),
                  ),
                  if (_controller.isLoadingMore.value)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

