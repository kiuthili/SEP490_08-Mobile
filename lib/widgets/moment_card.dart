import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/social_models.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class MomentCard extends StatefulWidget {
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
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartAnimController;
  late Animation<double> _heartScale;
  late Animation<double> _heartFade;

  bool? _isLiked;
  int? _reactionCount;

  @override
  void didUpdateWidget(covariant MomentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment.id != widget.moment.id) {
      _isLiked = null;
      _reactionCount = null;
    } else {
      if (_isLiked != null && widget.moment.isLikedByMe == _isLiked) {
        _isLiked = null;
        _reactionCount = null;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_heartAnimController);

    _heartFade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_heartAnimController);
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  void _triggerDoubleTapLike() {
    HapticFeedback.mediumImpact();

    final currentLiked = _isLiked ?? widget.moment.isLikedByMe;
    if (!currentLiked) {
      setState(() {
        _isLiked = true;
        _reactionCount = widget.moment.reactionCount + 1;
      });
      widget.onLike(true);
    }

    // Start / replay the heart popping animation
    _heartAnimController.reset();
    _heartAnimController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.moment.fullName?.trim().isNotEmpty == true
        ? widget.moment.fullName!.trim()[0].toUpperCase()
        : '?';
    final hasImage = widget.moment.imageUrl.isNotEmpty;

    // Resolve states using local overrides or widget properties
    final isLiked = _isLiked ?? widget.moment.isLikedByMe;
    final reactionCount = _reactionCount ?? widget.moment.reactionCount;

    return Container(
      margin: EdgeInsets.only(bottom: widget.isDetail ? 0 : 24),
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
        child: GestureDetector(
          onDoubleTap: _triggerDoubleTapLike,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image or Gradient
              if (hasImage)
                CachedNetworkImage(
                  imageUrl: widget.moment.imageUrl,
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
                      colors: [Color(0xFF34C3FF), AppColors.brand],
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

              // 3. Premium Double-Tap Heart Overlay Animation
              Center(
                child: AnimatedBuilder(
                  animation: _heartAnimController,
                  builder: (context, child) {
                    if (_heartAnimController.value == 0.0) {
                      return const SizedBox.shrink();
                    }
                    return Opacity(
                      opacity: _heartFade.value,
                      child: Transform.scale(
                        scale: _heartScale.value,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 24,
                                spreadRadius: 4,
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: AppColors.error,
                            size: 100,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 4. Header (Avatar, Name, Time, Menu)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Get.toNamed(
                            AppRoutes.userProfile,
                            arguments: widget.moment.userId,
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26, blurRadius: 4)
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (widget.moment.avatarUrl != null &&
                                      widget.moment.avatarUrl!.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: widget.moment.avatarUrl!,
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
                                    widget.moment.fullName ?? 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      shadows: [
                                        Shadow(
                                            color: Colors.black45,
                                            blurRadius: 4)
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm - dd/MM/yyyy').format(
                                        widget.moment.createdAt.toLocal()),
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      shadows: const [
                                        Shadow(
                                            color: Colors.black45,
                                            blurRadius: 4)
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.moment.userId == widget.currentUserId ||
                        widget.onReport != null)
                      _buildMoreMenu(context),
                  ],
                ),
              ),

              // 5. Caption & Actions
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Caption
                    Expanded(
                      child: widget.moment.caption?.isNotEmpty == true
                          ? Text(
                              widget.moment.caption!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 4)
                                ],
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
                          icon: isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_outline_rounded,
                          iconColor: isLiked ? AppColors.error : Colors.white,
                          label: reactionCount > 0 ? '$reactionCount' : '',
                          onTap: () {
                            final nextState = !isLiked;
                            setState(() {
                              _isLiked = nextState;
                              _reactionCount = widget.moment.reactionCount +
                                  (nextState ? 1 : -1);
                            });
                            widget.onLike(nextState);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildSolidActionButton(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Bình luận',
                          onTap: widget.onComment ?? () {},
                        ),
                        if (widget.onShare != null) ...[
                          const SizedBox(height: 16),
                          _buildSolidActionButton(
                            icon: Icons.send_rounded,
                            label: 'Chia sẻ',
                            onTap: widget.onShare!,
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      child: PopupMenuButton<String>(
        icon:
            const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 28),
        onSelected: (val) {
          if (val == 'delete') {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Xóa khoảnh khắc'),
                content: const Text(
                    'Bạn có chắc chắn muốn xóa khoảnh khắc này không? Thao tác này không thể hoàn tác.'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Không'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      widget.onDelete(widget.moment.id);
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error),
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            );
          }
          if (val == 'report') widget.onReport?.call(widget.moment.id);
        },
        itemBuilder: (_) => [
          if (widget.moment.userId == widget.currentUserId)
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
          if (widget.moment.userId != widget.currentUserId &&
              widget.onReport != null)
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
