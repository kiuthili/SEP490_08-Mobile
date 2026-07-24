import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/tour_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class TourCard extends StatelessWidget {
  final TourModel tour;
  final VoidCallback onTap;
  final String? heroTagPrefix;

  const TourCard({
    super.key,
    required this.tour,
    required this.onTap,
    this.heroTagPrefix,
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
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Hero(
                        tag: heroTagPrefix != null
                            ? '$heroTagPrefix-tour-image-${tour.id}'
                            : 'tour-image-${tour.id}',
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
                                          color: AppColors.brand
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) =>
                                        _placeholderImage(),
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
                    if (tour.averageStar != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _ImageBadge(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFFFB800),
                          label: tour.averageStar!.toStringAsFixed(1),
                        ),
                      ),
                    if (tour.discountPercentage != null &&
                        tour.discountPercentage! > 0)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            '-${tour.discountPercentage!.toStringAsFixed(0)}%',
                            style:
                                AppTextStyles.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
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
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.brandLight,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            size: 15,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tour.locationLabel,
                            style: AppTextStyles.textTheme.bodySmall,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                    if (tour.startingPrice != null ||
                        tour.nextDeparture != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (tour.nextDeparture != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGrouped,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 15,
                                    color: AppColors.brand,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    DateFormatter.display(tour.nextDeparture),
                                    style: AppTextStyles.textTheme.labelMedium
                                        ?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (tour.startingPrice != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tour.originalPrice != null) ...[
                                      Text(
                                        CurrencyFormatter.format(
                                            tour.originalPrice!),
                                        style: AppTextStyles
                                            .textTheme.labelSmall
                                            ?.copyWith(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      'Từ',
                                      style: AppTextStyles.textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                                Text(
                                  CurrencyFormatter.format(
                                    tour.startingPrice!,
                                  ),
                                  style: AppTextStyles.textTheme.titleSmall
                                      ?.copyWith(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
