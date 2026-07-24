import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/social_models.dart';
import '../theme/app_colors.dart';
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
    final hasImage = moment.imageUrl.isNotEmpty;
    
    // Nếu là ảnh ngang quá mức, AspectRatio 4/5 sẽ crop center. 
    // Nếu không có ảnh, dùng một gradient nhẹ.
    
    return Container(
      margin: EdgeInsets.only(bottom: isDetail ? 0 : 24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceGrouped,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: AspectRatio(
        aspectRatio: 0.85, // Locket style: slightly vertical
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Image or Gradient
            if (hasImage)
              CachedNetworkImage(
                imageUrl: moment.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceElevated,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceElevated,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.textTertiary, size: 40),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF34C3FF), Color(0xFF0068E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

            // 2. Gradients for Text Legibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.2, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Header (Avatar, Name, Time, Menu)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (moment.avatarUrl != null && moment.avatarUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: moment.avatarUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.brand,
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moment.fullName ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm - dd/MM/yyyy')
                              .format(moment.createdAt.toLocal()),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (moment.userId == currentUserId || onReport != null)
                    _buildMoreMenu(context),
                ],
              ),
            ),

            // 4. Caption & Actions
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Caption
                  Expanded(
                    child: moment.caption?.isNotEmpty == true
                        ? Text(
                            moment.caption!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 16),
                  // Actions Column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSolidActionButton(
                        icon: moment.isLikedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        iconColor: moment.isLikedByMe ? Colors.redAccent : Colors.white,
                        label: moment.reactionCount > 0 ? '${moment.reactionCount}' : '',
                        onTap: () => onLike(!moment.isLikedByMe),
                      ),
                      const SizedBox(height: 16),
                      _buildSolidActionButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Bình luận',
                        onTap: onComment ?? () {},
                      ),
                      if (onShare != null) ...[
                        const SizedBox(height: 16),
                        _buildSolidActionButton(
                          icon: Icons.send_rounded,
                          label: 'Chia sẻ',
                          onTap: onShare!,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolidActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 28),
        onSelected: (val) {
          if (val == 'delete') {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Xóa khoảnh khắc'),
                content: const Text(
                    'Bạn có chắc chắn muốn xóa khoảnh khắc này không? Thao tác này không thể hoàn tác.'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Không'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      onDelete(moment.id);
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            );
          }
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
                  Icon(Icons.flag_outlined, color: Colors.black87, size: 20),
                  SizedBox(width: 8),
                  Text('Báo cáo vi phạm'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}