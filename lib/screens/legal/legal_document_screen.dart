import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../legal/legal_section.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/ios_grouped.dart';
import '../../services/system_setting_service.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    this.title,
    this.lastUpdated,
    this.sections,
    this.settingKey,
    this.relatedRoute,
    this.relatedLabel,
    this.relatedDocuments,
  });

  final String? title;
  final String? lastUpdated;
  final List<LegalSection>? sections;
  final String? settingKey;
  final String? relatedRoute;
  final String? relatedLabel;
  final List<Map<String, String>>? relatedDocuments;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  bool _isLoading = false;
  String? _htmlContent;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final key = widget.settingKey ?? Get.arguments?['settingKey'] as String?;
    if (key == null || key.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      if (!Get.isRegistered<SystemSettingService>()) {
        Get.put(SystemSettingService());
      }
      final service = Get.find<SystemSettingService>();

      final localeCode = Get.locale?.languageCode ?? 'vi';
      final fetchKey = localeCode == 'vi' ? key : '${key}_en';

      var content = await service.getSetting(fetchKey);
      if (content == null || content.isEmpty) {
        content = await service.getSetting(key);
      }

      if (mounted) {
        setState(() {
          _htmlContent = content?.replaceAll('&nbsp;', ' ');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final resolvedTitle = widget.title ?? args['title'] as String? ?? 'Văn bản pháp lý';
    final resolvedUpdated = widget.lastUpdated ?? args['lastUpdated'] as String? ?? '';
    final resolvedSections = widget.sections ?? (args['sections'] as List<LegalSection>?) ?? [];
    final resolvedRelatedRoute = widget.relatedRoute ?? args['relatedRoute'] as String?;
    final resolvedRelatedLabel = widget.relatedLabel ?? args['relatedLabel'] as String?;
    final resolvedRelatedDocs = widget.relatedDocuments ??
        (args['relatedDocuments'] as List<Map<String, String>>?) ??
        [
          if (resolvedRelatedRoute != null && resolvedRelatedLabel != null)
            {'route': resolvedRelatedRoute, 'label': resolvedRelatedLabel},
        ];

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
          if (resolvedRelatedDocs.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...resolvedRelatedDocs.map(
              (doc) => Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextButton.icon(
                    onPressed: () => Get.toNamed(doc['route'] ?? ''),
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.brand,
                    ),
                    label: Text(
                      doc['label'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_htmlContent != null && _htmlContent!.isNotEmpty)
            IosSurfaceCard(
              margin: EdgeInsets.zero,
              child: HtmlWidget(
                _htmlContent!,
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
              ),
            )
          else
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
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
