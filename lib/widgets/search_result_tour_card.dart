import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/tour_model.dart';
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
                        placeholder: (_, __) =>
                            ColoredBox(
                              color: AppColors.brandLight,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.brand.withValues(alpha: 0.5),
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
                  if (tour.discountPercentage != null && tour.discountPercentage! > 0)
                    Positioned(
                      top: 32,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                      label: tour.locationLabel
                          .split(',')
                          .first,
                      iconColor: Colors.white,
                    ),
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
                                      CurrencyFormatter.format(tour.originalPrice!),
                                      style: AppTextStyles.textTheme.labelSmall?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.textTertiary,
                                        fontSize: 9,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'Từ',
                                    style: AppTextStyles.textTheme.labelSmall?.copyWith(fontSize: 10),
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

