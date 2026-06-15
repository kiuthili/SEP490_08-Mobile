import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/ios_grouped.dart';
import 'friend_management_panel.dart';

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
          FriendManagementPanel(
            social: _social,
            searchController: _searchController,
          ),
          _MomentsPanel(social: _social),
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
