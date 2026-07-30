import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/ai_models.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class AiRecommendationsScreen extends StatelessWidget {
  const AiRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'ai_recommendations_title'.tr,
      actions: [
        IconButton(
          tooltip: 'ai_user_study_tooltip'.tr,
          icon: const Icon(Icons.rate_review_outlined),
          onPressed: () => Get.toNamed(AppRoutes.userStudy),
        ),
        IconButton(
          tooltip: 'ai_retake_tooltip'.tr,
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

class AiRecommendationsTab extends StatefulWidget {
  const AiRecommendationsTab({super.key, this.onRetake});

  final VoidCallback? onRetake;

  @override
  State<AiRecommendationsTab> createState() => _AiRecommendationsTabState();
}

class _AiRecommendationsTabState extends State<AiRecommendationsTab> {
  String _tourFilter = 'all'; // 'all', 'exact', 'nearby'

  @override
  Widget build(BuildContext context) {
    final ai = Get.find<AiController>();
    if (ai.recommendations.isEmpty && !ai.isLoading.value) {
      ai.fetchRecommendations();
    }

    return Obx(() {
      if (ai.isLoading.value && ai.recommendations.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            LoadingWidget(message: 'ai_loading_recommendations'.tr),
          ],
        );
      }
      final detail = ai.recommendationDetail.value;
      final hasExact = ai.recommendations.isNotEmpty;
      final hasNearby = detail?.nearbyScheduleTours.isNotEmpty == true;

      if (!hasExact && !hasNearby) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            EmptyStateWidget(
              title: 'ai_no_recommendations'.tr,
              subtitle: 'ai_no_recommendations_subtitle'.tr,
              retryLabel: 'ai_start_questionnaire'.tr,
              onRetry: widget.onRetake ??
                  () => Get.toNamed(AppRoutes.aiQuestionnaire),
            ),
          ],
        );
      }

      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              child: TabBar(
                indicatorColor: AppColors.brand,
                labelColor: AppColors.brand,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.tour_rounded),
                    text: 'ai_tab_tours'.tr,
                  ),
                  Tab(
                    icon: const Icon(Icons.menu_book_rounded),
                    text: 'ai_tab_guide'.tr,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Tours
                  RefreshIndicator(
                    onRefresh: ai.fetchRecommendations,
                    child: _buildToursTab(context, ai, detail),
                  ),
                  // Tab 2: AI Guide
                  RefreshIndicator(
                    onRefresh: ai.fetchRecommendations,
                    child: _buildAiGuideTab(context, ai, detail),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildResponsiveWrapper({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: child,
      ),
    );
  }

  Widget _buildToursTab(BuildContext context, AiController ai,
      PersonalizedRecommendationModel? detail) {
    final hasNearby = detail?.nearbyScheduleTours.isNotEmpty == true;

    final exactTours = ai.recommendations;
    final nearbyTours = detail?.nearbyScheduleTours ?? const [];

    final showExactSection = exactTours.isNotEmpty;
    final showNearbySection = nearbyTours.isNotEmpty;

    // Align active filter logic with web
    String activeFilter = _tourFilter;
    if (!showExactSection && showNearbySection) {
      activeFilter = 'nearby';
    } else if (showExactSection && _tourFilter == 'nearby' && !showNearbySection) {
      activeFilter = 'exact';
    }

    final showExact = activeFilter == 'all' || activeFilter == 'exact';
    final showNearby =
        (activeFilter == 'all' || activeFilter == 'nearby') && hasNearby;

    return _buildResponsiveWrapper(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Filter chips matching web visibility rules
          if ((showExactSection && showNearbySection) || showExactSection || showNearbySection)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (showExactSection && showNearbySection) ...[
                      ChoiceChip(
                        label: Text('ai_filter_all'.trParams({'count': '${exactTours.length + nearbyTours.length}'})),
                        selected: activeFilter == 'all',
                        onSelected: (val) {
                          if (val) setState(() => _tourFilter = 'all');
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (showExactSection) ...[
                      ChoiceChip(
                        label: Text('ai_filter_exact'.trParams({'count': '${exactTours.length}'})),
                        selected: activeFilter == 'exact',
                        onSelected: (val) {
                          if (val) setState(() => _tourFilter = 'exact');
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (showNearbySection) ...[
                      ChoiceChip(
                        label: Text('ai_filter_nearby'.trParams({'count': '${nearbyTours.length}'})),
                        selected: activeFilter == 'nearby',
                        onSelected: (val) {
                          if (val) setState(() => _tourFilter = 'nearby');
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

          if (showExact) ...[
            if (activeFilter == 'all' && hasNearby)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: Text(
                  'ai_exact_tours'.tr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            if (exactTours.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'ai_no_exact_tours'.tr,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              _buildTourList(context, exactTours),
          ],

          if (showNearby) ...[
            const SizedBox(height: 16),
            if (activeFilter == 'all')
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'ai_nearby_tours'.tr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            if (nearbyTours.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'ai_no_nearby_tours'.tr,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              _buildTourList(context, nearbyTours, nearby: true),
          ],
        ],
      ),
    );
  }

  Widget _buildTourList(BuildContext context, List<TourRecommendationModel> tours, {bool nearby = false}) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 600;

    if (isWide) {
      final colCount = width > 900 ? 3 : 2;
      final colWidth = width / colCount;
      final childRatio = colWidth / 140; // Maintain fixed card height

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childRatio,
        ),
        itemCount: tours.length,
        itemBuilder: (context, index) {
          final rec = tours[index];
          return _RecommendationCard(
            rec: rec,
            nearby: nearby,
            onShowDetails: () => _showAiMatchDetailsSheet(context, rec),
          );
        },
      );
    } else {
      return Column(
        children: tours.map((rec) => _RecommendationCard(
          rec: rec,
          nearby: nearby,
          onShowDetails: () => _showAiMatchDetailsSheet(context, rec),
        )).toList(),
      );
    }
  }

  Widget _buildAiOverviewBanner(BuildContext context, String summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.homeHeroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF05073C).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -24,
            child: Icon(
              Icons.auto_awesome,
              size: 110,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ai_guide_title'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripProfileChips(
      BuildContext context, TourPreferenceQuestionnaireModel profile) {
    final destination = [profile.preferredCity, profile.preferredCountry]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');
    final dates = [
      if (profile.preferredStartDate.isNotEmpty)
        _formatDateStr(profile.preferredStartDate),
      if (profile.preferredEndDate != null &&
          profile.preferredEndDate!.isNotEmpty)
        _formatDateStr(profile.preferredEndDate),
    ].join(' - ');    final companion = profile.companionType;
    final companionLabel = 'ai_companion_$companion'.tr;

    final companionDetails = [
      if (profile.hasElderly) 'ai_elderly'.tr,
      if (profile.hasChildren) 'ai_children'.tr,
    ].join(', ');

    final budget =
        profile.maxBudgetPerPerson != null && profile.maxBudgetPerPerson! > 0
            ? CurrencyFormatter.format(profile.maxBudgetPerPerson!)
            : 'ai_unlimited'.tr;

    final chips = <({IconData icon, String label})>[
      if (destination.isNotEmpty)
        (icon: Icons.place_outlined, label: destination),
      if (dates.isNotEmpty) (icon: Icons.date_range_outlined, label: dates),
      (
        icon: Icons.people_outline_rounded,
        label: companionLabel +
            (companionDetails.isNotEmpty ? ' ($companionDetails)' : '')
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        label: 'ai_budget_prefix'.trParams({'budget': budget})
      ),
      ...profile.travelInterests.map((interest) {
        final key = 'ai_interest_${interest.toLowerCase().trim()}';
        final trans = key.tr;
        final localizedLabel = trans == key ? interest : trans;
        return (icon: Icons.interests_outlined, label: localizedLabel);
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.badge_outlined, size: 14, color: AppColors.brand),
            const SizedBox(width: 6),
            Text(
              'ai_trip_profile'.tr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 20),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = chips[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 14, color: AppColors.brand),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAiTransparencySheet(
      BuildContext context, RecommenderMetaModel meta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: 650,
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.brandLight,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.brand,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ai_evaluation_mechanism'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: _RecommenderTransparencyContent(meta: meta),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundSecondary,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.button,
                      ),
                    ),
                    child: Text(
                      'ai_close'.tr,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiGuideTab(BuildContext context, AiController ai,
      PersonalizedRecommendationModel? detail) {
    if (detail == null) {
      return Center(child: Text('ai_no_guide_data'.tr));
    }

    return _buildResponsiveWrapper(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (detail.summary.isNotEmpty)
            _buildAiOverviewBanner(context, detail.summary),
          if (detail.appliedProfile != null)
            _buildTripProfileChips(context, detail.appliedProfile!),
          const SizedBox(height: 4),
          _TipsTabsContent(detail: detail),
          const SizedBox(height: 24),
          _DestinationTipsContent(detail: detail),
          const SizedBox(height: 24),
          if (detail.relatedInsights.isNotEmpty) ...[
            _RelatedInsightsContent(insights: detail.relatedInsights),
            const SizedBox(height: 24),
          ],
          if (detail.recommenderMeta != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    _showAiTransparencySheet(context, detail.recommenderMeta!),
                icon: const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.brand),
                label: Text(
                  'ai_how_it_works'.tr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAiMatchDetailsSheet(
      BuildContext context, TourRecommendationModel rec) {
    final hasBreakdown = rec.scoreBreakdown != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 650,
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ai_analysis_title'.tr,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: AppColors.brand,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rec.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Floating circular match score
                      if (rec.score != null)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.homeHeroGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brand.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${(rec.score! * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Detail Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tour basic information row
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceGrouped,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                if (rec.city != null) ...[
                                  const Icon(Icons.location_on_outlined,
                                      size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    rec.city!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                                if (rec.durationDays != null) ...[
                                  const Icon(Icons.wb_sunny_outlined,
                                      size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ai_days'.trParams({'days': '${rec.durationDays}'}),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Match Reason Text
                          if (rec.reason != null && rec.reason!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.psychology_outlined,
                                    color: AppColors.brand, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ai_match_reason'.tr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.brandLight.withOpacity(0.5),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                border: Border.all(
                                    color: AppColors.brand.withOpacity(0.1)),
                              ),
                              child: Text(
                                rec.reason!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Match Reasons Checklist Tags
                          if (rec.matchReasons != null &&
                              rec.matchReasons!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    color: AppColors.success, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ai_highlight_points'.tr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: rec.matchReasons!.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceGrouped,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.xs),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_rounded,
                                          color: AppColors.success, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        tag,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Schedule Note
                          if (rec.scheduleNote != null &&
                              rec.scheduleNote!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded,
                                    color: AppColors.accent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ai_suggested_schedule'.tr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.accentLight.withOpacity(0.5),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                border: Border.all(
                                    color: AppColors.accent.withOpacity(0.1)),
                              ),
                              child: Text(
                                rec.scheduleNote!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.accentHover,
                                  height: 1.45,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Weather Advice
                          if (rec.destinationWeather != null) ...[
                            _WeatherAdviceContent(
                                weather: rec.destinationWeather!),
                          ],

                          // Score Breakdown
                          if (hasBreakdown) ...[
                            Row(
                              children: [
                                const Icon(Icons.analytics_outlined,
                                    color: AppColors.brand, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ai_criteria_scores'.tr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildScoreBreakdownInSheet(
                                context, rec.scoreBreakdown!),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.tourDetail, arguments: rec.tourId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.button,
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ai_view_details_book'.tr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreBreakdownInSheet(
      BuildContext context, ScoreBreakdownModel breakdown) {
    final explanations = breakdown.dimensionExplanations.isNotEmpty
        ? breakdown.dimensionExplanations
        : breakdown.dimensionScores.entries
            .map((entry) => ScoreDimensionExplanationModel(
                  dimensionKey: entry.key,
                  label: _formatDimensionKey(entry.key),
                  score: entry.value,
                  weight: 0.0,
                  explanation: '',
                ))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (breakdown.overallExplanation != null &&
            breakdown.overallExplanation!.isNotEmpty) ...[
          Text(
            breakdown.overallExplanation!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...explanations.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(item.score * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: item.score,
                    minHeight: 6,
                    backgroundColor: AppColors.backgroundSecondary,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.brand),
                  ),
                ),
                if (item.explanation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.explanation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard(
      {required this.rec, this.nearby = false, required this.onShowDetails});

  final TourRecommendationModel rec;
  final bool nearby;
  final VoidCallback onShowDetails;

  Widget _buildFallbackImage() {
    return Container(
      width: 100,
      height: 100,
      color: AppColors.backgroundSecondary,
      child: const Center(
        child: Icon(
          Icons.tour_rounded,
          size: 36,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IosSurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Get.toNamed(AppRoutes.tourDetail, arguments: rec.tourId),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Image with Match Badge overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: rec.imageUrl != null && rec.imageUrl!.isNotEmpty
                          ? Image.network(
                              rec.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildFallbackImage(),
                            )
                          : _buildFallbackImage(),
                    ),
                  ),
                  // Small Match Score Badge in top left
                  if (rec.score != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(rec.score! * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Nearby badge on image
                  if (nearby)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Center(
                          child: Text(
                            'ai_filter_nearby'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Right: Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tour Title
                    Text(
                      rec.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Rating & Location
                    Row(
                      children: [
                        if (rec.averageStar != null &&
                            rec.averageStar! > 0) ...[
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            rec.averageStar!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.textSecondary, size: 12),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            [rec.city, rec.country]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Compact Weather Indicator
                    if (rec.destinationWeather != null) ...[
                      Row(
                        children: [
                          const Text('⛅ ', style: TextStyle(fontSize: 10)),
                          Text(
                            '${rec.destinationWeather!.avgMaxTempC?.round() ?? '--'}°C',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.lightBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if ((rec.destinationWeather!.totalRainMm ?? 0) > 20)
                            const Text(' ☔', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Price & Duration Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Duration
                              if (rec.durationDays != null)
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded,
                                        color: AppColors.brand, size: 11),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ai_days'.trParams({'days': '${rec.durationDays}'}),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 2),
                              // Price
                              if (rec.minPrice != null && rec.minPrice! > 0)
                                Text(
                                  'ai_price_from'.trParams({'price': CurrencyFormatter.format(rec.minPrice!)}),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // "Why match" button
                        GestureDetector(
                          onTap: onShowDetails,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: AppColors.brandLight,
                                borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    color: AppColors.brand, size: 10),
                                const SizedBox(width: 4),
                                Text(
                                  'ai_why_fit'.tr,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ],
                            ),
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
}

class _WeatherAdviceContent extends StatelessWidget {
  const _WeatherAdviceContent({required this.weather});

  final WeatherAdviceModel weather;

  String _detectWeatherCondition(WeatherAdviceModel weather) {
    final rain = weather.totalRainMm ?? 0;
    final max = weather.avgMaxTempC ?? 28;
    final min = weather.avgMinTempC ?? 22;

    if (rain >= 30) return 'rainy';
    if (max >= 32) return 'hot';
    if (max <= 22 && min <= 18) return 'cool';
    return 'mild';
  }

  String _getWeatherConditionLabel(String condition) {
    switch (condition) {
      case 'rainy':
        return 'ai_weather_rainy'.tr;
      case 'hot':
        return 'ai_weather_hot'.tr;
      case 'cool':
        return 'ai_weather_cool'.tr;
      case 'mild':
      default:
        return 'ai_weather_mild'.tr;
    }
  }

  Color _getConditionBgColor(String condition) {
    switch (condition) {
      case 'rainy':
        return Colors.blue.shade50;
      case 'hot':
        return Colors.orange.shade50;
      case 'cool':
        return Colors.indigo.shade50;
      case 'mild':
      default:
        return AppColors.success.withValues(alpha: 0.1);
    }
  }

  Color _getConditionTextColor(String condition) {
    switch (condition) {
      case 'rainy':
        return Colors.blue.shade700;
      case 'hot':
        return Colors.orange.shade700;
      case 'cool':
        return Colors.indigo.shade700;
      case 'mild':
      default:
        return AppColors.success;
    }
  }

  String _formatDataSource(String source) {
    final s = source.toLowerCase();
    if (s.contains('forecast')) {
      return 'ai_weather_forecast'.tr;
    }
    if (s.contains('historical')) {
      return 'ai_weather_historical'.tr;
    }
    return source;
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'ai_unknown'.tr;
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final condition = _detectWeatherCondition(weather);
    final conditionLabel = _getWeatherConditionLabel(condition);
    final bgColor = _getConditionBgColor(condition);
    final textColor = _getConditionTextColor(condition);

    IconData weatherIcon = Icons.wb_sunny_rounded;
    if (condition == 'rainy') {
      weatherIcon = Icons.thunderstorm_rounded;
    } else if (condition == 'cool') {
      weatherIcon = Icons.cloudy_snowing;
    } else if (condition == 'hot') {
      weatherIcon = Icons.wb_sunny_rounded;
    } else {
      weatherIcon = Icons.filter_drama_rounded;
    }

    return IosSurfaceCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: const Icon(Icons.cloud_outlined,
                        color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ai_destination_weather'.tr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(weatherIcon, size: 12, color: textColor),
                    const SizedBox(width: 4),
                    Text(
                      conditionLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather.city,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    if (weather.periodStart != null &&
                        weather.periodEnd != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDateTime(weather.periodStart)} - ${_formatDateTime(weather.periodEnd)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (weather.avgMaxTempC != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${weather.avgMaxTempC!.round()}°C',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      'ai_min_temp_prefix'.trParams({'temp': '${weather.avgMinTempC?.round() ?? 0}'}),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (weather.totalRainMm != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop_outlined,
                          size: 12, color: AppColors.brand),
                      const SizedBox(width: 4),
                      Text(
                        'ai_rain_prefix'.trParams({'rain': weather.totalRainMm!.toStringAsFixed(1)}),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                _formatDataSource(weather.dataSource),
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (weather.summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              weather.summary,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary, height: 1.4),
            ),
          ],
          if (weather.impactOnTours.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.accent.withOpacity(0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      weather.impactOnTours,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentHover,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TipsTabsContent extends StatelessWidget {
  const _TipsTabsContent({required this.detail});

  final PersonalizedRecommendationModel detail;

  @override
  Widget build(BuildContext context) {
    final categories = <({
      String label,
      IconData icon,
      List<String> tips,
      Color color,
      Color bgColor
    })>[
      if (detail.generalTips.isNotEmpty)
        (
          label: 'ai_tip_general_label'.tr,
          icon: Icons.lightbulb_rounded,
          tips: detail.generalTips,
          color: AppColors.brand,
          bgColor: AppColors.brandLight
        ),
      if (detail.foreignVisitorTips.isNotEmpty)
        (
          label: 'ai_tip_foreigner_label'.tr,
          icon: Icons.translate_rounded,
          tips: detail.foreignVisitorTips,
          color: AppColors.accent,
          bgColor: AppColors.accentLight
        ),
      if (detail.elderlyCompanionTips.isNotEmpty)
        (
          label: 'ai_tip_elderly_label'.tr,
          icon: Icons.elderly_rounded,
          tips: detail.elderlyCompanionTips,
          color: Colors.teal,
          bgColor: Colors.teal.shade50
        ),
      if (detail.childrenCompanionTips.isNotEmpty)
        (
          label: 'ai_tip_children_label'.tr,
          icon: Icons.child_care_rounded,
          tips: detail.childrenCompanionTips,
          color: Colors.purple,
          bgColor: Colors.purple.shade50
        ),
    ];

    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: const Icon(Icons.tips_and_updates_outlined,
                  color: AppColors.brand, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'ai_tips_group_title'.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              final screenWidth = MediaQuery.of(context).size.width;
              final cardWidth = screenWidth > 600 ? 340.0 : screenWidth * 0.78;

              return Container(
                width: cardWidth,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textSecondary.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: cat.bgColor,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: cat.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: cat.tips.map((tip) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded,
                                      color: cat.color, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DestinationTipsContent extends StatelessWidget {
  const _DestinationTipsContent({required this.detail});

  final PersonalizedRecommendationModel detail;

  @override
  Widget build(BuildContext context) {
    final profile = detail.appliedProfile;
    final preferredCity = profile?.preferredCity?.trim();

    final List<String> tourCities = [];
    if (preferredCity != null && preferredCity.isNotEmpty) {
      tourCities.add(preferredCity);
    } else {
      final exactCities = detail.recommendedTours
          .map((tour) => tour.city?.trim())
          .whereType<String>()
          .where((city) => city.isNotEmpty);
      final nearbyCities = detail.nearbyScheduleTours
          .map((tour) => tour.city?.trim())
          .whereType<String>()
          .where((city) => city.isNotEmpty);
      tourCities.addAll({...exactCities, ...nearbyCities});
    }

    final facts = detail.culturalFacts.where((fact) {
      final factCity = fact.city?.trim();
      if (tourCities.isEmpty) return true;
      if (factCity == null || factCity.isEmpty) return false;
      return tourCities.any((c) => _citiesMatch(factCity, c));
    }).toList();

    if (facts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: const Icon(Icons.place_outlined,
                  color: AppColors.brand, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'ai_local_culture_guide'.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: facts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final fact = facts[idx];
              final formatted = _formatDestinationFact(fact.fact);
              final hasHeadline =
                  formatted.headline != null && formatted.headline!.isNotEmpty;
              final screenWidth = MediaQuery.of(context).size.width;
              final cardWidth = screenWidth > 600 ? 320.0 : screenWidth * 0.75;

              return Container(
                width: cardWidth,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrouped,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (fact.city != null && fact.city!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 10, color: AppColors.brand),
                                const SizedBox(width: 2),
                                Text(
                                  fact.city!,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Icon(Icons.explore_outlined,
                            size: 14, color: AppColors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hasHeadline) ...[
                      Text(
                        formatted.headline!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          formatted.body,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RelatedInsightsContent extends StatelessWidget {
  const _RelatedInsightsContent({required this.insights});

  final List<TourismInsightModel> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: const Icon(Icons.insights_outlined,
                  color: AppColors.brand, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'ai_related_insights'.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: insights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final insight = insights[idx];
              final meta = [
                insight.city,
                insight.authorityLevel,
                insight.sourceName,
              ].whereType<String>().where((e) => e.isNotEmpty).join(' • ');

              return Container(
                width: MediaQuery.of(context).size.width * 0.7,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (insight.description != null &&
                        insight.description!.isNotEmpty)
                      Expanded(
                        child: Text(
                          insight.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommenderTransparencyContent extends StatelessWidget {
  const _RecommenderTransparencyContent({required this.meta});

  final RecommenderMetaModel meta;

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weights = meta.dimensionWeights.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Technical summary
        _buildMetaRow(Icons.memory_rounded, 'ai_algorithm_label'.tr, meta.modelFamily),
        _buildMetaRow(Icons.verified_outlined, 'ai_version_label'.tr, meta.modelVersion),
        _buildMetaRow(Icons.groups_rounded, 'ai_fairness_label'.tr,
            meta.fairnessAlpha.toStringAsFixed(2)),

        if (meta.aggregationFormula.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrouped,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              meta.aggregationFormula,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],

        if (weights.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'ai_weights_label'.tr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...weights.map((entry) {
            final label = _formatDimensionKey(entry.key);
            final pct = (entry.value * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: entry.value,
                      minHeight: 5,
                      backgroundColor: AppColors.backgroundSecondary,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.brand),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _FormattedDestinationFact {
  final String? headline;
  final String body;

  _FormattedDestinationFact({this.headline, required this.body});
}

_FormattedDestinationFact _formatDestinationFact(String fact) {
  final trimmed = fact.trim();
  final colonIdx = trimmed.indexOf(':');

  if (colonIdx > 0 && colonIdx < 72) {
    final headline = trimmed.substring(0, colonIdx).trim();
    final body = trimmed.substring(colonIdx + 1).trim();
    if (body.isNotEmpty) {
      return _FormattedDestinationFact(headline: headline, body: body);
    }
  }

  return _FormattedDestinationFact(body: trimmed);
}

String _normalizeCityKey(String value) {
  final withoutDiacritics = value
      .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'), 'A')
      .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'), 'E')
      .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp(r'[ÌÍỊỈĨ]'), 'I')
      .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'), 'O')
      .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'), 'U')
      .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
      .replaceAll(RegExp(r'[ỲÝỴỶỸ]'), 'Y')
      .replaceAll(RegExp(r'[đ]'), 'd')
      .replaceAll(RegExp(r'[Đ]'), 'D');
  return withoutDiacritics.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

bool _citiesMatch(String a, String b) {
  return _normalizeCityKey(a) == _normalizeCityKey(b);
}

String _labelize(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _formatDateStr(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'ai_unknown'.tr;
  try {
    final parsed = DateTime.parse(dateStr);
    return DateFormat('dd/MM/yyyy').format(parsed);
  } catch (_) {
    return dateStr;
  }
}

String _formatDimensionKey(String key) {
  final normalized = key.toLowerCase();
  switch (normalized) {
    case 'interest_semantic':
      return 'ai_dim_interest'.tr;
    case 'location':
      return 'ai_dim_location'.tr;
    case 'budget':
      return 'ai_dim_budget'.tr;
    case 'schedule':
      return 'ai_dim_schedule'.tr;
    case 'weather':
      return 'ai_dim_weather'.tr;
    case 'accessibility':
      return 'ai_dim_accessibility'.tr;
    case 'cultural_fit':
      return 'ai_dim_cultural_fit'.tr;
    default:
      return _labelize(key);
  }
}
