import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/ai_models.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class AiRecommendationsScreen extends StatelessWidget {
  const AiRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Gợi ý AI',
      actions: [
        IconButton(
          tooltip: 'Làm lại khảo sát',
          icon: const Icon(Icons.psychology_outlined),
          onPressed: () => Get.toNamed(AppRoutes.aiQuestionnaire),
        ),
      ],
      body: AiRecommendationsTab(
        onRetake: () => Get.toNamed(AppRoutes.aiQuestionnaire),
      ),
    );
  }
}

class AiRecommendationsTab extends StatelessWidget {
  const AiRecommendationsTab({super.key, this.onRetake});

  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context) {
    final ai = Get.find<AiController>();
    if (ai.recommendations.isEmpty && !ai.isLoading.value) {
      ai.fetchRecommendations();
    }

    return RefreshIndicator(
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
                onRetry:
                    onRetake ?? () => Get.toNamed(AppRoutes.aiQuestionnaire),
              ),
            ],
          );
        }
        final detail = ai.recommendationDetail.value;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (detail != null) ...[
              _AiDeepAnalysisCard(detail: detail),
              if (detail.weatherAdvice != null)
                _WeatherAdviceCard(weather: detail.weatherAdvice!),
              _TipsTabsCard(detail: detail),
              _DestinationTipsCard(detail: detail),
              _RelatedInsightsCard(insights: detail.relatedInsights),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Tour phù hợp',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...ai.recommendations.map((rec) => _RecommendationTile(rec: rec)),
            if (detail?.nearbyScheduleTours.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Lịch gần phù hợp',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...detail!.nearbyScheduleTours
                  .take(4)
                  .map((rec) => _RecommendationTile(rec: rec, nearby: true)),
            ],
          ],
        );
      }),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.rec, this.nearby = false});

  final TourRecommendationModel rec;
  final bool nearby;

  @override
  Widget build(BuildContext context) {
    return IosSurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: () => Get.toNamed(AppRoutes.tourDetail, arguments: rec.tourId),
        leading: nearby
            ? const Icon(Icons.event_available_rounded)
            : rec.imageUrl != null
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
  }
}

class _AiDeepAnalysisCard extends StatelessWidget {
  const _AiDeepAnalysisCard({required this.detail});

  final PersonalizedRecommendationModel detail;

  @override
  Widget build(BuildContext context) {
    final meta = detail.recommenderMeta;
    final scheduleMessage = detail.scheduleAvailability?.customerMessage;
    final weights = meta?.dimensionWeights.entries.take(4).toList() ?? [];

    return IosSurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.analytics_outlined,
            title: 'Phân tích AI chuyên sâu',
          ),
          if (detail.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(detail.summary),
          ],
          if (scheduleMessage != null && scheduleMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoPill(icon: Icons.event_rounded, text: scheduleMessage),
          ],
          if (meta != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (meta.modelFamily.isNotEmpty)
                  _InfoPill(icon: Icons.memory_rounded, text: meta.modelFamily),
                if (meta.modelVersion.isNotEmpty)
                  _InfoPill(
                    icon: Icons.verified_outlined,
                    text: 'Model ${meta.modelVersion}',
                  ),
                _InfoPill(
                  icon: Icons.groups_rounded,
                  text: 'Fairness ${meta.fairnessAlpha.toStringAsFixed(2)}',
                ),
              ],
            ),
            if (meta.aggregationFormula.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                meta.aggregationFormula,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            if (weights.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: weights
                    .map(
                      (entry) => Chip(
                        label: Text(
                          '${_labelize(entry.key)} ${(entry.value * 100).toStringAsFixed(0)}%',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WeatherAdviceCard extends StatelessWidget {
  const _WeatherAdviceCard({required this.weather});

  final WeatherAdviceModel weather;

  @override
  Widget build(BuildContext context) {
    return IosSurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.wb_cloudy_outlined,
            title: 'Thời tiết',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  weather.city,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (weather.dataSource.isNotEmpty)
                Text(
                  weather.dataSource,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (weather.avgMaxTempC != null)
                _InfoPill(
                  icon: Icons.thermostat_rounded,
                  text: 'Cao ${weather.avgMaxTempC!.toStringAsFixed(1)}°C',
                ),
              if (weather.avgMinTempC != null)
                _InfoPill(
                  icon: Icons.ac_unit_rounded,
                  text: 'Thấp ${weather.avgMinTempC!.toStringAsFixed(1)}°C',
                ),
              if (weather.totalRainMm != null)
                _InfoPill(
                  icon: Icons.water_drop_outlined,
                  text: 'Mưa ${weather.totalRainMm!.toStringAsFixed(1)} mm',
                ),
            ],
          ),
          if (weather.summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(weather.summary),
          ],
          if (weather.impactOnTours.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              weather.impactOnTours,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TipsTabsCard extends StatefulWidget {
  const _TipsTabsCard({required this.detail});

  final PersonalizedRecommendationModel detail;

  @override
  State<_TipsTabsCard> createState() => _TipsTabsCardState();
}

class _TipsTabsCardState extends State<_TipsTabsCard> {
  String _active = 'general';

  @override
  Widget build(BuildContext context) {
    final tabs = <({String key, String label, List<String> tips})>[
      (key: 'general', label: 'Chung', tips: widget.detail.generalTips),
      (
        key: 'foreign',
        label: 'Khách quốc tế',
        tips: widget.detail.foreignVisitorTips,
      ),
      (
        key: 'elderly',
        label: 'Người lớn tuổi',
        tips: widget.detail.elderlyCompanionTips,
      ),
      (
        key: 'children',
        label: 'Gia đình',
        tips: widget.detail.childrenCompanionTips,
      ),
    ].where((tab) => tab.tips.isNotEmpty).toList();

    if (tabs.isEmpty) return const SizedBox.shrink();
    if (!tabs.any((tab) => tab.key == _active)) _active = tabs.first.key;
    final tips = tabs.firstWhere((tab) => tab.key == _active).tips;

    return IosSurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.lightbulb_outline,
            title: 'Mẹo du lịch',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tabs.map((tab) {
              return ChoiceChip(
                label: Text(tab.label),
                selected: tab.key == _active,
                onSelected: (_) => setState(() => _active = tab.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          ...tips.take(8).map((tip) => _TipLine(text: tip)),
        ],
      ),
    );
  }
}

class _DestinationTipsCard extends StatelessWidget {
  const _DestinationTipsCard({required this.detail});

  final PersonalizedRecommendationModel detail;

  @override
  Widget build(BuildContext context) {
    final allowedCities = detail.recommendedTours
        .map((tour) => tour.city?.trim())
        .whereType<String>()
        .where((city) => city.isNotEmpty)
        .toSet();
    final facts = detail.culturalFacts.where((fact) {
      final city = fact.city?.trim();
      return city != null && city.isNotEmpty && allowedCities.contains(city);
    }).toList();

    if (facts.isEmpty) return const SizedBox.shrink();
    final grouped = <String, List<CulturalFactModel>>{};
    for (final fact in facts) {
      grouped.putIfAbsent(fact.city!, () => []).add(fact);
    }

    return IosSurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.place_outlined,
            title: 'Mẹo cho điểm đến',
          ),
          const SizedBox(height: 10),
          ...grouped.entries.take(3).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoPill(icon: Icons.location_on_outlined, text: entry.key),
                  const SizedBox(height: 6),
                  ...entry.value
                      .take(3)
                      .map((fact) => _TipLine(text: _formatFact(fact.fact))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RelatedInsightsCard extends StatelessWidget {
  const _RelatedInsightsCard({required this.insights});

  final List<TourismInsightModel> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    return IosSurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.manage_search_outlined,
            title: 'Insight liên quan',
          ),
          const SizedBox(height: 10),
          ...insights.take(4).map((insight) {
            final meta = [
              insight.city,
              insight.authorityLevel,
              insight.sourceName,
            ].whereType<String>().where((e) => e.isNotEmpty).join(' • ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (insight.description != null &&
                      insight.description!.isNotEmpty)
                    Text(
                      insight.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        meta,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brand, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brand),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isHeader = text.endsWith(':') && text.length < 96;
    if (isHeader) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7, right: 8),
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _formatFact(String fact) {
  final parts = fact.split(RegExp(r'[:：]'));
  if (parts.length < 2 || parts.first.length > 80) return fact;
  return parts.skip(1).join(':').trim();
}

String _labelize(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
