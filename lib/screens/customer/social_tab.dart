import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
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
import '../../widgets/safe_avatar.dart';
import '../../utils/snackbar_helper.dart';
import 'friend_management_panel.dart';
import 'my_profile_panel.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

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

  bool _isFeedLight = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _social.fetchFriends();
    _social.fetchPendingRequests();
    _social.fetchChatRooms();
    Get.find<OrderController>().fetchEligibleSchedules();
  }

  Color get _headerColor {
    if (_tabController.index != 0) return Colors.black87;
    return _isFeedLight ? Colors.black87 : Colors.white;
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _headerColor),
        titleTextStyle: TextStyle(
          color: _headerColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          tooltip: 'sc_tooltip_add_moment'.tr,
          icon: const Icon(Icons.camera_alt_outlined),
          onPressed: () => Get.toNamed(AppRoutes.shareMoment),
        ),
        title: Text('sc_title'.tr),
        actions: [
          IconButton(
            tooltip: 'sc_tooltip_messages'.tr,
            onPressed: () => Get.toNamed(AppRoutes.chatInbox),
            icon: const Icon(Icons.forum_outlined),
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _headerColor,
          indicatorWeight: 3,
          labelColor: _headerColor,
          unselectedLabelColor: _headerColor.withValues(alpha: 0.6),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: [
            Tab(text: 'sc_tab_feed'.tr),
            Tab(text: 'sc_tab_friends'.tr),
            Tab(text: 'sc_tab_profile'.tr),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MomentsPanel(
            social: _social,
            onThemeChanged: (isLight) {
              if (_isFeedLight != isLight) {
                setState(() => _isFeedLight = isLight);
              }
            },
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 48,
            ),
            child: FriendManagementPanel(
              social: _social,
              searchController: _searchController,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 48,
            ),
            child: const MyProfilePanel(),
          ),
        ],
      ),
    );
  }
}

class _MomentsPanel extends StatefulWidget {
  final SocialController social;
  final Function(bool isLight) onThemeChanged;

  const _MomentsPanel({required this.social, required this.onThemeChanged});

  @override
  State<_MomentsPanel> createState() => _MomentsPanelState();
}

class _MomentsPanelState extends State<_MomentsPanel> {
  final _pageController = PageController();
  int _currentFeedIndex = 0;
  final Map<int, bool> _isFeedLightMap = {};

  @override
  void initState() {
    super.initState();
    widget.social.loadFeed(refresh: true);
    _pageController.addListener(() {
      if (_pageController.position.pixels >=
          _pageController.position.maxScrollExtent - 200) {
        widget.social.loadMoreFeed();
      }
      int newIndex = _pageController.page?.round() ?? 0;
      if (newIndex != _currentFeedIndex) {
        _currentFeedIndex = newIndex;
        _checkImageColor(newIndex);
      }
    });

    ever(widget.social.moments, (_) {
      if (widget.social.moments.isNotEmpty &&
          !_isFeedLightMap.containsKey(0) &&
          _currentFeedIndex == 0) {
        _checkImageColor(0);
      }
    });
  }

  Future<void> _checkImageColor(int index) async {
    if (index >= widget.social.moments.length) return;

    if (_isFeedLightMap.containsKey(index)) {
      widget.onThemeChanged(_isFeedLightMap[index]!);
      return;
    }

    final imageUrl = widget.social.moments[index].imageUrl;
    if (imageUrl.isEmpty) return;

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
      );
      final dominantColor = palette.dominantColor?.color ??
          palette.mutedColor?.color ??
          Colors.black;
      final isLight = dominantColor.computeLuminance() > 0.5;

      if (mounted) {
        _isFeedLightMap[index] = isLight;
        if (_currentFeedIndex == index) {
          widget.onThemeChanged(isLight);
        }
      }
    } catch (e) {
      // ignore
    }
  }

  void _shareMoment(MomentModel moment) {
    final rooms = widget.social.chatRooms;
    if (rooms.isEmpty) {
      SnackbarHelper.error('sc_share_no_conv'.tr);
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
                Text(
                  'sc_share_send_to'.tr,
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
            SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final roomName =
                      (room.name != null && room.name!.trim().isNotEmpty)
                          ? room.name!
                          : 'sc_share_conversation'.tr;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.brandLight,
                      backgroundImage: safeAvatarImageProvider(room.avatarUrl),
                      child: safeAvatarImageProvider(room.avatarUrl) == null
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
                      room.isGroup
                          ? 'sc_share_tour_group'.tr
                          : 'sc_share_direct_chat'.tr,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                    trailing: const Icon(Icons.send_rounded,
                        color: AppColors.brand, size: 20),
                    onTap: () async {
                      Get.back(); // Đóng bottom sheet
                      final shareText = '[MomentShare:${jsonEncode({
                            'id': moment.id,
                            'imageUrl': moment.imageUrl,
                            'caption': moment.caption ?? '',
                          })}]';

                      await widget.social.sendChatMessage(room.id, shareText);
                      SnackbarHelper.success('sc_share_success'.tr);
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
        if (widget.social.isMomentsLoading.value &&
            widget.social.moments.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.all(16)
                .copyWith(bottom: ShellLayout.bottomInset(context)),
            itemCount: 3,
            itemBuilder: (_, __) => const _SkeletonPlaceholder(),
          );
        }

        if (widget.social.moments.isEmpty) {
          return ListView(
            children: [
              SizedBox(height: 120),
              Center(child: Text('sc_moment_empty'.tr)),
            ],
          );
        }

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: widget.social.moments.length +
              (widget.social.isMomentsLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == widget.social.moments.length) {
              return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()));
            }
            final m = widget.social.moments[index];
            return MomentCard(
              moment: m,
              currentUserId: widget.social.currentUserId,
              onDelete: widget.social.deleteMoment,
              onLike: (isLike) => widget.social.reactMoment(m.id, isLike),
              onComment: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => CommentBottomSheet(moment: m),
                );
              },
              onReport: (id) =>
                  _showReportDialog(context, 'Moment', id, widget.social),
              onShare: () => _shareMoment(m),
            );
          },
        );
      }),
    );
  }

  void _showReportDialog(BuildContext context, String contentType, int targetId,
      SocialController social) {
    String selectedReason = 'Spam';
    final detailsController = TextEditingController();
    var isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${contentType == 'Moment' ? 'sc_report_moment'.tr : 'sc_report_comment'.tr}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: InputDecoration(
                        labelText: 'sc_report_reason'.tr,
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'Spam', child: Text('sc_report_spam'.tr)),
                        DropdownMenuItem(
                            value: 'sc_report_hate'.tr,
                            child: Text('sc_report_hate'.tr)),
                        DropdownMenuItem(
                            value: 'Harassment',
                            child: Text('sc_report_harassment'.tr)),
                        DropdownMenuItem(
                            value: 'Violence',
                            child: Text('sc_report_violence'.tr)),
                        DropdownMenuItem(
                            value: 'Other', child: Text('sc_report_other'.tr)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedReason = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: detailsController,
                      decoration: InputDecoration(
                        labelText: 'sc_report_details'.tr,
                        hintText: 'sc_report_details_hint'.tr,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isSending ? null : () => Navigator.pop(context),
                            child: Text('sc_report_cancel'.tr),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: isSending
                                ? null
                                : () async {
                                    setSheetState(() => isSending = true);
                                    final ok = await social.reportContent(
                                      contentType: contentType,
                                      targetId: targetId,
                                      reason: selectedReason,
                                      details: detailsController.text
                                              .trim()
                                              .isNotEmpty
                                          ? detailsController.text.trim()
                                          : null,
                                    );
                                    setSheetState(() => isSending = false);
                                    if (ok) {
                                      Navigator.pop(context);
                                    }
                                  },
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand),
                            child: isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text('sc_report_submit'.tr),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
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
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.separator),
        ),
      ),
    );
  }
}
