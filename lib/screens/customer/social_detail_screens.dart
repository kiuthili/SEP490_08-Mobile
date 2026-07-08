import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../models/social_models.dart'; // Đã thêm
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../services/signalr_service.dart';
import '../../services/social_service.dart';
import '../../services/storage_service.dart';
import '../../services/tour_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/moment_card.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _socialService = Get.find<SocialService>();
  final _socialController = Get.find<SocialController>();
  final _signalR = Get.find<SignalRService>();
  final _tourService = Get.find<TourService>();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();

  final _messages = <ChatMessageModel>[];
  var _loading = true;
  var _sending = false;
  String? _error;
  var _loadingOlder = false;
  var _canLoadOlder = true;
  var _historySkip = 0;
  static const _pageSize = 40;
  int? _roomId;
  String _roomTitle = 'Tin nhắn';
  bool _isGroup = false;
  String? _avatarUrl;
  int? _scheduleId;
  TourScheduleModel? _schedule;
  bool _loadingSchedule = false;
  String? _scheduleError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initRoom();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > 80 ||
        _loadingOlder ||
        !_canLoadOlder ||
        _roomId == null) {
      return;
    }
    _loadOlderMessages();
  }

  Future<void> _loadOlderMessages() async {
    setState(() => _loadingOlder = true);
    _historySkip += _pageSize;
    try {
      final older = await _socialService.getChatMessages(
        _roomId!,
        skip: _historySkip,
        top: _pageSize,
      );
      if (older.isEmpty) {
        _canLoadOlder = false;
        _historySkip -= _pageSize;
      } else {
        final currentOffset = _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels;
        setState(() => _messages.insertAll(0, older));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              (_scrollController.position.maxScrollExtent - currentOffset)
                  .clamp(0, _scrollController.position.maxScrollExtent),
            );
          }
        });
      }
    } catch (e) {
      _historySkip -= _pageSize;
      SnackbarHelper.error(e.toString());
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _initRoom() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final arg = Get.arguments;
    try {
      if (arg is Map) {
        _roomId = arg['roomId'] as int?;
        _roomTitle = arg['title'] as String? ?? _roomTitle;
        _isGroup = arg['isGroup'] as bool? ?? false;
        _avatarUrl = arg['avatarUrl'] as String?;
        _scheduleId = arg['scheduleId'] as int?;
        if (_isGroup && _scheduleId != null) {
          unawaited(_loadSchedule());
        }
      } else if (arg is int) {
        final room = await _socialService.createDirectChat(arg);
        _roomId = room.id;
        await _socialController.fetchChatRooms();
        final enriched = _socialController.chatRooms
            .firstWhereOrNull((r) => r.id == room.id);
        _roomTitle = enriched?.name ?? room.name ?? 'Tin nhắn riêng';
        _avatarUrl = enriched?.avatarUrl ?? room.avatarUrl;
      }

      if (_roomId != null) {
        _historySkip = 0;
        _canLoadOlder = true;
        final history = await _socialService.getChatMessages(
          _roomId!,
          top: _pageSize,
        );
        setState(() {
          _messages.clear();
          _messages.addAll(history);
          if (history.length < _pageSize) _canLoadOlder = false;
        });
        await _signalR.joinChatRoom(_roomId!);
        _signalR.onReceiveMessage((msg) {
          if (!mounted ||
              msg.chatRoomId != _roomId ||
              msg.content.trim().isEmpty) {
            return;
          }
          if (_messages.any((message) => message.id == msg.id)) return;
          setState(() => _messages.add(msg));
          _socialController.fetchChatRooms();
          _scrollToBottom();
        });
        _scrollToBottom(jump: true);
      } else {
        _error = 'Không xác định được cuộc trò chuyện';
      }
    } catch (e) {
      _error = e.toString();
      SnackbarHelper.error(_error!);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSchedule() async {
    final scheduleId = _scheduleId;
    if (scheduleId == null) return;

    if (mounted) {
      setState(() {
        _loadingSchedule = true;
        _scheduleError = null;
      });
    }

    try {
      final schedule = await _tourService.getScheduleById(scheduleId);
      if (!mounted || _scheduleId != scheduleId) return;
      setState(() {
        _schedule = schedule;
        final tourName = schedule.tour?.name.trim();
        if (tourName != null && tourName.isNotEmpty) {
          _roomTitle = tourName;
        }
        _avatarUrl ??= schedule.tour?.imageUrl;
      });
    } catch (e) {
      if (!mounted || _scheduleId != scheduleId) return;
      setState(() => _scheduleError = e.toString());
    } finally {
      if (mounted && _scheduleId == scheduleId) {
        setState(() => _loadingSchedule = false);
      }
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent;
        if (jump) {
          _scrollController.jumpTo(target);
        } else {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _signalR.sendChatMessage(_roomId!, text);
      _messageController.clear();
      await _socialController.fetchChatRooms();
    } catch (e) {
      _messageController.text = text;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
      SnackbarHelper.error('Không gửi được tin nhắn. ${e.toString()}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    if (_roomId != null) _signalR.leaveChatRoom(_roomId!);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = Get.find<StorageService>().user?.id;

    return AppScreen(
      title: _roomTitle,
      centerTitle: false,
      leading: IconButton(
        onPressed: Get.back,
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      actions: [
        if (_isGroup)
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'leave' && _roomId != null) {
                await _socialService.leaveChatRoom(_roomId!);
                await _socialController.fetchChatRooms();
                Get.back();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Rời nhóm'),
                  ],
                ),
              ),
            ],
          )
        else
          const SizedBox(width: 8),
      ],
      body: _loading
          ? const LoadingWidget(message: 'Đang kết nối cuộc trò chuyện...')
          : _error != null
          ? _ChatError(message: _error!, onRetry: _initRoom)
          : Column(
        children: [
          _ConversationInfoBar(
            title: _roomTitle,
            avatarUrl: _avatarUrl,
            isGroup: _isGroup,
            scheduleId: _scheduleId,
            schedule: _schedule,
            loadingSchedule: _loadingSchedule,
            scheduleError: _scheduleError,
            onRetrySchedule: _loadSchedule,
          ),
          if (_loadingOlder)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyConversation(isGroup: _isGroup)
                : ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding:
              const EdgeInsets.fromLTRB(14, 16, 14, 18),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final previous =
                index > 0 ? _messages[index - 1] : null;
                final showDate = previous == null ||
                    !_sameDay(previous.sentAt, m.sentAt);
                return Column(
                  children: [
                    if (showDate) _DateDivider(date: m.sentAt),
                    _MessageBubble(
                      message: m,
                      isMe: m.senderId == myId,
                      showSender: _isGroup,
                    ),
                  ],
                );
              },
            ),
          ),
          _MessageComposer(
            controller: _messageController,
            focusNode: _inputFocus,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime? first, DateTime? second) {
    if (first == null || second == null) return false;
    final a = first.toLocal();
    final b = second.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ConversationInfoBar extends StatelessWidget {
  const _ConversationInfoBar({
    required this.title,
    required this.avatarUrl,
    required this.isGroup,
    required this.scheduleId,
    required this.schedule,
    required this.loadingSchedule,
    required this.scheduleError,
    required this.onRetrySchedule,
  });

  final String title;
  final String? avatarUrl;
  final bool isGroup;
  final int? scheduleId;
  final TourScheduleModel? schedule;
  final bool loadingSchedule;
  final String? scheduleError;
  final VoidCallback onRetrySchedule;

  @override
  Widget build(BuildContext context) {
    if (isGroup && scheduleId != null) {
      return _GroupScheduleCard(
        scheduleId: scheduleId!,
        fallbackTitle: title,
        fallbackAvatarUrl: avatarUrl,
        schedule: schedule,
        loading: loadingSchedule,
        hasError: scheduleError != null,
        onRetry: onRetrySchedule,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppColors.separator)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: isGroup ? AppColors.brandGradient : null,
              color: isGroup ? null : AppColors.brandLight,
              shape: BoxShape.circle,
            ),
            child: avatarUrl?.isNotEmpty == true
                ? CachedNetworkImage(
              imageUrl: avatarUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _fallback(),
            )
                : _fallback(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGroup ? 'Nhóm trò chuyện tour' : 'Tin nhắn riêng',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isGroup && scheduleId != null
                      ? 'Lịch trình #$scheduleId • $title'
                      : 'Đang kết nối qua StayHub',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Icon(
      isGroup ? Icons.groups_2_rounded : Icons.person_rounded,
      color: isGroup ? Colors.white : AppColors.brand,
      size: 20,
    );
  }
}

class _GroupScheduleCard extends StatelessWidget {
  const _GroupScheduleCard({
    required this.scheduleId,
    required this.fallbackTitle,
    required this.fallbackAvatarUrl,
    required this.schedule,
    required this.loading,
    required this.hasError,
    required this.onRetry,
  });

  final int scheduleId;
  final String fallbackTitle;
  final String? fallbackAvatarUrl;
  final TourScheduleModel? schedule;
  final bool loading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tour = schedule?.tour;
    final title = tour?.name.trim().isNotEmpty == true ? tour!.name : fallbackTitle;
    final imageUrl = tour?.imageUrl?.trim().isNotEmpty == true ? tour!.imageUrl : fallbackAvatarUrl;
    final canOpenTour = tour != null && tour.id > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppColors.separator)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canOpenTour ? () => Get.toNamed(AppRoutes.tourDetail, arguments: tour.id) : null,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.brandLight,
                  AppColors.surfaceElevated,
                  AppColors.accentLight.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                _ScheduleCover(imageUrl: imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.groups_2_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text('NHÓM TOUR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '#$scheduleId',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      if (loading && schedule == null)
                        const _ScheduleLoading()
                      else if (hasError && schedule == null)
                        _ScheduleLoadError(onRetry: onRetry)
                      else if (schedule != null)
                          _ScheduleMetadata(schedule: schedule!)
                        else
                          Text('Không có thông tin lịch khởi hành', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                if (canOpenTour) ...[
                  const SizedBox(width: 7),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.brand),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleCover extends StatelessWidget {
  const _ScheduleCover({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 82,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: imageUrl?.isNotEmpty == true
          ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _fallback())
          : _fallback(),
    );
  }

  Widget _fallback() => const Icon(Icons.luggage_rounded, color: Colors.white, size: 30);
}

class _ScheduleMetadata extends StatelessWidget {
  const _ScheduleMetadata({required this.schedule});
  final TourScheduleModel schedule;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final location = schedule.tour?.locationLabel;
    final days = schedule.returnDate.difference(schedule.departureDate).inDays.abs() + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScheduleMetaLine(
          icon: Icons.calendar_month_rounded,
          text: '${dateFormat.format(schedule.departureDate.toLocal())} - ${dateFormat.format(schedule.returnDate.toLocal())}',
        ),
        const SizedBox(height: 4),
        _ScheduleMetaLine(
          icon: Icons.location_on_rounded,
          text: location?.trim().isNotEmpty == true ? '$location • $days ngày' : '$days ngày',
        ),
      ],
    );
  }
}

class _ScheduleMetaLine extends StatelessWidget {
  const _ScheduleMetaLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.accent),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _ScheduleLoading extends StatelessWidget {
  const _ScheduleLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Đang tải thông tin lịch...', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ScheduleLoadError extends StatelessWidget {
  const _ScheduleLoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('Chưa tải được lịch khởi hành', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.error))),
        InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(99),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text('Thử lại', style: TextStyle(color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.isGroup});
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                gradient: isGroup ? AppColors.brandGradient : null,
                color: isGroup ? null : AppColors.brandLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGroup ? Icons.groups_2_rounded : Icons.waving_hand_rounded,
                size: 34,
                color: isGroup ? Colors.white : AppColors.brand,
              ),
            ),
            const SizedBox(height: 16),
            Text(isGroup ? 'Chào cả đoàn nào!' : 'Bắt đầu cuộc trò chuyện', style: AppTextStyles.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 7),
            Text(
              isGroup ? 'Trao đổi lịch trình và kết nối với những người cùng chuyến đi.' : 'Gửi một lời chào để bắt đầu nhắn tin trên StayHub.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final label = date == null ? 'Tin nhắn' : DateFormat('dd/MM/yyyy').format(date!.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(label, style: Theme.of(context).textTheme.labelSmall)),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
  });

  final ChatMessageModel message;
  final bool isMe;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final normalizedSenderName = message.senderName?.trim().toLowerCase() ?? '';
    final isSystemMessage = message.senderId == 0 ||
        normalizedSenderName == 'unknown user' ||
        normalizedSenderName == 'unknow user';

    if (isSystemMessage) {
      return _SystemMessageNotice(message: message);
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
      decoration: BoxDecoration(
        gradient: isMe ? AppColors.brandGradient : null,
        color: isMe ? null : AppColors.surfaceElevated,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 5),
          bottomRight: Radius.circular(isMe ? 5 : 18),
        ),
        border: isMe ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe && showSender && message.senderName?.isNotEmpty == true) ...[
            Text(message.senderName!, style: const TextStyle(color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
          ],
          Text(message.content, style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 15, height: 1.35)),
          if (message.sentAt != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                DateFormat('HH:mm').format(message.sentAt!.toLocal()),
                style: TextStyle(
                  color: isMe ? Colors.white.withValues(alpha: 0.65) : AppColors.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showSender) ...[
            _MessageAvatar(message: message),
            const SizedBox(width: 7),
          ],
          bubble,
        ],
      ),
    );
  }
}

class _SystemMessageNotice extends StatelessWidget {
  const _SystemMessageNotice({required this.message});
  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceGrouped,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textTertiary),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      message.content,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                ],
              ),
              if (message.sentAt != null) ...[
                const SizedBox(height: 3),
                Text(DateFormat('HH:mm').format(message.sentAt!.toLocal()), style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.message});
  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final name = message.senderName?.trim() ?? '';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: 28,
      height: 28,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: AppColors.brandLight, shape: BoxShape.circle),
      child: message.senderAvatar?.isNotEmpty == true
          ? CachedNetworkImage(imageUrl: message.senderAvatar!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Center(child: Text(initial)))
          : Center(child: Text(initial, style: const TextStyle(color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w800))),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottom > 0 ? bottom : 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.separator)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(hintText: 'Nhập tin nhắn...', prefixIcon: Icon(Icons.chat_bubble_outline_rounded)),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: sending ? null : onSend,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: sending ? null : AppColors.brandGradient,
                  color: sending ? AppColors.brand.withValues(alpha: 0.35) : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 21),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Không kết nối được chat',
              style: AppTextStyles.textTheme.titleMedium,
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}


class MomentDetailScreen extends StatefulWidget {
  const MomentDetailScreen({super.key});

  @override
  State<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends State<MomentDetailScreen> {
  final _socialController = Get.find<SocialController>();
  final _storage = Get.find<StorageService>();
  final _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  MomentModel? _moment;
  List<SocialCommentModel> _comments = [];
  bool _loading = true;
  bool _sendingComment = false;
  String? _error;
  int? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _loadMoment();
  }

  int get _currentUserId => _socialController.currentUserId;

  MomentModel? _findInFeed(int id) {
    for (final m in _socialController.moments) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Backend KHÔNG có GET /moments/{id} và GET comments => lấy moment + comments
  /// trực tiếp từ feed (đã chứa comments inline), tránh gọi endpoint 404.
  Future<void> _loadMoment() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final arg = Get.arguments;
    MomentModel? moment = arg is MomentModel ? arg : null;
    final int? momentId =
    arg is MomentModel ? arg.id : (arg is int ? arg : null);

    if (momentId == null) {
      setState(() {
        _error = 'ID moment không hợp lệ';
        _loading = false;
      });
      return;
    }

    try {
      // Ưu tiên dữ liệu mới nhất trong feed; nếu chưa có thì nạp feed.
      moment = _findInFeed(momentId) ?? moment;
      if (moment == null || _findInFeed(momentId) == null) {
        await _socialController.loadFeed(refresh: true);
        moment = _findInFeed(momentId) ?? moment;
      }

      if (moment == null) {
        setState(() => _error = 'Moment không tồn tại hoặc đã bị xóa');
      } else {
        setState(() {
          _moment = moment;
          _comments = List<SocialCommentModel>.from(moment!.comments);
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _editComment(SocialCommentModel c) {
    setState(() {
      _editingCommentId = c.id;
      _commentController.text = c.comment;
    });
    _commentFocusNode.requestFocus();
  }

  String get _myName {
    try {
      final dynamic u = _storage.user; // truy cập động: không phụ thuộc field cụ thể
      final dynamic n = u?.fullName;
      if (n is String && n.trim().isNotEmpty) return n;
    } catch (_) {}
    return 'Bạn';
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _moment == null) return;

    setState(() => _sendingComment = true);
    try {
      if (_editingCommentId != null) {
        final editingId = _editingCommentId!;
        if (editingId > 0) {
          await _socialController.updateComment(editingId, text);
        }
        // Cập nhật ngay trên UI (không có GET comments để reload).
        setState(() {
          _comments = _comments
              .map((c) => c.id == editingId
              ? SocialCommentModel(
            id: c.id,
            momentId: c.momentId,
            userId: c.userId,
            userName: c.userName,
            avatarUrl: c.avatarUrl,
            comment: text,
            timestamp: c.timestamp,
          )
              : c)
              .toList();
          _editingCommentId = null;
        });
      } else {
        // commentMoment() tra ve bool (thanh cong/that bai). Tu dung comment tai cho
        // tu thong tin user hien tai de hien thi ngay (id am = chua dong bo server).
        final ok = await _socialController.commentMoment(_moment!.id, text);
        if (ok != null) {
          final added = SocialCommentModel(
            id: -DateTime.now().millisecondsSinceEpoch,
            momentId: _moment!.id,
            userId: _currentUserId,
            userName: _myName,
            avatarUrl: _storage.user?.avatarUrl,
            comment: text,
            timestamp: DateTime.now(),
          );
          setState(() {
            _comments = [..._comments, added];
            _moment = _moment!.copyWith(comments: _comments);
          });
        }
      }
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _deleteComment(SocialCommentModel c) async {
    // id<=0 là comment lạc quan chưa biết id server => chỉ xóa cục bộ.
    if (c.id > 0) {
      await _socialController.deleteComment(c.id);
    }
    if (mounted) {
      setState(() => _comments.removeWhere((x) => x.id == c.id));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Chi tiết Moment',
      body: _loading
          ? const LoadingWidget(message: 'Đang tải moment...')
          : _error != null || _moment == null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Moment không tồn tại hoặc đã bị xóa'),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _loadMoment,
                child: const Text('Thử lại')),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadMoment,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  MomentCard(
                    moment: _moment!,
                    currentUserId: _currentUserId,
                    onDelete: (id) async {
                      await _socialController.deleteMoment(id);
                      Get.back();
                    },
                    onLike: (isLike) async {
                      // Bỏ qua nếu trạng thái không đổi (chống đếm sai).
                      if (_moment!.isLikedByMe == isLike) return;

                      // Cập nhật lạc quan NGAY trên màn chi tiết, kể cả khi
                      // moment không nằm trong feed đã nạp (idx < 0 ở controller).
                      final newCount = (_moment!.reactionCount + (isLike ? 1 : -1))
                          .clamp(0, 1 << 30)
                          .toInt();
                      setState(() {
                        _moment = _moment!.copyWith(
                          isLikedByMe: isLike,
                          reactionCount: newCount,
                        );
                      });

                      await _socialController.reactMoment(_moment!.id, isLike);

                      // Nếu moment có trong feed, đồng bộ lại cho khớp controller.
                      final updated = _findInFeed(_moment!.id);
                      if (updated != null && mounted) {
                        setState(() => _moment = updated);
                      }
                    },
                    onReport: (id) => _showReportDialog(context, 'Moment', id, _socialController),
                    isDetail: true,
                  ),
                  const Divider(),
                  Text('Bình luận (${_comments.length})',
                      style:
                      Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Chưa có bình luận. Hãy là người đầu tiên!',
                        style: TextStyle(
                            color: AppColors.textTertiary),
                      ),
                    ),
                  ..._comments.map((c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.brandLight,
                      backgroundImage: (c.avatarUrl != null &&
                          c.avatarUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(
                          c.avatarUrl!)
                          : null,
                      child: (c.avatarUrl == null ||
                          c.avatarUrl!.isEmpty)
                          ? const Icon(Icons.person,
                          size: 20,
                          color: AppColors.brand)
                          : null,
                    ),
                    title: Text(c.userName ?? 'Người dùng',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    subtitle: Text(c.comment),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) async {
                        if (val == 'edit') {
                          _editComment(c);
                        } else if (val == 'delete') {
                          await _deleteComment(c);
                        } else if (val == 'report') {
                          _showReportDialog(context, 'Comment', c.id, _socialController);
                        }
                      },
                      itemBuilder: (_) => [
                        if (c.userId == _currentUserId) ...const [
                          PopupMenuItem(
                              value: 'edit',
                              child: Text('Chỉnh sửa')),
                          PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa',
                                  style: TextStyle(
                                      color:
                                      AppColors.error))),
                        ],
                        if (c.userId != _currentUserId)
                          const PopupMenuItem(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(Icons.flag_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text('Báo cáo vi phạm'),
                                ],
                              )),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16,
                  MediaQuery.paddingOf(context).bottom + 8),
              decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: Border(
                      top: BorderSide(color: AppColors.separator))),
              child: Row(
                children: [
                  if (_editingCommentId != null)
                    IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.error),
                        onPressed: () {
                          setState(() {
                            _editingCommentId = null;
                            _commentController.clear();
                            FocusScope.of(context).unfocus();
                          });
                        }),
                  Expanded(
                    child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitComment(),
                        decoration: InputDecoration(
                            hintText: _editingCommentId != null
                                ? 'Chỉnh sửa bình luận...'
                                : 'Thêm bình luận...',
                            border: InputBorder.none)),
                  ),
                  _sendingComment
                      ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2)))
                      : IconButton(
                      icon: const Icon(Icons.send,
                          color: AppColors.brand),
                      onPressed: _submitComment),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, String contentType, int targetId, SocialController social) {
    String selectedReason = 'Spam';
    final detailsController = TextEditingController();
    var isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Báo cáo ${contentType == 'Moment' ? 'khoảnh khắc' : 'bình luận'}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(labelText: 'Lý do báo cáo'),
                      items: const [
                        DropdownMenuItem(value: 'Spam', child: Text('Spam (Rác / Quảng cáo)')),
                        DropdownMenuItem(value: 'Hate Speech', child: Text('Ngôn từ kích động thù hận')),
                        DropdownMenuItem(value: 'Harassment', child: Text('Quấy rối / Đe dọa')),
                        DropdownMenuItem(value: 'Violence', child: Text('Bạo lực / Máu me')),
                        DropdownMenuItem(value: 'Other', child: Text('Lý do khác')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedReason = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Chi tiết (Không bắt buộc)',
                        hintText: 'Nhập thêm chi tiết vi phạm...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Get.back(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          setDialogState(() => isSending = true);
                          final ok = await social.reportContent(
                            contentType: contentType,
                            targetId: targetId,
                            reason: selectedReason,
                            details: detailsController.text.trim().isNotEmpty ? detailsController.text.trim() : null,
                          );
                          setDialogState(() => isSending = false);
                          if (ok) {
                            Get.back();
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Gửi báo cáo'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}


class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _social = Get.find<SocialService>();
  final _socialController = Get.find<SocialController>();
  UserSearchModel? _user;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = Get.arguments as int?;
    try {
      if (id != null) {
        _user = await _social.getUserProfile(id);
        await Future.wait([
          _socialController.fetchFriends(),
          _socialController.fetchPendingRequests(),
        ]);
      }
    } catch (_) {
      SnackbarHelper.error('Không thể tải hồ sơ người dùng');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat() async {
    final user = _user;
    if (user == null) return;
    final room = await _socialController.createDirectChat(user.id);
    if (room == null) return;
    await Get.toNamed(
      AppRoutes.chatRoom,
      arguments: {
        'roomId': room.id,
        'title':
        room.name?.trim().isNotEmpty == true ? room.name : user.fullName,
        'isGroup': false,
        'avatarUrl': room.avatarUrl ?? user.avatarUrl,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Hồ sơ người dùng',
      body: _loading
          ? const LoadingWidget()
          : _user == null
          ? const Center(child: Text('Không tìm thấy'))
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildProfileHeader(_user!),
            const SizedBox(height: 18),
            _buildActions(_user!),
            const SizedBox(height: 18),
            _buildProfileInformation(_user!),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserSearchModel user) {
    final initial = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim()[0].toUpperCase();
    return IosSurfaceCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Column(
          children: [
            SizedBox(
              height: 174,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned.fill(
                    bottom: 42,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: AppColors.homeHeroGradient,
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -30,
                            top: -46,
                            child: _profileDecorationCircle(
                              128,
                              Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          Positioned(
                            left: -22,
                            bottom: -48,
                            child: _profileDecorationCircle(
                              104,
                              Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            top: 17,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.explore_outlined,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'StayHub Traveler',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: 0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: user.avatarUrl?.isNotEmpty == true
                          ? CachedNetworkImage(
                        imageUrl: user.avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _profileInitial(initial),
                      )
                          : _profileInitial(initial),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(
                children: [
                  Text(
                    user.fullName.isEmpty
                        ? 'Người dùng StayHub'
                        : user.fullName,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (user.email?.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      user.email!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Obx(() {
                    final isFriend = _socialController.isFriend(user.id);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isFriend
                            ? AppColors.brandLight
                            : AppColors.surfaceGrouped,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: isFriend
                              ? AppColors.brand.withValues(alpha: 0.16)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFriend
                                ? Icons.people_rounded
                                : Icons.person_outline_rounded,
                            size: 16,
                            color: isFriend
                                ? AppColors.brand
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isFriend ? 'Bạn bè' : 'Thành viên StayHub',
                            style: TextStyle(
                              color: isFriend
                                  ? AppColors.brand
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileDecorationCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _profileInitial(String initial) {
    return Container(
      color: AppColors.brandLight,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.textTheme.displaySmall?.copyWith(
          color: AppColors.brand,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildActions(UserSearchModel user) {
    return Obx(() {
      final isFriend = _socialController.isFriend(user.id);
      final hasIncoming = _socialController.hasIncomingRequest(user.id);
      final sent = _socialController.sentRequestUserIds.contains(user.id);
      final busy = _socialController.processingUserIds.contains(user.id);

      Widget relationshipButton;
      if (isFriend) {
        relationshipButton = FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.people_rounded),
          label: const Text('Đã là bạn bè'),
          style: FilledButton.styleFrom(
            disabledBackgroundColor: AppColors.brandLight,
            disabledForegroundColor: AppColors.brand,
          ),
        );
      } else if (hasIncoming) {
        final request = _socialController.pendingRequests
            .firstWhere((item) => item.senderId == user.id);
        relationshipButton = FilledButton.icon(
          onPressed: busy
              ? null
              : () => _socialController.respondRequest(request.id, true),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Chấp nhận'),
          style: _profilePrimaryButtonStyle(),
        );
      } else {
        relationshipButton = FilledButton.icon(
          onPressed: busy || sent
              ? null
              : () => _socialController.sendFriendRequest(user.id),
          icon: Icon(
            sent ? Icons.schedule_rounded : Icons.person_add_rounded,
          ),
          label: Text(sent ? 'Đã gửi lời mời' : 'Kết bạn'),
          style: _profilePrimaryButtonStyle(),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final chatButton = OutlinedButton.icon(
            onPressed: busy ? null : _openChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Nhắn tin'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.brand),
              backgroundColor: AppColors.surfaceElevated,
            ),
          );
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 50, child: relationshipButton),
                const SizedBox(height: 10),
                SizedBox(height: 50, child: chatButton),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: SizedBox(height: 50, child: relationshipButton)),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 50, child: chatButton)),
            ],
          );
        },
      );
    });
  }

  ButtonStyle _profilePrimaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.35),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
    );
  }

  Widget _buildProfileInformation(UserSearchModel user) {
    final joinedAt = user.createdAt == null
        ? 'Chưa cập nhật'
        : DateFormat('MM/yyyy').format(user.createdAt!.toLocal());
    return IosSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    size: 19,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  'Thông tin cá nhân',
                  style: AppTextStyles.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _profileInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Họ và tên',
            value: user.fullName,
          ),
          _profileInfoRow(
            icon: Icons.people_outline_rounded,
            label: 'Giới tính',
            value: user.gender,
          ),
          _profileInfoRow(
            icon: Icons.cake_outlined,
            label: 'Ngày sinh',
            value: user.dateOfBirth,
          ),
          _profileInfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Tham gia từ',
            value: joinedAt,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _profileInfoRow({
    required IconData icon,
    required String label,
    String? value,
    bool showDivider = true,
  }) {
    final displayValue =
    value?.trim().isNotEmpty == true ? value!.trim() : 'Chưa cập nhật';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  displayValue,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 68, endIndent: 18),
      ],
    );
  }
}