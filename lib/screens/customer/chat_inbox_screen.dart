import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';

enum _InboxFilter { all, direct, group }

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _social = Get.find<SocialController>();
  final _searchController = TextEditingController();
  _InboxFilter _filter = _InboxFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _social.fetchChatRooms();
    });
  }

  @override
  void dispose() {
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
    if (_social.friends.isEmpty) {
      await _social.fetchFriends();
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tin nhắn mới',
                      style: AppTextStyles.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chọn một người bạn để bắt đầu trò chuyện',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Obx(() {
                  if (_social.isLoading.value && _social.friends.isEmpty) {
                    return const LoadingWidget();
                  }
                  if (_social.friends.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'Chưa có bạn bè',
                      subtitle: 'Kết bạn trước để gửi tin nhắn riêng',
                      icon: Icons.person_add_alt_1_rounded,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _social.friends.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final friend = _social.friends[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        tileColor: AppColors.surfaceGrouped,
                        leading: _ChatAvatar(
                          imageUrl: friend.avatarUrl,
                          name: friend.fullName,
                          isGroup: false,
                          size: 46,
                        ),
                        title: Text(
                          friend.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(friend.email ?? 'Bạn bè trên StayHub'),
                        trailing: const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.brand,
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Get.toNamed(
                            AppRoutes.chatRoom,
                            arguments: friend.userId,
                          )?.then((_) => _social.fetchChatRooms());
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Tin nhắn',
      actions: [
        IconButton(
          tooltip: 'Tin nhắn mới',
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
            return const LoadingWidget(message: 'Đang tải cuộc trò chuyện...');
          }
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _InboxHeader(
                  directCount: _social.directChats.length,
                  groupCount: _social.tourGroupChats.length,
                  unreadCount: _social.unreadChatCount,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Tìm cuộc trò chuyện...',
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
                child: SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterChip(
                        label: 'Tất cả',
                        selected: _filter == _InboxFilter.all,
                        onTap: () => setState(() => _filter = _InboxFilter.all),
                      ),
                      _FilterChip(
                        label: 'Tin nhắn riêng',
                        icon: Icons.person_outline_rounded,
                        selected: _filter == _InboxFilter.direct,
                        onTap: () =>
                            setState(() => _filter = _InboxFilter.direct),
                      ),
                      _FilterChip(
                        label: 'Nhóm tour',
                        icon: Icons.groups_2_outlined,
                        selected: _filter == _InboxFilter.group,
                        onTap: () =>
                            setState(() => _filter = _InboxFilter.group),
                      ),
                    ],
                  ),
                ),
              ),
              if (rooms.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    title: _query.isNotEmpty
                        ? 'Không tìm thấy cuộc trò chuyện'
                        : _filter == _InboxFilter.group
                            ? 'Chưa có nhóm tour'
                            : 'Chưa có tin nhắn',
                    subtitle: _filter == _InboxFilter.group
                        ? 'Sau khi thanh toán tour, nhóm chat lịch trình sẽ xuất hiện tại đây.'
                        : 'Nhấn biểu tượng soạn tin để trò chuyện với bạn bè.',
                    icon: _filter == _InboxFilter.group
                        ? Icons.groups_2_outlined
                        : Icons.forum_outlined,
                    onRetry: _social.fetchChatRooms,
                    retryLabel: 'Làm mới',
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

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({
    required this.directCount,
    required this.groupCount,
    required this.unreadCount,
  });

  final int directCount;
  final int groupCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071A3D), Color(0xFF0068E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kết nối mọi hành trình',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  unreadCount > 0
                      ? '$directCount chat riêng • $groupCount nhóm tour • $unreadCount chưa đọc'
                      : '$directCount chat riêng • $groupCount nhóm tour',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFFFD37A),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: icon == null
            ? null
            : Icon(
                icon,
                size: 17,
                color: selected ? AppColors.brand : AppColors.textSecondary,
              ),
        label: Text(label),
        onSelected: (_) => onTap(),
        selectedColor: AppColors.brandLight,
        backgroundColor: AppColors.surfaceElevated,
        side: BorderSide(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.2)
              : AppColors.border,
        ),
        labelStyle: TextStyle(
          color: selected ? AppColors.brand : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
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
            ? 'Nhóm tour #${room.scheduleId ?? room.id}'
            : 'Cuộc trò chuyện #${room.id}';
    final hasUnread = room.unreadCount > 0;
    final previewStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: hasUnread ? AppColors.textPrimary : null,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
        );
    final titleStyle = AppTextStyles.textTheme.titleSmall?.copyWith(
      fontWeight: hasUnread || room.isPinned ? FontWeight.w800 : FontWeight.w700,
      color: hasUnread ? AppColors.textPrimary : null,
    );
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _ChatAvatar(
                imageUrl: room.avatarUrl,
                name: title,
                isGroup: room.isGroup,
                size: 54,
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
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: hasUnread
                                      ? AppColors.brand
                                      : AppColors.textTertiary,
                                  fontWeight:
                                      hasUnread ? FontWeight.w700 : FontWeight.w400,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (room.isGroup) ...[
                          const Icon(
                            Icons.groups_2_outlined,
                            size: 15,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            room.lastMessage?.trim().isNotEmpty == true
                                ? room.lastMessage!
                                : room.isGroup
                                    ? 'Nhóm trò chuyện theo lịch tour'
                                    : 'Bắt đầu cuộc trò chuyện',
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
                              size: 15,
                              color: AppColors.brand,
                            ),
                          ),
                        if (room.isMuted)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.notifications_off_outlined,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasUnread)
                _UnreadBadge(count: room.unreadCount, compact: false)
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({
    required this.count,
    this.compact = true,
  });

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    final minWidth = compact ? 18.0 : 22.0;
    final height = compact ? 18.0 : 24.0;
    return Container(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: height),
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
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
