import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/review_controller.dart';
import 'package:stayhub_mobile/models/reviewreply_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_formatter.dart';
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
          if (_controller.isLoading.value && _controller.myReviews.isEmpty) {
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
                    // ── Tour name + "Xem tour" ──────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tour icon badge
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.brandLight,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(
                            Icons.map_rounded,
                            size: 18,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.tourName ?? 'Tour #${r.tourId}',
                                style: AppTextStyles.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (r.createdAt != null)
                                Text(
                                  DateFormatter.display(r.createdAt!),
                                  style: AppTextStyles.textTheme.labelSmall
                                      ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => Get.toNamed(
                            AppRoutes.tourDetail,
                            arguments: r.tourId,
                          ),
                          child: const Text('Xem tour'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // ── Rating + comment ────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < r.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 18,
                            color: const Color(0xFFFFB800),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${r.rating}/5',
                          style: AppTextStyles.textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        r.comment!,
                        style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],

                    // ── Replies ─────────────────────────────────
                    if (r.replies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _RepliesBlock(replies: r.replies),
                    ],
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

// ── Replies block ────────────────────────────────────────────────────────────

class _RepliesBlock extends StatelessWidget {
  const _RepliesBlock({required this.replies});

  final List<ReviewReplyModel> replies;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                const Icon(Icons.forum_rounded,
                    size: 14, color: AppColors.brand),
                const SizedBox(width: 6),
                Text(
                  'Phản hồi từ ban tổ chức',
                  style: AppTextStyles.textTheme.labelMedium?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12),

          // Items
          ...replies.map((reply) => _ReplyItem(reply: reply)),
        ],
      ),
    );
  }
}

class _ReplyItem extends StatelessWidget {
  const _ReplyItem({required this.reply});

  final ReviewReplyModel reply;

  @override
  Widget build(BuildContext context) {
    final isLast = true; // padding handled per item
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staff avatar
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.brand,
            backgroundImage: (reply.userAvatar?.trim().isNotEmpty ?? false)
                ? NetworkImage(reply.userAvatar!.trim())
                : null,
            child: (reply.userAvatar?.trim().isNotEmpty ?? false)
                ? null
                : (reply.userName?.trim().isNotEmpty ?? false)
                    ? Text(
                        reply.userName!.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      )
                    : const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reply.userName ?? 'Staff',
                        style: AppTextStyles.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (reply.createdAt != null)
                      Text(
                        DateFormatter.display(reply.createdAt!),
                        style: AppTextStyles.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (reply.content?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    reply.content!,
                    style: AppTextStyles.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
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
