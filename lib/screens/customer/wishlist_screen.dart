import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';
import 'package:stayhub_mobile/theme/app_colors.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late final WishlistController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<WishlistController>();
    _controller.fetchWishlist();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Tour yêu thích',
      body: RefreshIndicator(
        onRefresh: _controller.fetchWishlist,
        child: Obx(() => _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    const physics = AlwaysScrollableScrollPhysics();

    if (_controller.isLoading.value && _controller.items.isEmpty) {
      return ListView(
        physics: physics,
        children: const [
          SizedBox(height: 120),
          LoadingWidget(message: 'Đang tải wishlist...'),
        ],
      );
    }

    if (_controller.items.isEmpty) {
      return ListView(
        physics: physics,
        children: const [
          SizedBox(height: 80),
          EmptyStateWidget(
            title: 'Chưa có tour yêu thích',
            subtitle: 'Nhấn ♥ ở chi tiết tour để lưu',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: physics,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _controller.items.length,
      itemBuilder: (context, index) {
        final item = _controller.items[index];
        final tour = item.tour;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Get.toNamed(
              AppRoutes.tourDetail,
              arguments: item.tourId,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: tour.imageUrl != null && tour.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: tour.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Color(0xFFF0F0F0),
                            child:
                                Icon(Icons.image_outlined, color: Colors.grey),
                          ),
                        )
                      : const ColoredBox(
                          color: Color(0xFFF0F0F0),
                          child: Icon(Icons.image_outlined, color: Colors.grey),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tour.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (tour.city != null)
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 14, color: Colors.black54),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  tour.city!,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black54),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFFFB800), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  tour.averageStar?.toStringAsFixed(1) ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => _controller.toggleWishlist(
                                item.tourId,
                                isInWishlist: true,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.favorite_rounded,
                                    color: AppColors.error, size: 24),
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
    );
  }
}
