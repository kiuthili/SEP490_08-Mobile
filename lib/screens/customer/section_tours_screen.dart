import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/section_tours_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/search_result_tour_card.dart';

class SectionToursScreen extends StatefulWidget {
  const SectionToursScreen({super.key});

  @override
  State<SectionToursScreen> createState() => _SectionToursScreenState();
}

class _SectionToursScreenState extends State<SectionToursScreen> {
  final _controller = Get.put(SectionToursController());
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.fetchTours();
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
        title: Obx(() => Text(
              _controller.title.value,
              style: AppTextStyles.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.brand,
            ),
          );
        }

        if (_controller.tours.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.search,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Không tìm thấy tour nào.',
                  style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _controller.refreshData(),
          color: AppColors.brand,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
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
              if (_controller.isLoadMore.value)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ),
              if (!_controller.hasMore.value && _controller.tours.isNotEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(height: 40),
                ),
            ],
          ),
        );
      }),
    );
  }
}
