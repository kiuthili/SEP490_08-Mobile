import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late final ReviewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ReviewController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.fetchMyReviews();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Đánh giá của tôi',
      body: RefreshIndicator(
        onRefresh: _controller.fetchMyReviews,
        child: Obx(() {
          if (_controller.isLoading.value &&
              _controller.myReviews.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                LoadingWidget(),
              ],
            );
          }
          if (_controller.myReviews.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                EmptyStateWidget(
                  title: 'Chưa có đánh giá',
                  subtitle: 'Hoàn thành tour và viết đánh giá từ chi tiết đơn',
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: _controller.myReviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final r = _controller.myReviews[index];
              return IosSurfaceCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < r.rating ? Icons.star : Icons.star_border,
                            size: 18,
                            color: Colors.amber,
                          ),
                        ),
                        const Spacer(),
                      TextButton(
                        onPressed: () => Get.toNamed(
                          AppRoutes.tourDetail,
                          arguments: r.tourId,
                        ),
                        child: const Text('Xem tour'),
                      ),
                      ],
                    ),
                    if (r.comment != null && r.comment!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(r.comment!),
                      ),
                    if (r.customerName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          r.customerName!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
