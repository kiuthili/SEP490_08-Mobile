import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/feature_controllers.dart';
import '../models/tour_model.dart';
import '../routes/app_routes.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency_formatter.dart';

class SearchResultTourCard extends StatelessWidget {
  final TourModel tour;
  final VoidCallback onTap;

  const SearchResultTourCard({
    super.key,
    required this.tour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1, // Square image
                    child: Hero(
                      tag: 'tour-search-image-${tour.id}',
                      child: tour.imageUrl != null && tour.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: tour.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => ColoredBox(
                                color: AppColors.brandLight,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        AppColors.brand.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => _placeholderImage(),
                            )
                          : _placeholderImage(),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x3305073C),
                            Colors.transparent,
                            Color(0x7305073C),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (tour.discountPercentage != null &&
                      tour.discountPercentage! > 0)
                    Positioned(
                      top: 32,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '-${tour.discountPercentage!.toStringAsFixed(0)}%',
                          style: AppTextStyles.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  if (tour.averageStar != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _ImageBadge(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFFFB800),
                        label: tour.averageStar!.toStringAsFixed(1),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _ImageBadge(
                      icon: Icons.place_rounded,
                      label: tour.locationLabel.split(',').first,
                      iconColor: Colors.white,
                    ),
                  ),
                  // ❤️ Wishlist button
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _SearchWishlistButton(tourId: tour.id),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tour.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                      if (tour.startingPrice != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (tour.originalPrice != null) ...[
                                    Text(
                                      CurrencyFormatter.format(
                                          tour.originalPrice!),
                                      style: AppTextStyles.textTheme.labelSmall
                                          ?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.textTertiary,
                                        fontSize: 9,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'from_price'.tr,
                                    style: AppTextStyles.textTheme.labelSmall
                                        ?.copyWith(fontSize: 10),
                                  ),
                                ],
                              ),
                              Text(
                                CurrencyFormatter.format(tour.startingPrice!),
                                style: AppTextStyles.textTheme.titleSmall
                                    ?.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
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

  Widget _placeholderImage() {
    return ColoredBox(
      color: AppColors.brandLight,
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 48,
          color: AppColors.brand.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _ImageBadge extends StatelessWidget {
  const _ImageBadge({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchWishlistButton extends StatelessWidget {
  final int tourId;
  const _SearchWishlistButton({required this.tourId});

  @override
  Widget build(BuildContext context) {
    WishlistController? wishlistCtrl;
    try {
      wishlistCtrl = Get.find<WishlistController>();
    } catch (_) {
      // WishlistController not available on this route
    }

    if (wishlistCtrl == null) return const SizedBox.shrink();
    final ctrl = wishlistCtrl;

    return Obx(() {
      final isInWishlist = ctrl.containsTour(tourId);
      final isProcessing = ctrl.isProcessing(tourId);

      return GestureDetector(
        onTap: () {
          final storage = Get.find<StorageService>();
          if (!storage.isLoggedIn) {
            Get.toNamed(AppRoutes.login);
            return;
          }
          ctrl.toggleWishlist(tourId, isInWishlist: isInWishlist);
        },
        child: AnimatedScale(
          scale: isProcessing ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: isProcessing
                ? const Padding(
                    padding: EdgeInsets.all(7),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Icon(
                      isInWishlist
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(isInWishlist),
                      size: 16,
                      color: isInWishlist
                          ? const Color(0xFFFF4D6D)
                          : Colors.white,
                    ),
                  ),
          ),
        ),
      );
    });
  }
}
