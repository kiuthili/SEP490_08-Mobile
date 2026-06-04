import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../legal/legal_section.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/ios_grouped.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    this.title,
    this.lastUpdated,
    this.sections,
    this.relatedRoute,
    this.relatedLabel,
  });

  final String? title;
  final String? lastUpdated;
  final List<LegalSection>? sections;
  final String? relatedRoute;
  final String? relatedLabel;

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final resolvedTitle =
        title ?? args['title'] as String? ?? 'Văn bản pháp lý';
    final resolvedUpdated =
        lastUpdated ?? args['lastUpdated'] as String? ?? '';
    final resolvedSections =
        sections ?? (args['sections'] as List<LegalSection>?) ?? [];
    final resolvedRelatedRoute =
        relatedRoute ?? args['relatedRoute'] as String?;
    final resolvedRelatedLabel =
        relatedLabel ?? args['relatedLabel'] as String?;

    return AppScreen(
      title: resolvedTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (resolvedUpdated.isNotEmpty)
            Text(
              'Cập nhật: $resolvedUpdated',
              style: AppTextStyles.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          if (resolvedRelatedRoute != null &&
              resolvedRelatedLabel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Get.toNamed(resolvedRelatedRoute!),
                child: Text(resolvedRelatedLabel!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...resolvedSections.map(_SectionCard.new),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(this.section);

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IosSurfaceCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: AppTextStyles.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...section.paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  p,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                      ),
                ),
              ),
            ),
            if (section.bullets.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...section.bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          b,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
