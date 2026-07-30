import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/controllers/review_controller.dart';
import 'package:stayhub_mobile/models/reviewreply_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
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
      title: 'mr_title'.tr,
      body: ColoredBox(
        color: AppColors.surfaceGrouped,
        child: RefreshIndicator(
          onRefresh: _controller.fetchMyReviews,
          child: Obx(() {
            if (_controller.isLoading.value && _controller.myReviews.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  LoadingWidget(),
                ],
              );
            }
            if (_controller.myReviews.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  EmptyStateWidget(
                    title: 'mr_empty_title'.tr,
                    subtitle: 'mr_empty_desc'.tr,
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _controller.myReviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final r = _controller.myReviews[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                              color: AppColors.brand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
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
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (r.createdAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormatter.display(r.createdAt!),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Get.toNamed(
                              AppRoutes.tourDetail,
                              arguments: r.tourId,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGrouped,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'mr_view_tour'.tr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      // ── Rating + comment ────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB800)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFB800),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${r.rating}/5',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7A5500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (r.comment != null &&
                          r.comment!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          r.comment!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ],

                      // ── Replies ─────────────────────────────────
                      if (r.replies.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _RepliesBlock(replies: r.replies),
                      ],
                    ],
                  ),
                );
              },
            );
          }),
        ),
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
        color: AppColors.surfaceGrouped,
        borderRadius: BorderRadius.circular(12),
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
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'mr_organizer_reply'.tr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: AppColors.border,
          ),

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staff avatar
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.border,
            backgroundImage: (reply.userAvatar?.trim().isNotEmpty ?? false)
                ? NetworkImage(reply.userAvatar!.trim())
                : null,
            child: (reply.userAvatar?.trim().isNotEmpty ?? false)
                ? null
                : (reply.userName?.trim().isNotEmpty ?? false)
                    ? Text(
                        reply.userName!.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      )
                    : const Icon(
                        Icons.support_agent_rounded,
                        color: AppColors.textSecondary,
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (reply.createdAt != null)
                      Text(
                        DateFormatter.display(reply.createdAt!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (reply.content?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    reply.content!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
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
