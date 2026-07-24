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
                  const Expanded(
                    child: Text(
                      'Bạn có thể chuyển sang điền Form bất cứ lúc nào để có đề xuất ngay.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onSwitchToGuide,
                    child: const Text(
                      'Mở Form →',
                      style: TextStyle(
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
                  if (widget.onSwitchToGuide != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.brand.withOpacity(0.06),
                            Colors.indigo.withOpacity(0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.brand.withOpacity(0.25),
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
                                'Nhận đề xuất nhanh',
                                style: AppTextStyles.textTheme.titleSmall
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Điền Form khảo sát ngắn (100% miễn phí, không tốn tài nguyên chat, trả kết quả tức thì).',
                            style: TextStyle(
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
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text(
                                'Chuyển sang điền Form khảo sát',
                                style: TextStyle(
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
                  decoration: InputDecoration(
                    hintText: 'Nhập câu hỏi...',
                    prefixIcon: const Icon(Icons.auto_awesome_outlined),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide:
                          const BorderSide(color: AppColors.brand, width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(
                () => IconButton.filled(
                  onPressed: _ai.isSendingChat.value ? null : () => _send(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                  ),
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
                borderRadius: BorderRadius.circular(AppRadius.md),
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
                    return IosSurfaceCard(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        dense: true,
                        title: Text(t.name),
                        subtitle: Text(t.reason ?? t.city ?? ''),
                        trailing: const Icon(Icons.chevron_right),
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
          borderRadius: BorderRadius.circular(AppRadius.md),
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
