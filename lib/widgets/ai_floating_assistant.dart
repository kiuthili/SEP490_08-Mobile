import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/feature_controllers.dart';
import '../models/ai_models.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'ios_grouped.dart';
import '../screens/customer/ai_questionnaire_screen.dart';
import '../screens/customer/ai_recommendations_screen.dart';

class AiFloatingAssistant extends StatelessWidget {
  const AiFloatingAssistant({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'ai-floating-assistant',
      onPressed: () => showAiAssistantPanel(context),
      icon: const Icon(Icons.auto_awesome_rounded),
      label: const Text('AI Guide'),
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }
}

enum AiPanelTab { guide, assistant }

Future<void> showAiAssistantPanel([
  BuildContext? context,
  AiPanelTab initialTab = AiPanelTab.guide,
]) {
  final navContext = _navigatorContext(context);
  if (navContext == null) return Future.value();

  return showModalBottomSheet<void>(
    context: navContext,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiAssistantSheet(initialTab: initialTab),
  );
}

BuildContext? _navigatorContext(BuildContext? context) {
  if (context != null && Navigator.maybeOf(context) != null) {
    return context;
  }

  final getContext = Get.context;
  if (getContext != null && Navigator.maybeOf(getContext) != null) {
    return getContext;
  }

  final overlayContext = Get.overlayContext;
  if (overlayContext != null && Navigator.maybeOf(overlayContext) != null) {
    return overlayContext;
  }

  return null;
}

class _AiAssistantSheet extends StatefulWidget {
  const _AiAssistantSheet({required this.initialTab});

  final AiPanelTab initialTab;

  @override
  State<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<_AiAssistantSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == AiPanelTab.guide ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.86;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.separator,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'StayHub AI',
                        style: AppTextStyles.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AI Guide va AI Assistant',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceGrouped,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                indicator: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(10),
                ),
                tabs: const [
                  Tab(icon: Icon(Icons.travel_explore), text: 'AI Guide'),
                  Tab(
                    icon: Icon(Icons.chat_bubble_outline),
                    text: 'AI Assistant',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _AiGuideTab(),
                _AiAssistantChatTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiGuideTab extends StatefulWidget {
  const _AiGuideTab();

  @override
  State<_AiGuideTab> createState() => _AiGuideTabState();
}

class _AiGuideTabState extends State<_AiGuideTab>
    with SingleTickerProviderStateMixin {
  late final TabController _guideController;

  @override
  void initState() {
    super.initState();
    _guideController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _guideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.psychology_outlined),
                label: Text('Khảo sát'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.auto_awesome_outlined),
                label: Text('Gợi ý'),
              ),
            ],
            selected: {_guideController.index},
            onSelectionChanged: (value) {
              setState(() => _guideController.index = value.first);
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _guideController,
            children: [
              AiQuestionnaireTab(
                onCompleted: () {
                  setState(() => _guideController.index = 1);
                },
              ),
              AiRecommendationsTab(
                onRetake: () {
                  setState(() => _guideController.index = 0);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiAssistantChatTab extends StatefulWidget {
  const _AiAssistantChatTab();

  @override
  State<_AiAssistantChatTab> createState() => _AiAssistantChatTabState();
}

class _AiAssistantChatTabState extends State<_AiAssistantChatTab> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final AiController _ai;
  Worker? _messagesWorker;

  static const _suggestions = [
    'Trợ lý AI làm được gì?',
    'Cách đặt tour trên StayHub?',
    'Voucher dùng như thế nào?',
    'Gợi ý tour Đà Nẵng cho gia đình',
  ];

  @override
  void initState() {
    super.initState();
    _ai = Get.find<AiController>();
    _messagesWorker = ever(_ai.chatMessages, (_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messagesWorker?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? text]) async {
    final message = (text ?? _input.text).trim();
    if (message.isEmpty) return;
    _input.clear();
    await _ai.sendChatMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Obx(() {
            final messages = _ai.chatMessages;
            if (messages.isEmpty) {
              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.brand,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hỏi StayHub AI',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mình có thể hỗ trợ đặt tour, voucher, thanh toán, gợi ý điểm đến và câu hỏi về nền tảng.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _suggestions
                        .map(
                          (q) => ActionChip(
                            label: Text(q),
                            onPressed: () => _send(q),
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
            }

            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              itemCount: messages.length + (_ai.isSendingChat.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= messages.length) {
                  return const _TypingBubble();
                }
                return _ChatBubble(message: messages[index], onAsk: _send);
              },
            );
          }),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Nhập câu hỏi...',
                    prefixIcon: Icon(Icons.auto_awesome_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(
                () => IconButton.filled(
                  onPressed: _ai.isSendingChat.value ? null : () => _send(),
                  icon: _ai.isSendingChat.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.onAsk});

  final AiChatMessageModel message;
  final Future<void> Function(String text) onAsk;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final response = message.response;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.76,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.brand : AppColors.surfaceGrouped,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ),
          if (!isUser && response != null) ...[
            if (response.recommendedTours.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: response.recommendedTours.take(3).map((t) {
                    return IosSurfaceCard(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        dense: true,
                        title: Text(t.name),
                        subtitle: Text(t.reason ?? t.city ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop();
                          Get.toNamed(AppRoutes.tourDetail,
                              arguments: t.tourId);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (response.suggestedQuestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: response.suggestedQuestions.take(3).map((q) {
                    return ActionChip(
                      label: Text(q),
                      onPressed: () => onAsk(q),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrouped,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
