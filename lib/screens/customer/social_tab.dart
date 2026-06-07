import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/ios_grouped.dart';

class SocialTab extends StatefulWidget {
  const SocialTab({super.key});

  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _social = Get.find<SocialController>();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _social.fetchFriends();
    _social.fetchPendingRequests();
    _social.fetchMoments();
    _social.fetchChatRooms();
    Get.find<OrderController>().fetchEligibleSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Xã hội'),
        actions: [
          IconButton(
            tooltip: 'Tin nhắn',
            onPressed: () => Get.toNamed(AppRoutes.chatInbox),
            icon: const Icon(Icons.forum_outlined),
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Bạn bè'),
            Tab(text: 'Moments'),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          onPressed: () => Get.toNamed(AppRoutes.shareMoment),
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Moment'),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FriendsPanel(
            social: _social,
            searchController: _searchController,
          ),
          _MomentsPanel(social: _social),
        ],
      ),
    );
  }
}

class _FriendsPanel extends StatelessWidget {
  final SocialController social;
  final TextEditingController searchController;

  const _FriendsPanel({
    required this.social,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await social.fetchFriends();
        await social.fetchPendingRequests();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Tìm người dùng theo email hoặc tên...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.person_search),
                onPressed: () => social.searchUsers(searchController.text),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: social.searchUsers,
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (social.searchResults.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kết quả tìm kiếm',
                      style: Theme.of(context).textTheme.titleSmall),
                  ...social.searchResults.map(
                    (u) => ListTile(
                      leading: CircleAvatar(
                        child: Text(u.fullName.isNotEmpty
                            ? u.fullName[0].toUpperCase()
                            : '?'),
                      ),
                      title: Text(u.fullName),
                      subtitle: Text(u.email ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: () => social.sendFriendRequest(u.id),
                      ),
                      onTap: () => Get.toNamed(
                        AppRoutes.userProfile,
                        arguments: u.id,
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
          Obx(() {
            if (social.pendingRequests.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lời mời kết bạn',
                      style: Theme.of(context).textTheme.titleSmall),
                  ...social.pendingRequests.map(
                    (r) => ListTile(
                      title: Text(r.senderName ?? 'Người dùng #${r.senderId}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => social.respondRequest(r.id, true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => social.respondRequest(r.id, false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
          Text('Danh sách bạn bè',
              style: Theme.of(context).textTheme.titleSmall),
          Obx(() {
            if (social.friends.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Chưa có bạn bè')),
              );
            }
            return Column(
              children: social.friends.map((f) {
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(f.fullName.isNotEmpty
                        ? f.fullName[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(f.fullName),
                  subtitle: Text(f.email ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => Get.toNamed(
                      AppRoutes.chatRoom,
                      arguments: f.userId,
                    ),
                  ),
                  onTap: () => Get.toNamed(
                    AppRoutes.userProfile,
                    arguments: f.userId,
                  ),
                  onLongPress: () => _confirmUnfriend(context, f),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  void _confirmUnfriend(BuildContext context, dynamic f) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy kết bạn'),
        content: Text('Hủy kết bạn với ${f.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () {
              social.unfriend(f.friendshipId);
              Navigator.pop(ctx);
            },
            child: const Text('Hủy kết bạn'),
          ),
        ],
      ),
    );
  }
}

class _MomentsPanel extends StatelessWidget {
  final SocialController social;

  const _MomentsPanel({required this.social});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: social.fetchMoments,
      child: Obx(() {
        if (social.isLoading.value && social.moments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (social.moments.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 120),
              Center(child: Text('Chưa có moment')),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16).copyWith(
            bottom: ShellLayout.bottomInset(context),
          ),
          itemCount: social.moments.length,
          itemBuilder: (context, index) {
            final m = social.moments[index];
            return IosSurfaceCard(
              margin: const EdgeInsets.only(bottom: 12),
              onTap: () => Get.toNamed(
                AppRoutes.momentDetail,
                arguments: m.id,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(m.userName?.isNotEmpty == true
                          ? m.userName![0].toUpperCase()
                          : '?'),
                    ),
                    title: Text(m.userName ?? 'Người dùng'),
                  ),
                  if (m.content != null) Text(m.content!),
                  if (m.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Image.network(m.imageUrl!, fit: BoxFit.cover),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          m.hasReacted ? Icons.favorite : Icons.favorite_border,
                        ),
                        onPressed: () => social.reactMoment(m.id),
                      ),
                      Text('${m.reactionCount}'),
                      IconButton(
                        icon: const Icon(Icons.comment_outlined),
                        onPressed: () => _showCommentDialog(context, m.id),
                      ),
                      Text('${m.commentCount}'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  void _showCommentDialog(BuildContext context, int momentId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bình luận'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nhập bình luận...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              social.commentMoment(momentId, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }
}
