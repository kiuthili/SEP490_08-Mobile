import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/social_models.dart';
import '../theme/app_colors.dart';

class MomentCard extends StatelessWidget {
  final MomentModel moment;
  final int currentUserId;
  final Function(int) onDelete;
  final Function(bool) onLike;
  final VoidCallback? onComment;
  final Function(int)? onReport;
  final bool isDetail;
  final VoidCallback? onShare;

  const MomentCard({
    super.key,
    required this.moment,
    required this.currentUserId,
    required this.onDelete,
    required this.onLike,
    this.onComment,
    this.onReport,
    this.onShare,
    this.isDetail = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = moment.fullName?.trim().isNotEmpty == true
        ? moment.fullName!.trim()[0].toUpperCase()
        : '?';

    return Container(
      margin: EdgeInsets.only(bottom: isDetail ? 0 : 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Time, Options
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.brandLight,
                  radius: 20,
                  backgroundImage: (moment.avatarUrl != null && moment.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(moment.avatarUrl!)
                      : null,
                  child: (moment.avatarUrl == null || moment.avatarUrl!.isEmpty)
                      ? Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moment.fullName ?? 'User',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(moment.createdAt.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (moment.userId == currentUserId || onReport != null)
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'delete') onDelete(moment.id);
                      if (val == 'report') onReport?.call(moment.id);
                    },
                    itemBuilder: (_) => [
                      if (moment.userId == currentUserId)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              SizedBox(width: 8),
                              Text('Xóa bài', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      if (moment.userId != currentUserId && onReport != null)
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, color: AppColors.textPrimary, size: 20),
                              SizedBox(width: 8),
                              Text('Báo cáo vi phạm'),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // Body: Content & Image
          if (moment.caption?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                moment.caption!,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),

          if (moment.imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CachedNetworkImage(
                imageUrl: moment.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: AppColors.surfaceGrouped,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: AppColors.surfaceGrouped,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.textTertiary, size: 40),
                ),
              ),
            ),

          // Footer: Actions (Like, Comment)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => onLike(!moment.isLikedByMe),
                  style: TextButton.styleFrom(
                    foregroundColor: moment.isLikedByMe ? AppColors.brand : AppColors.textSecondary,
                  ),
                  icon: Icon(
                    moment.isLikedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 20,
                  ),
                  label: Text(moment.reactionCount > 0 ? '${moment.reactionCount}' : 'Thích'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onComment,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  label: const Text('Bình luận'),
                ),
                if (onShare != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onShare,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: const Text('Chia sẻ'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}