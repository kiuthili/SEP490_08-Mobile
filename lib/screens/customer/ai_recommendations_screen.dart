import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class AiRecommendationsScreen extends StatelessWidget {
  const AiRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ai = Get.find<AiController>();
    if (ai.recommendations.isEmpty && !ai.isLoading.value) {
      ai.fetchRecommendations();
    }

    return AppScreen(
      title: 'Gợi ý AI',
      actions: [
        IconButton(
          tooltip: 'Làm lại khảo sát',
          icon: const Icon(Icons.psychology_outlined),
          onPressed: () => Get.toNamed(AppRoutes.aiQuestionnaire),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: ai.fetchRecommendations,
        child: Obx(() {
          if (ai.isLoading.value && ai.recommendations.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                LoadingWidget(message: 'Đang tải gợi ý...'),
              ],
            );
          }
          if (ai.recommendations.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                EmptyStateWidget(
                  title: 'Chưa có gợi ý',
                  subtitle:
                      'Hoàn thành khảo sát AI để nhận danh sách tour phù hợp',
                  retryLabel: 'Bắt đầu khảo sát',
                  onRetry: () => Get.toNamed(AppRoutes.aiQuestionnaire),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: ai.recommendations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final rec = ai.recommendations[index];
              return IosSurfaceCard(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => Get.toNamed(
                    AppRoutes.tourDetail,
                    arguments: rec.tourId,
                  ),
                  leading: rec.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            rec.imageUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.tour_rounded),
                          ),
                        )
                      : const Icon(Icons.tour_rounded, size: 32),
                  title: Text(rec.name),
                  subtitle: Text(rec.reason ?? rec.city ?? ''),
                  trailing: rec.score != null
                      ? Chip(label: Text(rec.score!.toStringAsFixed(1)))
                      : const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
