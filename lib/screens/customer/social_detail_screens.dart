import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../models/tour_model.dart';
import '../../routes/app_routes.dart';
import '../../services/signalr_service.dart';
import '../../services/social_service.dart';
import '../../services/storage_service.dart';
import '../../services/tour_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/loading_widget.dart';

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
                  .clamp(
                0,
                _scrollController.position.maxScrollExtent,
              ),
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
    final title =
        tour?.name.trim().isNotEmpty == true ? tour!.name : fallbackTitle;
    final imageUrl = tour?.imageUrl?.trim().isNotEmpty == true
        ? tour!.imageUrl
        : fallbackAvatarUrl;
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
          onTap: canOpenTour
              ? () => Get.toNamed(AppRoutes.tourDetail, arguments: tour.id)
              : null,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.groups_2_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'NHÓM TOUR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '#$scheduleId',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      if (loading && schedule == null)
                        const _ScheduleLoading()
                      else if (hasError && schedule == null)
                        _ScheduleLoadError(onRetry: onRetry)
                      else if (schedule != null)
                        _ScheduleMetadata(schedule: schedule!)
                      else
                        Text(
                          'Không có thông tin lịch khởi hành',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
                if (canOpenTour) ...[
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.brand,
                  ),
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
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => const Icon(
        Icons.luggage_rounded,
        color: Colors.white,
        size: 30,
      );
}

class _ScheduleMetadata extends StatelessWidget {
  const _ScheduleMetadata({required this.schedule});

  final TourScheduleModel schedule;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final location = schedule.tour?.locationLabel;
    final days =
        schedule.returnDate.difference(schedule.departureDate).inDays.abs() + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScheduleMetaLine(
          icon: Icons.calendar_month_rounded,
          text:
              '${dateFormat.format(schedule.departureDate.toLocal())} - ${dateFormat.format(schedule.returnDate.toLocal())}',
        ),
        const SizedBox(height: 4),
        _ScheduleMetaLine(
          icon: Icons.location_on_rounded,
          text: location?.trim().isNotEmpty == true
              ? '$location • $days ngày'
              : '$days ngày',
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
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
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
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text(
          'Đang tải thông tin lịch...',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
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
        Expanded(
          child: Text(
            'Chưa tải được lịch khởi hành',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.error,
                ),
          ),
        ),
        InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(99),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              'Thử lại',
              style: TextStyle(
                color: AppColors.brand,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
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
            Text(
              isGroup ? 'Chào cả đoàn nào!' : 'Bắt đầu cuộc trò chuyện',
              style: AppTextStyles.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            Text(
              isGroup
                  ? 'Trao đổi lịch trình và kết nối với những người cùng chuyến đi.'
                  : 'Gửi một lời chào để bắt đầu nhắn tin trên StayHub.',
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
    final label = date == null
        ? 'Tin nhắn'
        : DateFormat('dd/MM/yyyy').format(date!.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
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
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
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
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe &&
              showSender &&
              message.senderName?.isNotEmpty == true) ...[
            Text(
              message.senderName!,
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.textPrimary,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          if (message.sentAt != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                DateFormat('HH:mm').format(message.sentAt!.toLocal()),
                style: TextStyle(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.65)
                      : AppColors.textTertiary,
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
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
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
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      message.content,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
              if (message.sentAt != null) ...[
                const SizedBox(height: 3),
                Text(
                  DateFormat('HH:mm').format(message.sentAt!.toLocal()),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
      decoration: const BoxDecoration(
        color: AppColors.brandLight,
        shape: BoxShape.circle,
      ),
      child: message.senderAvatar?.isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: message.senderAvatar!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(child: Text(initial)),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.brand,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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
              decoration: const InputDecoration(
                hintText: 'Nhập tin nhắn...',
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
              ),
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
                  color:
                      sending ? AppColors.brand.withValues(alpha: 0.35) : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
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

class MomentDetailScreen extends GetView<SocialController> {
  const MomentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final momentId = Get.arguments as int?;
    final userId = Get.find<StorageService>().user?.id;
    MomentModel? moment;
    for (final m in controller.moments) {
      if (m.id == momentId) {
        moment = m;
        break;
      }
    }

    return AppScreen(
      title: 'Chi tiết Moment',
      actions: [
        if (moment != null && moment.userId == userId)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await controller.deleteMoment(moment!.id);
              Get.back();
            },
          ),
      ],
      body: moment == null
          ? const Center(child: Text('Không tìm thấy moment'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(moment.userName?.isNotEmpty == true
                          ? moment.userName![0].toUpperCase()
                          : '?'),
                    ),
                    title: Text(moment.userName ?? ''),
                    subtitle: moment.createdAt != null
                        ? Text(moment.createdAt.toString())
                        : null,
                  ),
                  if (moment.content != null) Text(moment.content!),
                  if (moment.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Image.network(moment.imageUrl!, fit: BoxFit.cover),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(moment.hasReacted
                            ? Icons.favorite
                            : Icons.favorite_border),
                        onPressed: () => controller.reactMoment(moment!.id),
                      ),
                      Text('${moment.reactionCount}'),
                    ],
                  ),
                  const Divider(),
                  Text('Bình luận',
                      style: Theme.of(context).textTheme.titleMedium),
                  ...moment.comments.map((c) {
                    final isOwner = c.userId == userId;
                    return ListTile(
                      title: Text(c.userName ?? 'User'),
                      subtitle: Text(c.content),
                      trailing: isOwner
                          ? PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  final ctrl = TextEditingController(
                                    text: c.content,
                                  );
                                  final newText = await showDialog<String>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Sửa bình luận'),
                                      content: TextField(controller: ctrl),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, ctrl.text),
                                          child: const Text('Lưu'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (newText != null && newText.isNotEmpty) {
                                    await controller.updateComment(
                                      c.id,
                                      newText,
                                    );
                                  }
                                } else if (v == 'delete') {
                                  await controller.deleteComment(c.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Sửa'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Xóa'),
                                ),
                              ],
                            )
                          : null,
                    );
                  }),
                ],
              ),
            ),
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
  UserSearchModel? _user;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = Get.arguments as int?;
    if (id != null) _user = await _social.getUserProfile(id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Hồ sơ người dùng',
      body: _loading
          ? const LoadingWidget()
          : _user == null
              ? const Center(child: Text('Không tìm thấy'))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: _user!.avatarUrl != null
                            ? NetworkImage(_user!.avatarUrl!)
                            : null,
                        child: _user!.avatarUrl == null
                            ? Text(
                                _user!.fullName.isNotEmpty
                                    ? _user!.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 28),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(_user!.fullName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text(_user!.email ?? ''),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => Get.find<SocialController>()
                            .sendFriendRequest(_user!.id),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Kết bạn'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Get.toNamed(
                          AppRoutes.chatRoom,
                          arguments: _user!.id,
                        ),
                        icon: const Icon(Icons.chat),
                        label: const Text('Nhắn tin'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
