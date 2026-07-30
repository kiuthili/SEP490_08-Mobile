import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../constants/api_constants.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../models/social_models.dart'; // -É+ú th+¬m
import '../../models/tour_model.dart';
import '../../widgets/comment_bottom_sheet.dart';
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
  String _roomTitle = 'sc_sds_chat'.tr;
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
        _roomTitle = enriched?.name ?? room.name ?? 'sc_sds_direct_message'.tr;
        _avatarUrl = enriched?.avatarUrl ?? room.avatarUrl;
      }

      if (_roomId != null) {
        _signalR.setActiveChatRoom(_roomId);
        await _socialController.markChatRoomAsRead(_roomId!);
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
          unawaited(_socialController.markChatRoomAsRead(_roomId!));
          _socialController.fetchChatRooms();
          _scrollToBottom();
        });
        _scrollToBottom(jump: true);
      } else {
        _error = 'sc_sds_chat_not_found'.tr;
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

  Future<void> _shareLocation() async {
    final roomId = _roomId;
    if (roomId == null) return;

    setState(() => _sending = true);
    try {
      final token = await _socialService.generateTrackingToken();
      if (token.isNotEmpty) {
        // URL -æß+Öng: d+¦ng ApiConstants.webUrl -æß+â t¦¦¦íng th+¡ch vß+¢i tunnel -æang chß¦íy.
        // Khi deploy production th+¼ chß+ë cß¦ºn thay baseUrl trong api_constants.dart.
        final trackingUrl = '${ApiConstants.webUrl}/track/$token';
        final shareText =
            'sc_sds_live_location_prefix'.tr + '[LocationShare:${jsonEncode({
              'token': token,
              'url': trackingUrl
            })}]';
        await _socialController.sendChatMessage(roomId, shareText);
        SnackbarHelper.success('sc_sds_location_shared'.tr);
      } else {
        SnackbarHelper.error('sc_sds_location_share_failed'.tr);
      }
    } catch (_) {
      SnackbarHelper.error('sc_sds_location_share_error'.tr);
    } finally {
      setState(() => _sending = false);
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
      SnackbarHelper.error('sc_sds_failed_send_message_prefix'.tr + e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    final roomId = _roomId;
    _signalR.setActiveChatRoom(null);
    if (roomId != null) {
      unawaited(_signalR.leaveChatRoom(roomId));
      unawaited(_socialController.markChatRoomAsRead(roomId));
    }
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = Get.find<StorageService>().user?.id;

    return AppScreen(
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: _isGroup ? AppColors.brandGradient : null,
              color: _isGroup ? null : AppColors.brandLight,
              shape: BoxShape.circle,
            ),
            child: _avatarUrl?.isNotEmpty == true
                ? CachedNetworkImage(
                    imageUrl: _avatarUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      _isGroup ? Icons.groups_2_rounded : Icons.person_rounded,
                      color: _isGroup ? Colors.white : AppColors.brand,
                      size: 20,
                    ),
                  )
                : Icon(
                    _isGroup ? Icons.groups_2_rounded : Icons.person_rounded,
                    color: _isGroup ? Colors.white : AppColors.brand,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _roomTitle,
                  style: AppTextStyles.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isGroup ? 'sc_sds_tour_group_chat'.tr : 'sc_sds_active_now'.tr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('sc_sds_leave_group'.tr),
                  ],
                ),
              ),
            ],
          )
        else
          const SizedBox(width: 8),
      ],
      body: _loading
          ? LoadingWidget(message: 'sc_sds_connecting_chat'.tr)
          : _error != null
              ? _ChatError(message: _error!, onRetry: _initRoom)
              : Column(
                  children: [
                    if (_isGroup && _scheduleId != null)
                      _GroupScheduleCard(
                        scheduleId: _scheduleId!,
                        fallbackTitle: _roomTitle,
                        fallbackAvatarUrl: _avatarUrl,
                        schedule: _schedule,
                        loading: _loadingSchedule,
                        hasError: _scheduleError != null,
                        onRetry: _loadSchedule,
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
                                final next = index < _messages.length - 1
                                    ? _messages[index + 1]
                                    : null;
                                final showDate = previous == null ||
                                    !_sameDay(previous.sentAt, m.sentAt);

                                bool isLastInBlock = true;
                                if (next != null &&
                                    next.senderId == m.senderId &&
                                    m.sentAt != null &&
                                    next.sentAt != null) {
                                  final diff = next.sentAt!
                                      .difference(m.sentAt!)
                                      .inMinutes
                                      .abs();
                                  if (diff < 1) {
                                    isLastInBlock = false;
                                  }
                                }

                                return Column(
                                  children: [
                                    if (showDate) _DateDivider(date: m.sentAt),
                                    _MessageBubble(
                                      message: m,
                                      isMe: m.senderId == myId,
                                      showSender: _isGroup,
                                      showAvatar:
                                          m.senderId != myId && isLastInBlock,
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
                      onShareLocation: _shareLocation,
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
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.groups_2_rounded,
                                    size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text('sc_sds_tour_group_caps'.tr,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6)),
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
                                    fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.navy, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      if (loading && schedule == null)
                        const _ScheduleLoading()
                      else if (hasError && schedule == null)
                        _ScheduleLoadError(onRetry: onRetry)
                      else if (schedule != null)
                        _ScheduleMetadata(schedule: schedule!)
                      else
                        Text('sc_sds_no_schedule_info'.tr,
                            style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                if (canOpenTour) ...[
                  const SizedBox(width: 7),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppColors.brand),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
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
              errorWidget: (_, __, ___) => _fallback())
          : _fallback(),
    );
  }

  Widget _fallback() =>
      const Icon(Icons.luggage_rounded, color: Colors.white, size: 30);
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
              ? '$location GÇó $days ' + 'sc_sds_days'.tr
              : days.toString() + 'sc_sds_days'.tr,
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
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _ScheduleLoading extends StatelessWidget {
  const _ScheduleLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('sc_sds_loading_schedule'.tr,
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
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
            child: Text('sc_sds_failed_load_schedule'.tr,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.error))),
        InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text('sc_sds_retry'.tr,
                style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
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
            Text(isGroup ? 'sc_sds_hello_group'.tr : 'sc_sds_start_chat'.tr,
                style: AppTextStyles.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 7),
            Text(
              isGroup
                  ? 'sc_sds_group_chat_desc'.tr
                  : 'sc_sds_direct_chat_desc'.tr,
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
        ? 'sc_sds_chat'.tr
        : DateFormat('dd/MM/yyyy').format(date!.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child:
                  Text(label, style: Theme.of(context).textTheme.labelSmall)),
          Expanded(child: Divider()),
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
    required this.showAvatar,
  });

  final ChatMessageModel message;
  final bool isMe;
  final bool showSender;
  final bool showAvatar;

  Widget _buildContent(BuildContext context) {
    final content = message.content;

    // 1) Moment Share
    if (content.contains('[MomentShare:')) {
      try {
        final match = RegExp(r'\[MomentShare:({.*?})\]').firstMatch(content);
        if (match != null) {
          final data = jsonDecode(match.group(1)!);
          final int id = data['id'];
          final String imageUrl = data['imageUrl'];
          final String? caption = data['caption'];

          return GestureDetector(
            onTap: () {
              Get.toNamed(AppRoutes.momentDetail, arguments: id);
            },
            child: Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.blue.shade900.withOpacity(0.4)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: isMe ? Colors.blue.shade800 : Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: isMe
                        ? Colors.blue.shade900.withOpacity(0.6)
                        : Colors.grey.shade200,
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt,
                            size: 14,
                            color: isMe
                                ? Colors.yellow.shade200
                                : AppColors.brand),
                        const SizedBox(width: 6),
                        Text(
                          'sc_sds_moment_caps'.tr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isMe ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AspectRatio(
                    aspectRatio: 4 / 5,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade300,
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  if (caption != null && caption.trim().isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
      } catch (_) {}
    }

    // 2) Location Share
    if (content.contains('[LocationShare:')) {
      try {
        final match = RegExp(r'\[LocationShare:({.*?})\]').firstMatch(content);
        if (match != null) {
          final data = jsonDecode(match.group(1)!);
          final String token = data['token'] as String? ?? '';
          // url -æ¦¦ß+úc l¦¦u trong payload hoß¦+c x+óy lß¦íi tß+½ ApiConstants.webUrl -æß+Öng
          final String trackingUrl =
              (data['url'] as String?)?.isNotEmpty == true
                  ? data['url'] as String
                  : '${ApiConstants.webUrl}/track/$token';

          return GestureDetector(
            onTap: () {
              // Mß+ƒ URL theo d+¦i -æß+Öng (ng+¦c/tunnel/production)
              Get.toNamed('/track/$token');
            },
            child: Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.blue.shade900.withOpacity(0.4)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: isMe ? Colors.blue.shade800 : Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'sc_sds_live_location_caps'.tr,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'sc_sds_track_location_desc'.tr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'sc_sds_view_location'.tr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } catch (_) {}
    }

    return Text(
      content,
      style: TextStyle(
        color: isMe ? Colors.white : AppColors.textPrimary,
        fontSize: 15,
        height: 1.35,
      ),
    );
  }

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
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
      decoration: BoxDecoration(
        color: isMe ? AppColors.brand : AppColors.surfaceElevated,
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
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe &&
              showSender &&
              message.senderName?.isNotEmpty == true) ...[
            Text(message.senderName!,
                style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
          ],
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _buildContent(context),
              if (message.sentAt != null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 1),
                  child: Text(
                    DateFormat('HH:mm').format(message.sentAt!.toLocal()),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              _MessageAvatar(message: message)
            else
              const SizedBox(width: 28),
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
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceGrouped,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.textTertiary),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      message.content,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.35),
                    ),
                  ),
                ],
              ),
              if (message.sentAt != null) ...[
                const SizedBox(height: 3),
                Text(DateFormat('HH:mm').format(message.sentAt!.toLocal()),
                    style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
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
          color: AppColors.brandLight, shape: BoxShape.circle),
      child: message.senderAvatar?.isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: message.senderAvatar!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(child: Text(initial)))
          : Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w800))),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    this.onShareLocation,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback? onShareLocation;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottom > 0 ? bottom + 10 : 20),
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
              decoration: InputDecoration(
                hintText: 'sc_sds_input_message'.tr,
                filled: true,
                fillColor: AppColors.surfaceGrouped,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: onShareLocation != null
                    ? IconButton(
                        icon: const Icon(Icons.location_on_rounded,
                            color: AppColors.brand),
                        onPressed: onShareLocation,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: sending ? null : onSend,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Ink(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: sending ? null : AppColors.brandGradient,
                  color:
                      sending ? AppColors.brand.withValues(alpha: 0.35) : null,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 21),
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
              'sc_sds_failed_connect_chat'.tr,
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
              label: Text('sc_sds_retry'.tr),
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
  MomentModel? _moment;
  bool _loading = true;
  String? _error;

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
        _error = 'Invalid moment ID';
        _loading = false;
      });
      return;
    }

    try {
      moment = _findInFeed(momentId) ?? moment;
      if (moment != null) {
        setState(() {
          _moment = moment;
          _loading = false;
        });
      }

      final latest = await _socialController.getMomentById(momentId);
      if (mounted) {
        setState(() {
          _moment = latest;
          _error = null;
        });
      }
    } catch (e) {
      if (moment == null && mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCommentBottomSheet(BuildContext context, MomentModel moment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        moment: moment,
      ),
    ).then((_) async {
      if (mounted) {
        final updated = _findInFeed(moment.id) ?? await _socialController.getMomentById(moment.id);
        if (updated != null && mounted) {
          setState(() => _moment = updated);
        }
      }
    });
  }

  void _shareMoment(MomentModel moment) {
    final rooms = _socialController.chatRooms;
    if (rooms.isEmpty) {
      SnackbarHelper.error('No conversation found to share.');
      return;
    }

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Send to',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true, 
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final roomName =
                      (room.name != null && room.name!.trim().isNotEmpty)
                          ? room.name!
                          : 'Conversation';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.brandLight,
                      backgroundImage:
                          (room.avatarUrl != null && room.avatarUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(room.avatarUrl!)
                              : null,
                      child: (room.avatarUrl == null || room.avatarUrl!.isEmpty)
                          ? const Icon(Icons.chat_bubble_outline_rounded,
                              color: AppColors.brand)
                          : null,
                    ),
                    title: Text(
                      roomName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      room.isGroup ? 'Tour Group' : 'Direct Chat',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                    trailing: const Icon(Icons.send_rounded,
                        color: AppColors.brand, size: 20),
                    onTap: () async {
                      Get.back(); // -É+¦ng bottom sheet
                      final shareText = '[MomentShare:${jsonEncode({
                            'id': moment.id,
                            'imageUrl': moment.imageUrl,
                            'caption': moment.caption ?? '',
                          })}]';

                      await _socialController.sendChatMessage(
                          room.id, shareText);
                      SnackbarHelper.success('Moment shared successfully');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _error != null || _moment == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error ?? 'Moment does not exist or has been deleted',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _loadMoment, child: const Text('Retry')),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Go Back', style: TextStyle(color: Colors.white70)),
                      )
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    MomentCard(
                      moment: _moment!,
                      currentUserId: _currentUserId,
                      isDetail: true,
                      onDelete: (id) async {
                        await _socialController.deleteMoment(id);
                        Get.back();
                      },
                      onShare: () {
                        if (_moment != null) {
                          _shareMoment(_moment!);
                        }
                      },
                      onLike: (isLike) async {
                        if (_moment == null) return;
                        if (_moment!.isLikedByMe == isLike) return;

                        final newCount =
                            (_moment!.reactionCount + (isLike ? 1 : -1))
                                .clamp(0, 1 << 30)
                                .toInt();
                        setState(() {
                          _moment = _moment!.copyWith(
                            isLikedByMe: isLike,
                            reactionCount: newCount,
                          );
                        });

                        await _socialController.reactMoment(
                            _moment!.id, isLike);

                        final updated = _findInFeed(_moment!.id);
                        if (updated != null && mounted) {
                          setState(() => _moment = updated);
                        }
                      },
                      onReport: (id) => _showReportDialog(
                          context, 'Moment', id, _socialController),
                      onComment: () {
                        if (_moment != null) {
                          _showCommentBottomSheet(context, _moment!);
                        }
                      },
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: SafeArea(
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Get.back(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
  void _showReportDialog(BuildContext context, String contentType, int targetId,
      SocialController social) {
    String selectedReason = 'Spam';
    final detailsController = TextEditingController();
    var isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                  'Report ${contentType == 'Moment' ? 'moment' : 'comment'}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(
                          labelText: 'Reason for reporting'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Spam', child: Text('Spam / Advertisement')),
                        DropdownMenuItem(
                            value: 'Hate Speech', child: Text('Hate Speech')),
                        DropdownMenuItem(
                            value: 'Harassment',
                            child: Text('Harassment / Threats')),
                        DropdownMenuItem(
                            value: 'Violence', child: Text('Violence / Gore')),
                        DropdownMenuItem(
                            value: 'Other', child: Text('Other reason')),
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
                        labelText: 'Details (Optional)',
                        hintText: 'Enter violation details...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
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
                            details: detailsController.text.trim().isNotEmpty
                                ? detailsController.text.trim()
                                : null,
                          );
                          setDialogState(() => isSending = false);
                          if (ok) {
                            Navigator.pop(context);
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Report'),
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

  // moments fetched for this user
  List<MomentModel> _moments = [];
  bool _momentsLoading = false;

  Future<void> _load() async {
    final id = Get.arguments as int?;
    try {
      if (id != null) {
        _user = await _social.getUserProfile(id);
        await Future.wait([
          _socialController.fetchFriends(),
          _socialController.fetchPendingRequests(),
          _loadMoments(id),
        ]);
      }
    } catch (_) {
      SnackbarHelper.error('sc_sds_failed_load_profile'.tr);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoments(int userId, {bool silent = false}) async {
    try {
      if (!silent) setState(() => _momentsLoading = true);
      _moments = await _social.getUserMoments(userId);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _momentsLoading = false);
    }
  }

  void _openFeedAtIndex(int index) async {
    if (_user == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OtherUserFeedScreen(
          user: _user!,
          moments: _moments,
          initialIndex: index,
          currentUserId: _socialController.currentUserId,
          socialController: _socialController,
        ),
      ),
    );
    final id = Get.arguments as int?;
    if (id != null) {
      _loadMoments(id, silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return AppScreen(
      title: user?.fullName.isNotEmpty == true ? user!.fullName : 'sc_sds_profile'.tr,
      body: _loading
          ? const LoadingWidget()
          : user == null
              ? Center(child: Text('sc_sds_not_found'.tr))
              : RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildIgHeader(user)),
                      SliverToBoxAdapter(child: _buildIgActions(user)),
                      const SliverToBoxAdapter(
                        child: Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: AppColors.separator),
                      ),
                      SliverToBoxAdapter(child: _buildTabRow()),
                      const SliverToBoxAdapter(
                        child: Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: AppColors.separator),
                      ),
                      if (_momentsLoading)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.all(60),
                            child:
                                LoadingWidget(message: 'sc_sds_loading_posts'.tr),
                          ),
                        )
                      else if (_moments.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyMoments(),
                        )
                      else
                        _buildPhotoGrid(),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 32),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildIgHeader(UserSearchModel user) {
    final initial = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar vß+¢i gradient ring
              _buildAvatarRing(user, initial),
              const SizedBox(width: 24),
              // Stats
              Expanded(
                child: Obx(() {
                  final isFriend = _socialController.isFriend(user.id);
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGrouped,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.separator),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(_moments.length.toString(), 'sc_sds_posts'.tr),
                        Container(
                            width: 1, height: 28, color: AppColors.separator),
                        _buildStat(
                          isFriend ? 'sc_sds_friends'.tr : 'sc_sds_member'.tr,
                          'sc_sds_relationship'.tr,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user.fullName.isEmpty ? 'StayHub User' : user.fullName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (user.email?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              user.email!,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarRing(UserSearchModel user, String initial) {
    return Stack(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.brand, Color(0xFF34C3FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: 3,
          left: 3,
          right: 3,
          bottom: 3,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          right: 4,
          bottom: 4,
          child: CircleAvatar(
            backgroundColor: AppColors.brandLight,
            backgroundImage: user.avatarUrl?.isNotEmpty == true
                ? CachedNetworkImageProvider(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildIgActions(UserSearchModel user) {
    return Obx(() {
      final isFriend = _socialController.isFriend(user.id);
      final hasIncoming = _socialController.hasIncomingRequest(user.id);
      final sent = _socialController.sentRequestUserIds.contains(user.id);
      final busy = _socialController.processingUserIds.contains(user.id);

      String friendLabel;
      IconData friendIcon;
      Color friendBg;
      Color friendFg;
      VoidCallback? friendAction;

      if (isFriend) {
        friendLabel = 'sc_sds_friends'.tr;
        friendIcon = Icons.people_rounded;
        friendBg = AppColors.brandLight;
        friendFg = AppColors.brand;
        friendAction = null;
      } else if (hasIncoming) {
        final req = _socialController.pendingRequests
            .firstWhere((r) => r.senderId == user.id);
        friendLabel = 'sc_sds_accept'.tr;
        friendIcon = Icons.person_add_alt_1_rounded;
        friendBg = AppColors.brand;
        friendFg = Colors.white;
        friendAction =
            busy ? null : () => _socialController.respondRequest(req.id, true);
      } else {
        friendLabel = sent ? 'sc_sds_sent'.tr : 'sc_sds_add_friend'.tr;
        friendIcon = sent ? Icons.schedule_rounded : Icons.person_add_rounded;
        friendBg = AppColors.brand;
        friendFg = Colors.white;
        friendAction = busy || sent
            ? null
            : () => _socialController.sendFriendRequest(user.id);
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: friendAction,
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: friendBg,
                    border: Border.all(
                      color: isFriend
                          ? AppColors.brand.withValues(alpha: 0.3)
                          : AppColors.brand,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(friendIcon, size: 15, color: friendFg),
                      const SizedBox(width: 6),
                      Text(
                        friendLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: friendFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: busy ? null : _openChat,
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.separator, width: 1),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 15, color: AppColors.textPrimary),
                      SizedBox(width: 6),
                      Text(
                        'sc_sds_message_action'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTabRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.grid_on_rounded, size: 26, color: AppColors.navy),
          Icon(Icons.map_outlined, size: 26, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemCount: _moments.length,
      itemBuilder: (context, index) {
        final moment = _moments[index];
        return GestureDetector(
          onTap: () => _openFeedAtIndex(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: moment.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppColors.surfaceElevated),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.surfaceElevated,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.border),
                ),
              ),
              if (moment.reactionCount > 0)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite,
                            color: Colors.white, size: 11),
                        const SizedBox(width: 3),
                        Text(
                          moment.reactionCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyMoments() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_library_outlined,
            size: 56, color: AppColors.textTertiary),
        SizedBox(height: 16),
        Text(
          'sc_sds_no_posts_yet'.tr,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
      ],
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
                              child: Row(
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
                        ? 'sc_sds_stayhub_user'.tr
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
                            isFriend ? 'sc_sds_friends'.tr : 'sc_sds_stayhub_member'.tr,
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
          label: Text('sc_sds_already_friends'.tr),
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
          label: Text('sc_sds_accept'.tr),
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
          label: Text(sent ? 'sc_sds_request_sent'.tr : 'sc_sds_add_friend'.tr),
          style: _profilePrimaryButtonStyle(),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final chatButton = OutlinedButton.icon(
            onPressed: busy ? null : _openChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: Text('sc_sds_message_action'.tr),
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
        ? 'sc_sds_not_updated'.tr
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
                  'sc_sds_personal_info'.tr,
                  style: AppTextStyles.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _profileInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'sc_sds_full_name'.tr,
            value: user.fullName,
          ),
          _profileInfoRow(
            icon: Icons.people_outline_rounded,
            label: 'sc_sds_gender'.tr,
            value: user.gender,
          ),
          _profileInfoRow(
            icon: Icons.cake_outlined,
            label: 'sc_sds_dob'.tr,
            value: user.dateOfBirth,
          ),
          _profileInfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'sc_sds_joined_since'.tr,
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
        value?.trim().isNotEmpty == true ? value!.trim() : 'sc_sds_not_updated'.tr;
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
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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

// GöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇ
// Full-screen vertical feed for other user's posts
// GöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇGöÇ
class _OtherUserFeedScreen extends StatefulWidget {
  const _OtherUserFeedScreen({
    required this.user,
    required this.moments,
    required this.initialIndex,
    required this.currentUserId,
    required this.socialController,
  });
  final UserSearchModel user;
  final List<MomentModel> moments;
  final int initialIndex;
  final int currentUserId;
  final SocialController socialController;

  @override
  State<_OtherUserFeedScreen> createState() => _OtherUserFeedScreenState();
}

class _OtherUserFeedScreenState extends State<_OtherUserFeedScreen> {
  late List<MomentModel> _moments;

  @override
  void initState() {
    super.initState();
    // Bß¦»t -æß¦ºu tß+½ b+ái -æ¦¦ß+úc chß+ìn
    _moments = widget.moments.sublist(widget.initialIndex);
    _loadFullMoments();
  }

  Future<void> _loadFullMoments() async {
    for (int i = 0; i < _moments.length; i++) {
      try {
        final fullData = await widget.socialController.getMomentById(_moments[i].id);
        if (mounted) {
          setState(() {
            _moments[i] = fullData;
          });
        }
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> _toggleLike(int index) async {
    final m = _moments[index];
    final newVal = !m.isLikedByMe;
    setState(() {
      _moments[index] = m.copyWith(
        isLikedByMe: newVal,
        reactionCount: (m.reactionCount + (newVal ? 1 : -1)).clamp(0, 1 << 30),
      );
    });
    await widget.socialController.reactMoment(m.id, newVal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          'sc_sds_posts'.tr,
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: Colors.black12, height: 0.5),
        ),
      ),
      body: ListView.separated(
        itemCount: _moments.length,
        separatorBuilder: (_, __) =>
            Container(height: 8, color: const Color(0xFFF0F0F0)),
        itemBuilder: (context, index) {
          final moment = _moments[index];
          return _OtherFeedItem(
            user: widget.user,
            moment: moment,
            currentUserId: widget.currentUserId,
            onLike: () => _toggleLike(index),
            onComment: () {
              Get.toNamed(AppRoutes.momentDetail, arguments: moment);
            },
          );
        },
      ),
    );
  }
}

class _OtherFeedItem extends StatelessWidget {
  const _OtherFeedItem({
    required this.user,
    required this.moment,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
  });
  final UserSearchModel user;
  final MomentModel moment;
  final int currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.brandLight,
                  backgroundImage: user.avatarUrl?.isNotEmpty == true &&
                          !user.avatarUrl!.toLowerCase().endsWith('.svg')
                      ? CachedNetworkImageProvider(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null ||
                          user.avatarUrl!.isEmpty ||
                          user.avatarUrl!.toLowerCase().endsWith('.svg')
                      ? Text(
                          (user.fullName?.isNotEmpty == true
                                  ? user.fullName![0]
                                  : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand,
                              fontSize: 14),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.fullName ?? 'StayHub User',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onComment,
            child: Hero(
              tag: 'moment_image_${moment.id}',
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: CachedNetworkImage(
                  imageUrl: moment.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      Container(height: 300, color: Colors.black12),
                  errorWidget: (_, __, ___) => Container(
                    height: 300,
                    color: Colors.black12,
                    child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.black38, size: 48)),
                  ),
                ),
              ),
            ),
          ),
          if (moment.caption?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                moment.caption!,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    moment.isLikedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color:
                        moment.isLikedByMe ? AppColors.error : Colors.black87,
                    size: 28,
                  ),
                  onPressed: onLike,
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      color: Colors.black87, size: 26),
                  onPressed: onComment,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              Get.locale?.languageCode == 'vi'
                  ? '${moment.reactionCount} l¦¦ß+út th+¡ch'
                  : '${moment.reactionCount} likes',
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: GestureDetector(
              onTap: onComment,
              child: Text(
                moment.comments.isNotEmpty
                    ? (Get.locale?.languageCode == 'vi'
                        ? 'Xem tß¦Ñt cß¦ú ${moment.comments.length} b+¼nh luß¦¡n'
                        : 'View all ${moment.comments.length} comments')
                    : (Get.locale?.languageCode == 'vi'
                        ? 'Th+¬m b+¼nh luß¦¡n...'
                        : 'Add a comment...'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Text(
              DateFormat('HH:mm - dd/MM/yyyy').format(moment.createdAt.toLocal()),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
      
