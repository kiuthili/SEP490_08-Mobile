import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/shell_controller.dart';
import '../../models/social_models.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/shell_layout.dart';
import '../../widgets/comment_bottom_sheet.dart';
import '../../widgets/moment_card.dart';
import '../../utils/snackbar_helper.dart';
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
        leading: IconButton(
          tooltip: 'Add Moment',
          icon: const Icon(Icons.camera_alt_outlined),
          onPressed: () => Get.toNamed(AppRoutes.shareMoment),
        ),
        title: const Text('Social'),
        actions: [
          IconButton(
            tooltip: 'Social Map',
            onPressed: () => Get.find<ShellController>().changeTab(0),
            icon: const Icon(Icons.map_outlined),
          ),
          IconButton(
            tooltip: 'Messages',
            onPressed: () => Get.toNamed(AppRoutes.chatInbox),
            icon: const Icon(Icons.forum_outlined),
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Moments'),
          ],
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
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    widget.social.loadFeed(refresh: true);
    _pageController.addListener(() {
      if (_pageController.position.pixels >= _pageController.position.maxScrollExtent - 200) {
        widget.social.loadMoreFeed();
      }
    });
  }

  void _shareMoment(MomentModel moment) {
    final rooms = widget.social.chatRooms;
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                  final roomName = (room.name != null && room.name!.trim().isNotEmpty) ? room.name! : 'Conversation';
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.brandLight,
                      backgroundImage: (room.avatarUrl != null && room.avatarUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(room.avatarUrl!)
                          : null,
                      child: (room.avatarUrl == null || room.avatarUrl!.isEmpty)
                          ? const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.brand)
                          : null,
                    ),
                    title: Text(
                      roomName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      room.isGroup ? 'Tour Group' : 'Direct Chat',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                    trailing: const Icon(Icons.send_rounded, color: AppColors.brand, size: 20),
                    onTap: () async {
                      Get.back(); // Đóng bottom sheet
                      final shareText = '[MomentShare:${jsonEncode({
                        'id': moment.id,
                        'imageUrl': moment.imageUrl,
                        'caption': moment.caption ?? '',
                      })}]';
                      
                      await widget.social.sendChatMessage(room.id, shareText);
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
    _pageController.dispose();
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
              Center(child: Text('No moments yet. Share your journey!')),
            ],
          );
        }

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
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
              onComment: () {
                Get.bottomSheet(
                  CommentBottomSheet(moment: m),
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                );
              },
              onReport: (id) => _showReportDialog(context, 'Moment', id, widget.social),
              onShare: () => _shareMoment(m),
            );
          },
        );
      }),
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
              title: Text('Report ${contentType == 'Moment' ? 'moment' : 'comment'}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(labelText: 'Reason for reporting'),
                      items: const [
                        DropdownMenuItem(value: 'Spam', child: Text('Spam / Advertisement')),
                        DropdownMenuItem(value: 'Hate Speech', child: Text('Hate Speech')),
                        DropdownMenuItem(value: 'Harassment', child: Text('Harassment / Threats')),
                        DropdownMenuItem(value: 'Violence', child: Text('Violence / Gore')),
                        DropdownMenuItem(value: 'Other', child: Text('Other reason')),
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
                            details: detailsController.text.trim().isNotEmpty ? detailsController.text.trim() : null,
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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