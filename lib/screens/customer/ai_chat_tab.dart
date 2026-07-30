import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/ai_models.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ios_grouped.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class AiChatTab extends StatefulWidget {
  const AiChatTab({super.key, this.onSwitchToGuide});

  final VoidCallback? onSwitchToGuide;

  @override
  State<AiChatTab> createState() => _AiChatTabState();
}

class _AiChatTabState extends State<AiChatTab> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final AiController _ai;
  Worker? _messagesWorker;

  final _suggestions = [
    'ai_sug_1'.tr,
    'ai_sug_2'.tr,
    'ai_sug_3'.tr,
    'ai_sug_4'.tr,
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
        Obx(() {
          final messages = _ai.chatMessages;
          if (messages.isNotEmpty && widget.onSwitchToGuide != null) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0x0F0052CC),
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.brand,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ai_chat_prompt'.tr,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onSwitchToGuide,
                    child: Text(
                      'ai_open_form'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),
        Expanded(
          child: Obx(() {
            final messages = _ai.chatMessages;
            if (messages.isEmpty) {
              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.brand,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ai_ask_stayhub'.tr,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ai_chat_subtitle'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (widget.onSwitchToGuide != null) ...[
                    const SizedBox(height: 20),
                      Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.brand.withValues(alpha: 0.06),
                            Colors.indigo.withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.brandLight,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xs),
                                ),
                                child: const Icon(
                                  Icons.bolt,
                                  color: AppColors.brand,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ai_quick_recommendations'.tr,
                                style: AppTextStyles.textTheme.titleSmall
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ai_quick_recommendations_desc'.tr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: widget.onSwitchToGuide,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                'ai_switch_to_form'.tr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _suggestions
                        .map(
                          (q) => ActionChip(
                            label: Text(q, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.brand)),
                            shape: const StadiumBorder(side: BorderSide.none),
                            backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  decoration: InputDecoration(
                    hintText: 'ai_input_hint'.tr,
                    prefixIcon: const Icon(Icons.auto_awesome_outlined, size: 20),
                    suffixIcon: Obx(
                      () => Padding(
                        padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                        child: IconButton.filled(
                          onPressed: _ai.isSendingChat.value ? null : () => _send(),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ),
                          icon: _ai.isSendingChat.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 16),
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                    ),
                  ),
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
              child: isUser
                  ? Text(
                      message.text,
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.35,
                      ),
                    )
                  : MarkdownBody(
                      data: message.text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                        strong: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          t.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        subtitle: Text(
                          t.reason ?? t.city ?? '',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                        onTap: () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
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
                      label: Text(q, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.brand)),
                      shape: const StadiumBorder(side: BorderSide.none),
                      backgroundColor: AppColors.brand.withValues(alpha: 0.1),
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
