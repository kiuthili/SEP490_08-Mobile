import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';

enum _FriendView { friends, requests, sent, search }

class FriendManagementPanel extends StatefulWidget {
  const FriendManagementPanel({
    super.key,
    required this.social,
    required this.searchController,
  });

  final SocialController social;
  final TextEditingController searchController;

  @override
  State<FriendManagementPanel> createState() => _FriendManagementPanelState();
}

class _FriendManagementPanelState extends State<FriendManagementPanel> {
  _FriendView _view = _FriendView.friends;
  Timer? _searchDebounce;
  String _submittedQuery = '';

  SocialController get social => widget.social;

  @override
  void initState() {
    super.initState();
    // Tự động tải danh sách bạn bè và lời mời kết bạn khi mở giao diện
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      social.fetchFriends(),
      social.fetchPendingRequests(),
      social.fetchSentRequests(),
    ]);
    if (_view == _FriendView.search && _submittedQuery.isNotEmpty) {
      await social.searchUsers(_submittedQuery);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _submitSearch(value);
    });
  }

  void _submitSearch(String value) {
    final query = value.trim();
    setState(() => _submittedQuery = query);
    social.searchUsers(query);
  }

  Future<void> _openChat(int userId, String name, String? avatarUrl) async {
    final room = await social.createDirectChat(userId);
    if (room == null) return;
    await Get.toNamed(
      AppRoutes.chatRoom,
      arguments: {
        'roomId': room.id,
        'title': room.name?.trim().isNotEmpty == true ? room.name : name,
        'isGroup': false,
        'avatarUrl': room.avatarUrl ?? avatarUrl,
      },
    );
  }

  Future<void> _confirmUnfriend(FriendModel friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy kết bạn'),
        content: Text('Bạn có chắc muốn hủy kết bạn với ${friend.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hủy kết bạn'),
          ),
        ],
      ),
    );
    if (confirmed == true) await social.unfriend(friend.friendshipId);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _summaryCard()),
          SliverToBoxAdapter(child: _viewSelector()),
          if (_view == _FriendView.search)
            SliverToBoxAdapter(child: _searchField()),
          Obx(_buildContent),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Obx(
      () => Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.homeHeroGradient,
          borderRadius: AppRadius.card,
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
                Icons.people_alt_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bạn bè trên StayHub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${social.friends.length} bạn bè • '
                    '${social.pendingRequests.length} lời mời mới',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Obx(
        () => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_FriendView>(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.brand
                    : AppColors.surfaceElevated,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.brand,
              ),
              iconColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.brand,
              ),
              side: WidgetStateProperty.all(
                const BorderSide(color: AppColors.brand),
              ),
            ),
            segments: [
              const ButtonSegment(
                value: _FriendView.friends,
                icon: Icon(Icons.people_outline_rounded),
                label: Text('Bạn bè'),
              ),
              ButtonSegment(
                value: _FriendView.requests,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  social.pendingRequests.isEmpty
                      ? 'Lời mời nhận'
                      : 'Lời mời nhận (${social.pendingRequests.length})',
                ),
              ),
              ButtonSegment(
                value: _FriendView.sent,
                icon: const Icon(Icons.outbox_rounded),
                label: Text(
                  social.sentRequests.isEmpty
                      ? 'Đã gửi'
                      : 'Đã gửi (${social.sentRequests.length})',
                ),
              ),
              const ButtonSegment(
                value: _FriendView.search,
                icon: Icon(Icons.search_rounded),
                label: Text('Tìm kiếm'),
              ),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _view = selection.first);
            },
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: widget.searchController,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: _submitSearch,
        decoration: InputDecoration(
          hintText: 'Tìm theo tên hoặc email...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: widget.searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    widget.searchController.clear();
                    _submitSearch('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_view) {
      case _FriendView.friends:
        if (social.isFriendsLoading.value && social.friends.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingWidget(message: 'Đang tải danh sách bạn bè...'),
          );
        }
        if (social.friends.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'Chưa có bạn bè',
              subtitle: 'Tìm người dùng và gửi lời mời để kết nối.',
              icon: Icons.people_outline_rounded,
              onRetry: () => setState(() => _view = _FriendView.search),
              retryLabel: 'Tìm bạn bè',
            ),
          );
        }
        return _listSliver(social.friends.map(_friendCard).toList());
      case _FriendView.requests:
        if (social.isRequestsLoading.value && social.pendingRequests.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingWidget(message: 'Đang tải lời mời kết bạn...'),
          );
        }
        if (social.pendingRequests.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'Không có lời mời mới',
              subtitle: 'Các lời mời kết bạn nhận được sẽ xuất hiện tại đây.',
              icon: Icons.mark_email_read_outlined,
            ),
          );
        }
        return _listSliver(
          social.pendingRequests.map(_requestCard).toList(),
        );
      case _FriendView.sent:
        if (social.isRequestsLoading.value && social.sentRequests.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingWidget(message: 'Đang tải yêu cầu đã gửi...'),
          );
        }
        if (social.sentRequests.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'Chưa gửi yêu cầu nào',
              subtitle: 'Các lời mời kết bạn đã gửi đi sẽ xuất hiện tại đây.',
              icon: Icons.outbox_rounded,
            ),
          );
        }
        return _listSliver(
          social.sentRequests.map(_sentCard).toList(),
        );
      case _FriendView.search:
        if (social.isSearchingUsers.value) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingWidget(message: 'Đang tìm người dùng...'),
          );
        }
        if (_submittedQuery.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'Tìm bạn bè trên StayHub',
              subtitle: 'Nhập tên hoặc email để bắt đầu tìm kiếm.',
              icon: Icons.person_search_rounded,
            ),
          );
        }
        if (social.searchResults.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'Không tìm thấy người dùng',
              subtitle: 'Không có kết quả phù hợp với “$_submittedQuery”.',
              icon: Icons.search_off_rounded,
            ),
          );
        }
        return _listSliver(
          social.searchResults.map(_searchResultCard).toList(),
        );
    }
  }

  Widget _listSliver(List<Widget> children) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      sliver: SliverList.separated(
        itemCount: children.length,
        itemBuilder: (_, index) => children[index],
        separatorBuilder: (_, __) => const SizedBox(height: 10),
      ),
    );
  }

  Widget _friendCard(FriendModel friend) {
    final busy = social.processingFriendshipIds.contains(friend.friendshipId) ||
        social.processingUserIds.contains(friend.userId);
    return _PersonCard(
      name: friend.fullName,
      subtitle: 'Bạn bè trên StayHub',
      avatarUrl: friend.avatarUrl,
      onTap: () => Get.toNamed(AppRoutes.userProfile, arguments: friend.userId),
      actions: [
        IconButton.filled(
          tooltip: 'Nhắn tin',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.brandLight,
            disabledForegroundColor: AppColors.textTertiary,
          ),
          onPressed: busy
              ? null
              : () => _openChat(
                    friend.userId,
                    friend.fullName,
                    friend.avatarUrl,
                  ),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
        ),
        PopupMenuButton<String>(
          enabled: !busy,
          onSelected: (value) {
            if (value == 'unfriend') _confirmUnfriend(friend);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'unfriend',
              child: Row(
                children: [
                  Icon(
                    Icons.person_remove_outlined,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 10),
                  Text('Hủy kết bạn'),
                ],
              ),
            ),
          ],
        ),
      ],
      busy: busy,
    );
  }

  Widget _requestCard(FriendRequestModel request) {
    final busy = social.processingRequestIds.contains(request.id);
    final date = request.createdAt == null
        ? 'Lời mời kết bạn'
        : 'Gửi ngày ${DateFormat('dd/MM/yyyy').format(request.createdAt!.toLocal())}';
    return _PersonCard(
      name: request.senderName ?? 'Người dùng #${request.senderId}',
      subtitle: date,
      avatarUrl: request.senderAvatarUrl,
      onTap: () =>
          Get.toNamed(AppRoutes.userProfile, arguments: request.senderId),
      actions: [
        FilledButton(
          style: _primaryButtonStyle(),
          onPressed:
              busy ? null : () => social.respondRequest(request.id, true),
          child: const Text('Chấp nhận'),
        ),
        IconButton.outlined(
          tooltip: 'Từ chối',
          style: IconButton.styleFrom(
            foregroundColor: AppColors.brand,
            side: const BorderSide(color: AppColors.brand),
          ),
          onPressed:
              busy ? null : () => social.respondRequest(request.id, false),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
      busy: busy,
    );
  }

  Widget _sentCard(FriendRequestModel request) {
    final busy = social.processingFriendshipIds.contains(request.id) ||
        social.processingUserIds.contains(request.senderId);
    final date = request.createdAt == null
        ? 'Đã gửi lời mời'
        : 'Gửi ngày ${DateFormat('dd/MM/yyyy').format(request.createdAt!.toLocal())}';
    return _PersonCard(
      name: request.senderName ?? 'Người dùng #${request.senderId}',
      subtitle: date,
      avatarUrl: request.senderAvatarUrl,
      onTap: () =>
          Get.toNamed(AppRoutes.userProfile, arguments: request.senderId),
      actions: [
        IconButton.outlined(
          tooltip: 'Thu hồi yêu cầu',
          style: IconButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
          onPressed: busy ? null : () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Thu hồi yêu cầu'),
                content: Text('Bạn có chắc muốn thu hồi yêu cầu kết bạn gửi đến ${request.senderName}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Không'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                    child: const Text('Thu hồi'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await social.unfriend(request.id);
              await social.fetchSentRequests();
            }
          },
          icon: const Icon(Icons.person_remove_outlined),
        ),
      ],
      busy: busy,
    );
  }

  Widget _searchResultCard(UserSearchModel user) {
    final isFriend = social.isFriend(user.id);
    final hasIncoming = social.hasIncomingRequest(user.id);
    final sent = social.sentRequestUserIds.contains(user.id);
    final busy = social.processingUserIds.contains(user.id);
    return _PersonCard(
      name: user.fullName,
      subtitle: user.email ?? 'Người dùng StayHub',
      avatarUrl: user.avatarUrl,
      onTap: () => Get.toNamed(AppRoutes.userProfile, arguments: user.id),
      actions: [
        if (isFriend)
          IconButton.filled(
            tooltip: 'Nhắn tin',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.brandLight,
              disabledForegroundColor: AppColors.textTertiary,
            ),
            onPressed: busy
                ? null
                : () => _openChat(user.id, user.fullName, user.avatarUrl),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          )
        else if (hasIncoming)
          OutlinedButton(
            style: _secondaryButtonStyle(),
            onPressed: () => setState(() => _view = _FriendView.requests),
            child: const Text('Xem lời mời'),
          )
        else
          FilledButton.icon(
            style: _primaryButtonStyle(),
            onPressed:
                busy || sent ? null : () => social.sendFriendRequest(user.id),
            icon:
                Icon(sent ? Icons.schedule_rounded : Icons.person_add_rounded),
            label: Text(sent ? 'Đã gửi' : 'Kết bạn'),
          ),
      ],
      busy: busy,
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.35),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
    );
  }

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.brand,
      side: const BorderSide(color: AppColors.brand),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
    required this.onTap,
    required this.actions,
    required this.busy,
  });

  final String name;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onTap;
  final List<Widget> actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.card,
          ),
          child: Row(
            children: [
              _UserAvatar(name: name, imageUrl: avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Người dùng StayHub' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name, required this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 50,
      height: 50,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.brandLight,
        shape: BoxShape.circle,
      ),
      child: imageUrl?.isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(child: Text(initial)),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}
