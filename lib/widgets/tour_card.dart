import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/tour_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

class TourCard extends StatelessWidget {
  final TourModel tour;
  final VoidCallback onTap;
  final bool? isInWishlist;
  final bool wishlistBusy;
  final VoidCallback? onWishlistTap;

  const TourCard({
    super.key,
    required this.tour,
    required this.onTap,
    this.isInWishlist,
    this.wishlistBusy = false,
    this.onWishlistTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Ink(
          decoration: AppDecorations.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child:
                            tour.imageUrl != null && tour.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: tour.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => ColoredBox(
                                  color: AppColors.brandLight,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.brand.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) =>
                                    _placeholderImage(),
                              )
                            : _placeholderImage(),
                      ),
                      if (isInWishlist != null && onWishlistTap != null)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: isInWishlist!
                                    ? 'Xóa khỏi wishlist'
                                    : 'Thêm vào wishlist',
                                icon: wishlistBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        isInWishlist!
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: isInWishlist!
                                            ? AppColors.error
                                            : AppColors.textSecondary,
                                      ),
                                onPressed: wishlistBusy ? null : onWishlistTap,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tour.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 15,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tour.locationLabel,
                            style: AppTextStyles.textTheme.bodySmall,
                          ),
                        ),
                        if (tour.averageStar != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceGrouped,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Color(0xFFFFB800),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  tour.averageStar!.toStringAsFixed(1),
                                  style: AppTextStyles.textTheme.labelMedium
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
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
