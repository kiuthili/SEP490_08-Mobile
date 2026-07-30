import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/search_suggestion_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/currency_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/tour_card.dart';

class SearchSuggestionScreen extends StatefulWidget {
  const SearchSuggestionScreen({super.key});

  @override
  State<SearchSuggestionScreen> createState() => _SearchSuggestionScreenState();
}

class _SearchSuggestionScreenState extends State<SearchSuggestionScreen> {
  final _controller = Get.put(SearchSuggestionController());

  @override
  void initState() {
    super.initState();
    // Auto focus text field on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGrouped,
      appBar: _buildAppBar(),
      body: Obx(() {
        final query = _controller.searchTerm.value.trim();

        if (query.isNotEmpty) {
          return _buildSuggestionsList();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrendingSection(),
              const SizedBox(height: 24),
              _buildHotToursSection(),
            ],
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surfaceGrouped,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
        onPressed: () => Get.back(),
      ),
      title: Container(
        height: 40,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search_rounded,
                size: 20, color: AppColors.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller.searchController,
                focusNode: _controller.focusNode,
                decoration: InputDecoration(
                  hintText: 'search_hint'.tr,
                  hintStyle: AppTextStyles.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: AppTextStyles.textTheme.bodyMedium,
                textInputAction: TextInputAction.search,
                onSubmitted: _controller.onSearchSubmit,
              ),
            ),
            Obx(() => _controller.searchTerm.value.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      _controller.searchController.clear();
                      _controller.focusNode.requestFocus();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : const SizedBox.shrink()),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_controller.isLoadingSuggestions.value) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child:
              CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
        ),
      );
    }

    if (_controller.suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text(
                'no_search_results'.tr,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _controller.suggestions.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
        itemBuilder: (context, index) {
          final suggestion = _controller.suggestions[index];
          return ListTile(
            leading:
                const Icon(Icons.search_rounded, color: AppColors.textTertiary),
            title: Text(suggestion, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
            onTap: () => _controller.onSearchSubmit(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  size: 20, color: AppColors.brand),
              const SizedBox(width: 8),
              Text(
                'trending_searches'.tr,
                style: AppTextStyles.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_controller.isLoadingTrending.value)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.brand)),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _controller.trendingProvinces.map((province) {
                return GestureDetector(
                  onTap: () => _controller.onSearchSubmit(province),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      province,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildHotToursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.travel_explore_rounded,
                  size: 20, color: AppColors.brand),
              const SizedBox(width: 8),
              Text(
                'most_viewed_tours'.tr,
                style: AppTextStyles.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_controller.isLoadingHotTours.value)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.brand)),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _controller.hotTours.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final tour = _controller.hotTours[index];
                return GestureDetector(
                  onTap: () =>
                      Get.toNamed(AppRoutes.tourDetail, arguments: tour.id),
                  child: Container(
                    width: 160,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              child: SizedBox(
                                height: 90,
                                width: double.infinity,
                                child: tour.imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: tour.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const ColoredBox(
                                                color: AppColors.brandLight),
                                      )
                                    : const ColoredBox(
                                        color: AppColors.brandLight),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: WishlistButton(tourId: tour.id),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tour.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                if (tour.startingPrice != null)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('price_from'.tr,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary)),
                                      Text(
                                        CurrencyFormatter.format(
                                            tour.startingPrice!),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFE53935),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
