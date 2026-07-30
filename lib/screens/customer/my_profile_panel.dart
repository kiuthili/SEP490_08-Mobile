import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/user_model.dart';
import '../../models/social_models.dart';
import '../../routes/app_routes.dart';
import '../../services/social_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/comment_bottom_sheet.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/snackbar_helper.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class MyProfilePanel extends StatefulWidget {
  const MyProfilePanel({super.key});

  @override
  State<MyProfilePanel> createState() => _MyProfilePanelState();
}

class _MyProfilePanelState extends State<MyProfilePanel>
    with SingleTickerProviderStateMixin {
  final _auth = Get.find<AuthController>();
  final _socialService = Get.find<SocialService>();
  final _socialController = Get.find<SocialController>();

  var _loading = true;
  List<MomentModel> _myMoments = [];

  @override
  void initState() {
    super.initState();
    _loadMoments();
  }

  Future<void> _loadMoments({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final user = _auth.currentUser.value;
      if (user != null) {
        _myMoments = await _socialService.getUserMoments(user.id);
      }
    } catch (_) {
      SnackbarHelper.error('sc_mp_err_load_moments'.tr);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = _auth.currentUser.value;
      if (user == null) {
        return Center(child: Text('sc_mp_not_logged_in'.tr));
      }
      return RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _loadMoments,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(user)),
            SliverToBoxAdapter(child: _buildActionButtons()),
            const SliverToBoxAdapter(
              child: Divider(
                  height: 0.5, thickness: 0.5, color: AppColors.separator),
            ),
            if (_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(60),
                  child: LoadingWidget(message: 'sc_mp_loading_moments'.tr),
                ),
              )
            else if (_myMoments.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _buildEmpty())
            else
              _buildPhotoGrid(user),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      );
    });
  }

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader(UserModel user) {
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
              // Avatar với gradient ring tone hệ thống
              _buildAvatarRing(user, initial),
              const SizedBox(width: 24),
              // Stats bên phải trong card nhỏ
              Expanded(
                child: Obx(
                  () => Container(
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
                        _buildStat(
                            _myMoments.length.toString(), 'sc_mp_posts'.tr),
                        Container(
                          width: 1,
                          height: 28,
                          color: AppColors.separator,
                        ),
                        _buildStat(
                          _socialController.friends.length.toString(),
                          'sc_mp_friends'.tr,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user.fullName.isEmpty ? 'sc_mp_stayhub_user'.tr : user.fullName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (user.email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarRing(UserModel user, String initial) {
    return Stack(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
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
            backgroundImage: user.avatarUrl?.isNotEmpty == true &&
                    !user.avatarUrl!.toLowerCase().endsWith('.svg')
                ? CachedNetworkImageProvider(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null ||
                    user.avatarUrl!.isEmpty ||
                    user.avatarUrl!.toLowerCase().endsWith('.svg')
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
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // ACTION BUTTONS
  // ─────────────────────────────────────────
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.profile),
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.separator, width: 1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                alignment: Alignment.center,
                child: Text(
                  'sc_mp_edit_profile'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.shareMoment),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.separator, width: 1),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add_photo_alternate_outlined,
                  size: 18, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // TAB ROW
  // ─────────────────────────────────────────
  // ─────────────────────────────────────────
  // PHOTO GRID 3 CỘT
  // ─────────────────────────────────────────
  Widget _buildPhotoGrid(UserModel user) {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemCount: _myMoments.length,
      itemBuilder: (context, index) {
        final moment = _myMoments[index];
        return GestureDetector(
          onTap: () => _openFeedAtIndex(context, index),
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

  // ─────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────
  Widget _buildEmpty() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textPrimary, width: 2),
          ),
          child: const Icon(
            Icons.camera_alt_outlined,
            size: 32,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'sc_mp_empty_posts_title'.tr,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'sc_mp_empty_posts_desc'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => Get.toNamed(AppRoutes.shareMoment),
          child: Text(
            'sc_mp_share_first'.tr,
            style: TextStyle(
              color: AppColors.brand,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _openFeedAtIndex(BuildContext context, int index) async {
    final user = _auth.currentUser.value;
    if (user == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _UserMomentsFeedScreen(
          moments: _myMoments,
          initialIndex: index,
          currentUser: user,
          socialController: _socialController,
        ),
      ),
    );
    _loadMoments(silent: true);
  }
}

// ─────────────────────────────────────────────────
// Full-screen vertical feed — tap grid → lướt dọc
// ─────────────────────────────────────────────────
class _UserMomentsFeedScreen extends StatefulWidget {
  const _UserMomentsFeedScreen({
    required this.moments,
    required this.initialIndex,
    required this.currentUser,
    required this.socialController,
  });
  final List<MomentModel> moments;
  final int initialIndex;
  final UserModel currentUser;
  final SocialController socialController;

  @override
  State<_UserMomentsFeedScreen> createState() => _UserMomentsFeedScreenState();
}

class _UserMomentsFeedScreenState extends State<_UserMomentsFeedScreen> {
  late List<MomentModel> _moments;

  @override
  void initState() {
    super.initState();
    // Bắt đầu từ bài được chọn để khi cuộn ListView sẽ liên tiếp các bài cũ hơn
    _moments = widget.moments.sublist(widget.initialIndex);
    _loadFullMoments();
  }

  Future<void> _loadFullMoments() async {
    for (int i = 0; i < _moments.length; i++) {
      try {
        final fullData =
            await widget.socialController.getMomentById(_moments[i].id);
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
          'sc_mp_posts'.tr,
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
          return _FeedItem(
            moment: moment,
            currentUser: widget.currentUser,
            onLike: () => _toggleLike(index),
            onComment: () {
              Get.toNamed(AppRoutes.momentDetail, arguments: moment);
            },
            onDelete: () {
              widget.socialController.deleteMoment(moment.id);
              setState(() {
                _moments.removeAt(index);
              });
              Get.back();
            },
          );
        },
      ),
    );
  }
}

class _FeedItem extends StatelessWidget {
  const _FeedItem({
    required this.moment,
    required this.currentUser,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
  });

  final MomentModel moment;
  final UserModel currentUser;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.brandLight,
                  backgroundImage: currentUser.avatarUrl?.isNotEmpty == true &&
                          !currentUser.avatarUrl!.toLowerCase().endsWith('.svg')
                      ? CachedNetworkImageProvider(currentUser.avatarUrl!)
                      : null,
                  child: currentUser.avatarUrl == null ||
                          currentUser.avatarUrl!.isEmpty ||
                          currentUser.avatarUrl!.toLowerCase().endsWith('.svg')
                      ? Text(
                          (currentUser.fullName.isNotEmpty == true
                                  ? currentUser.fullName[0]
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
                    currentUser.fullName.isEmpty
                        ? 'sc_mp_stayhub_user'.tr
                        : currentUser.fullName,
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
                if (moment.userId == currentUser.id)
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.black87),
                    onPressed: () => _showOptions(context),
                  ),
              ],
            ),
          ),

          // ── Image ──
          GestureDetector(
            onTap:
                onComment, // Re-use onComment to navigate to MomentDetailScreen
            child: Hero(
              tag: 'moment_image_${moment.id}',
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: CachedNetworkImage(
                  imageUrl: moment.imageUrl,
                  width: double.infinity,
                  fit: BoxFit
                      .contain, // Fit contain to avoid cropping vertical images
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

          // ── Caption ──
          if (moment.caption?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                moment.caption!,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),

          // ── Actions ──
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

          // ── Likes Count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              Get.locale?.languageCode == 'vi'
                  ? '${moment.reactionCount} lượt thích'
                  : '${moment.reactionCount} likes',
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),

          // ── Time & Comments ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: GestureDetector(
              onTap: onComment,
              child: Text(
                moment.comments.isNotEmpty
                    ? (Get.locale?.languageCode == 'vi'
                        ? 'Xem tất cả ${moment.comments.length} bình luận'
                        : 'View all ${moment.comments.length} comments')
                    : (Get.locale?.languageCode == 'vi'
                        ? 'Thêm bình luận...'
                        : 'Add a comment...'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Text(
              DateFormat('HH:mm - dd/MM/yyyy')
                  .format(moment.createdAt.toLocal()),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('sc_mp_delete_post'.tr,
                  style: TextStyle(color: AppColors.error)),
              onTap: onDelete,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
