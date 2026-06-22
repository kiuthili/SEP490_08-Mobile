import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/moment_card.dart';
import 'friend_management_panel.dart';

class SocialTab extends StatefulWidget {
  const SocialTab({super.key});

  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _social = Get.find<SocialController>();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _social.fetchFriends();
    _social.fetchPendingRequests();
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
            tooltip: 'Bản đồ Social',
            onPressed: () => Get.toNamed(AppRoutes.socialMap),
            icon: const Icon(Icons.map_outlined),
          ),
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

class _MomentsPanel extends StatefulWidget {
  final SocialController social;

  const _MomentsPanel({required this.social});

  @override
  State<_MomentsPanel> createState() => _MomentsPanelState();
}

class _MomentsPanelState extends State<_MomentsPanel> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.social.loadFeed(refresh: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        widget.social.loadMoreFeed();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => widget.social.loadFeed(refresh: true),
      child: Obx(() {
        if (widget.social.isMomentsLoading.value && widget.social.moments.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.all(16).copyWith(bottom: ShellLayout.bottomInset(context)),
            itemCount: 3,
            itemBuilder: (_, __) => const _SkeletonPlaceholder(),
          );
        }

        if (widget.social.moments.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 120),
              Center(child: Text('Chưa có moment nào. Hãy chia sẻ chuyến đi của bạn!')),
            ],
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16).copyWith(bottom: ShellLayout.bottomInset(context)),
          itemCount: widget.social.moments.length + (widget.social.isMomentsLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == widget.social.moments.length) {
              return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
            }
            final m = widget.social.moments[index];
            return MomentCard(
              moment: m,
              currentUserId: widget.social.currentUserId,
              onDelete: widget.social.deleteMoment,
              onLike: (isLike) => widget.social.reactMoment(m.id, isLike),
              onComment: () => Get.toNamed(AppRoutes.momentDetail, arguments: m),
            );
          },
        );
      }),
    );
  }
}

class _SkeletonPlaceholder extends StatefulWidget {
  const _SkeletonPlaceholder();

  @override
  State<_SkeletonPlaceholder> createState() => _SkeletonPlaceholderState();
}

class _SkeletonPlaceholderState extends State<_SkeletonPlaceholder> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _toggle();
  }

  void _toggle() async {
    if (!mounted) return;
    setState(() => _visible = !_visible);
    await Future.delayed(const Duration(milliseconds: 800));
    _toggle();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 800),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 250,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.separator),
        ),
      ),
    );
  }
}