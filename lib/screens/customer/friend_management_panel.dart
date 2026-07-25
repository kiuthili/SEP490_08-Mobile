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
    if (value.isNotEmpty && _view != _FriendView.search) {
      setState(() => _view = _FriendView.search);
    }
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
        title: Text('sc_fm_unfriend_title'.tr),
        content: Text('sc_fm_unfriend_desc'.trParams({'name': friend.fullName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('sc_fm_no'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('sc_fm_unfriend_title'.tr),
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
          SliverToBoxAdapter(child: _searchField()),
          SliverToBoxAdapter(child: _viewSelector()),
          Obx(_buildContent),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }


  Widget _viewSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Obx(
        () => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                _FriendView.friends,
                'sc_fm_tab_friends'.tr,
                Icons.people_outline_rounded,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                _FriendView.requests,
                social.pendingRequests.isEmpty
                    ? 'sc_fm_tab_requests'.tr
                    : 'sc_fm_tab_requests_count'.trParams({'count': social.pendingRequests.length.toString()}),
                Icons.person_add_alt_1_rounded,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                _FriendView.sent,
                social.sentRequests.isEmpty
                    ? 'sc_fm_tab_sent'.tr
                    : 'sc_fm_tab_sent_count'.trParams({'count': social.sentRequests.length.toString()}),
                Icons.outbox_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(_FriendView value, String label, IconData icon) {
    final isSelected = _view == value;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : AppColors.brand,
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _view = value);
      },
      selectedColor: AppColors.brand,
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.brand,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isSelected
              ? AppColors.brand
              : AppColors.brand.withValues(alpha: 0.2),
        ),
      ),
      showCheckmark: false,
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
          hintText: 'sc_fm_search_hint'.tr,
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
          return SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingWidget(message: 'sc_fm_load_friends'.tr),
          );
        }
        if (social.friends.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'sc_fm_empty_friends_title'.tr,
              subtitle: 'sc_fm_empty_friends_desc'.tr,
              icon: Icons.people_outline_rounded,
              onRetry: () => setState(() => _view = _FriendView.search),
              retryLabel: 'sc_fm_btn_find_friends'.tr,
            ),
          );
        }
        return _listSliver(social.friends.map(_friendCard).toList());
      case _FriendView.requests:
        if (social.isRequestsLoading.value && social.pendingRequests.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingWidget(message: 'sc_fm_load_requests'.tr),
          );
        }
        if (social.pendingRequests.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'sc_fm_empty_req_title'.tr,
              subtitle: 'sc_fm_empty_req_desc'.tr,
              icon: Icons.mark_email_read_outlined,
            ),
          );
        }
        return _listSliver(
          social.pendingRequests.map(_requestCard).toList(),
        );
      case _FriendView.sent:
        if (social.isRequestsLoading.value && social.sentRequests.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingWidget(message: 'sc_fm_load_sent'.tr),
          );
        }
        if (social.sentRequests.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'sc_fm_empty_sent_title'.tr,
              subtitle: 'sc_fm_empty_sent_desc'.tr,
              icon: Icons.outbox_rounded,
            ),
          );
        }
        return _listSliver(
          social.sentRequests.map(_sentCard).toList(),
        );
      case _FriendView.search:
        if (social.isSearchingUsers.value) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingWidget(message: 'sc_fm_load_search'.tr),
          );
        }
        if (_submittedQuery.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'sc_fm_search_title'.tr,
              subtitle: 'sc_fm_search_desc'.tr,
              icon: Icons.person_search_rounded,
            ),
          );
        }
        if (social.searchResults.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'sc_fm_no_user_title'.tr,
              subtitle: 'sc_fm_no_user_desc'.trParams({'query': _submittedQuery}),
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
      subtitle: 'sc_fm_friends_on_stayhub'.tr,
      avatarUrl: friend.avatarUrl,
      onTap: () => Get.toNamed(AppRoutes.userProfile, arguments: friend.userId),
      actions: [
        IconButton.filled(
          tooltip: 'sc_fm_btn_message'.tr,
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
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'unfriend',
              child: Row(
                children: [
                  Icon(
                    Icons.person_remove_outlined,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 10),
                  Text('sc_fm_unfriend_title'.tr),
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
        ? 'sc_fm_friend_request'.tr
        : 'sc_fm_sent_date'.trParams({'date': DateFormat('dd/MM/yyyy').format(request.createdAt!.toLocal())});
    return _PersonCard(
      name: request.senderName ?? 'sc_fm_user_id'.trParams({'id': request.senderId.toString()}),
      subtitle: date,
      avatarUrl: request.senderAvatarUrl,
      onTap: () =>
          Get.toNamed(AppRoutes.userProfile, arguments: request.senderId),
      actions: [
        FilledButton(
          style: _primaryButtonStyle(),
          onPressed:
              busy ? null : () => social.respondRequest(request.id, true),
          child: Text('sc_fm_btn_accept'.tr),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'sc_fm_btn_decline'.tr,
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
        social.processingUserIds.contains(request.receiverId);
    final date = request.createdAt == null
        ? 'sc_fm_req_sent'.tr
        : 'sc_fm_sent_date'.trParams({'date': DateFormat('dd/MM/yyyy').format(request.createdAt!.toLocal())});
    return _PersonCard(
      name: request.senderName ?? 'sc_fm_user_id'.trParams({'id': request.receiverId.toString()}),
      subtitle: date,
      avatarUrl: request.senderAvatarUrl,
      onTap: () =>
          Get.toNamed(AppRoutes.userProfile, arguments: request.receiverId),
      actions: [
        IconButton.outlined(
          tooltip: 'sc_fm_revoke_title'.tr,
          style: IconButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
          onPressed: busy
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text('sc_fm_revoke_title'.tr),
                      content: Text(
                          'sc_fm_revoke_desc'.trParams({'name': request.senderName ?? ''})),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text('sc_fm_no'.tr),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error),
                          child: Text('sc_fm_btn_revoke'.tr),
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
      subtitle: user.email ?? 'sc_fm_stayhub_user'.tr,
      avatarUrl: user.avatarUrl,
      onTap: () => Get.toNamed(AppRoutes.userProfile, arguments: user.id),
      actions: [
        if (isFriend)
          IconButton.filled(
            tooltip: 'sc_fm_btn_message'.tr,
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
            child: Text('sc_fm_btn_view_req'.tr),
          )
        else
          FilledButton.icon(
            style: _primaryButtonStyle(),
            onPressed:
                busy || sent ? null : () => social.sendFriendRequest(user.id),
            icon:
                Icon(sent ? Icons.schedule_rounded : Icons.person_add_rounded),
            label: Text(sent ? sent ? 'sc_fm_btn_sent'.tr : 'sc_fm_btn_add_friend'.tr : 'sc_fm_btn_add_friend'.tr),
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
                      name.isEmpty ? 'sc_fm_stayhub_user'.tr : name,
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
