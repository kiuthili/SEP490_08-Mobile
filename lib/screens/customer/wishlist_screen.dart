import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';

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
      title: 'wl_title'.tr,
      body: ColoredBox(
        color: AppColors.surfaceGrouped,
        child: RefreshIndicator(
          onRefresh: _controller.fetchWishlist,
          child: Obx(() => _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    const physics = AlwaysScrollableScrollPhysics();

    if (_controller.isLoading.value && _controller.items.isEmpty) {
      return ListView(
        physics: physics,
        children: [
          const SizedBox(height: 120),
          LoadingWidget(message: 'wl_loading'.tr),
        ],
      );
    }

    if (_controller.items.isEmpty) {
      return ListView(
        physics: physics,
        children: [
          const SizedBox(height: 80),
          EmptyStateWidget(
            title: 'wl_empty_title'.tr,
            subtitle: 'wl_empty_desc'.tr,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: physics,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _controller.items.length,
      itemBuilder: (context, index) {
        final item = _controller.items[index];
        final tour = item.tour;
        return _WishlistCard(
          tour: tour,
          onTap: () => Get.toNamed(AppRoutes.tourDetail, arguments: item.tourId),
          onRemove: () =>
              _controller.toggleWishlist(item.tourId, isInWishlist: true),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.tour,
    required this.onTap,
    required this.onRemove,
  });

  final dynamic tour;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ────────────────────────────────────────────────
              SizedBox(
                width: 112,
                height: 112,
                child: (tour.imageUrl != null && tour.imageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: tour.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ColoredBox(
                          color: AppColors.surfaceGrouped,
                        ),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: AppColors.surfaceGrouped,
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      )
                    : const ColoredBox(
                        color: AppColors.surfaceGrouped,
                        child: Icon(
                          Icons.image_outlined,
                          color: AppColors.textTertiary,
                        ),
                      ),
              ),

              // ── Content ──────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        tour.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // City
                      if (tour.city != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                tour.city!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Rating + remove button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Empty space to push the remove button to the right
                          const Spacer(),

                          // Remove (unfavourite) button
                          GestureDetector(
                            onTap: onRemove,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: AppColors.error,
                                size: 22,
                              ),
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
      ),
    );
  }
}
