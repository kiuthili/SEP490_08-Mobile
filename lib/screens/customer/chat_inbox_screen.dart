import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

enum _InboxFilter { all, direct, group }

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen>
    with SingleTickerProviderStateMixin {
  final _social = Get.find<SocialController>();
  final _searchController = TextEditingController();
  late final TabController _tabController;
  _InboxFilter _filter = _InboxFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _filter = _InboxFilter.values[_tabController.index];
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _social.fetchChatRooms();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ChatRoomModel> get _visibleRooms {
    Iterable<ChatRoomModel> rooms = _social.chatRooms;
    if (_filter == _InboxFilter.direct) {
      rooms = rooms.where((room) => !room.isGroup);
    } else if (_filter == _InboxFilter.group) {
      rooms = rooms.where((room) => room.isGroup);
    }
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      rooms = rooms.where(
        (room) =>
            (room.name ?? '').toLowerCase().contains(query) ||
            (room.lastMessage ?? '').toLowerCase().contains(query),
      );
    }
    return rooms.toList();
  }

  Future<void> _openRoom(ChatRoomModel room) async {
    if (room.unreadCount > 0) {
      await _social.markChatRoomAsRead(room.id);
    }
    await Get.toNamed(
      AppRoutes.chatRoom,
      arguments: {
        'roomId': room.id,
        'title': room.name,
        'isGroup': room.isGroup,
        'avatarUrl': room.avatarUrl,
        'scheduleId': room.scheduleId,
      },
    );
    if (mounted) {
      await _social.fetchChatRooms();
    }
  }

  Future<void> _showNewMessageSheet() async {
    await Get.toNamed(AppRoutes.newMessage);
    if (mounted) {
      await _social.fetchChatRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'sc_ib_title'.tr,
      actions: [
        IconButton(
          tooltip: 'sc_ib_new_message'.tr,
          onPressed: _showNewMessageSheet,
          icon: const Icon(Icons.edit_square),
        ),
        const SizedBox(width: 6),
      ],
      body: RefreshIndicator(
        onRefresh: _social.fetchChatRooms,
        child: Obx(() {
          final rooms = _visibleRooms;
          if (_social.isChatLoading.value && _social.chatRooms.isEmpty) {
            return LoadingWidget(message: 'sc_ib_loading_chats'.tr);
          }
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'sc_ib_search'.tr,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.brand,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.brand,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(text: 'sc_ib_tab_all'.tr),
                    Tab(text: 'sc_ib_tab_direct'.tr),
                    Tab(text: 'sc_ib_tab_group'.tr),
                  ],
                ),
              ),
              if (rooms.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    title: _query.isNotEmpty
                        ? 'sc_ib_empty_search_title'.tr
                        : _filter == _InboxFilter.group
                            ? 'sc_ib_empty_group_title'.tr
                            : 'sc_ib_empty_direct_title'.tr,
                    subtitle: _filter == _InboxFilter.group
                        ? 'sc_ib_empty_group_desc'.tr
                        : 'sc_ib_empty_direct_desc'.tr,
                    icon: _filter == _InboxFilter.group
                        ? Icons.groups_2_outlined
                        : Icons.forum_outlined,
                    onRetry: _social.fetchChatRooms,
                    retryLabel: 'sc_ib_retry'.tr,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return _ConversationCard(
                        room: room,
                        onTap: () => _openRoom(room),
                      );
                    },
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.room, required this.onTap});

  final ChatRoomModel room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = room.name?.trim().isNotEmpty == true
        ? room.name!
        : room.isGroup
            ? 'sc_ib_tour_group_id'
                .trParams({'id': (room.scheduleId ?? room.id).toString()})
            : 'sc_ib_chat_id'.trParams({'id': room.id.toString()});
    final hasUnread = room.unreadCount > 0;

    final previewStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
          fontSize: 13,
        );

    final titleStyle = AppTextStyles.textTheme.titleSmall?.copyWith(
      fontWeight:
          hasUnread || room.isPinned ? FontWeight.w800 : FontWeight.w600,
      color: hasUnread ? AppColors.textPrimary : AppColors.textPrimary,
      fontSize: 15,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.button,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            _ChatAvatar(
              imageUrl: room.avatarUrl,
              name: title,
              isGroup: room.isGroup,
              size: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                      if (room.lastMessageAt != null)
                        Text(
                          _messageTime(room.lastMessageAt!),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: hasUnread
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: hasUnread
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (room.isGroup) ...[
                        const Icon(
                          Icons.groups_2_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          room.lastMessage?.trim().isNotEmpty == true
                              ? room.lastMessage!
                              : room.isGroup
                                  ? 'sc_ib_tour_group_desc'.tr
                                  : 'sc_ib_start_chat'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: previewStyle,
                        ),
                      ),
                      if (room.isPinned)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.push_pin_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (room.isMuted)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.notifications_off_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
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
    );
  }

  String _messageTime(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('dd/MM').format(local);
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.imageUrl,
    required this.name,
    required this.isGroup,
    required this.size,
  });

  final String? imageUrl;
  final String name;
  final bool isGroup;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: isGroup ? AppColors.brandGradient : null,
        color: isGroup ? null : AppColors.brandLight,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: imageUrl?.isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _avatarFallback(initial),
            )
          : _avatarFallback(initial),
    );
  }

  Widget _avatarFallback(String initial) {
    if (isGroup) {
      return const Icon(Icons.groups_2_rounded, color: Colors.white);
    }
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.brand,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
