import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/shell_controller.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/shell_layout.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/ai_floating_assistant.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final AuthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<AuthController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadProfile();
    });
  }

  String _genderLabel(String? value) {
    switch (value?.toLowerCase()) {
      case 'male':
        return 'Nam';
      case 'female':
        return 'Nữ';
      case 'other':
        return 'Khác';
      default:
        return 'Chưa cập nhật';
    }
  }

  String _valueOrFallback(String? value) {
    return value?.trim().isNotEmpty == true ? value!.trim() : 'Chưa cập nhật';
  }

  Future<void> _openEditProfile() async {
    await Get.toNamed(AppRoutes.editProfile);
    await _controller.loadProfile();
  }

  Widget _buildProfileOverview(UserModel user) {
    final hasAvatar = user.avatarUrl?.isNotEmpty == true;
    final initial = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()[0].toUpperCase()
        : '?';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            decoration: const BoxDecoration(
              gradient: AppColors.homeHeroGradient,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.brandLight,
                    backgroundImage: hasAvatar
                        ? CachedNetworkImageProvider(user.avatarUrl!)
                        : null,
                    child: !hasAvatar
                        ? Text(
                            initial,
                            style: AppTextStyles.textTheme.headlineMedium
                                ?.copyWith(
                                  color: AppColors.brandDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 17,
                        color: Color(0xFF8FE5B0),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Tài khoản đã xác minh',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (user.roles.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: user.roles
                        .map(
                          (role) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              role,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.brand,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Thông tin cá nhân',
                    style: AppTextStyles.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openEditProfile,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Chỉnh sửa'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          _profileInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Họ và tên',
            value: user.fullName,
          ),
          _profileInfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: user.email,
          ),
          _profileInfoRow(
            icon: Icons.phone_outlined,
            label: 'Số điện thoại',
            value: _valueOrFallback(user.phoneNumber),
          ),
          _profileInfoRow(
            icon: Icons.people_outline_rounded,
            label: 'Giới tính',
            value: _genderLabel(user.gender),
          ),
          _profileInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Ngày sinh',
            value: _valueOrFallback(user.dateOfBirth),
          ),
          _profileInfoRow(
            icon: Icons.login_rounded,
            label: 'Phương thức đăng nhập',
            value: _valueOrFallback(user.provider),
            showDivider: false,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _profileInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool showDivider = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.brand, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            const Divider(height: 1, indent: 46, color: AppColors.separator),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Làm mới hồ sơ',
              onPressed:
                  _controller.isLoading.value ? null : _controller.loadProfile,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final user = _controller.currentUser.value;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _controller.loadProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0).copyWith(
              bottom: ShellLayout.bottomInset(context),
            ),
            children: [
              _buildProfileOverview(user),
              IosGroupedSection(
                header: 'Tài khoản',
                margin: const EdgeInsets.only(top: 18),
                children: [
                  IosMenuTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Đổi mật khẩu',
                    onTap: () => Get.toNamed(AppRoutes.changePassword),
                  ),
                  IosMenuTile(
                    icon: Icons.notifications_outlined,
                    title: 'Thông báo',
                    onTap: () => Get.toNamed(AppRoutes.notifications),
                  ),
                ],
              ),
              IosGroupedSection(
                header: 'Đặt tour & ưu đãi',
                margin: const EdgeInsets.only(top: 8),
                children: [
                  IosMenuTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Đặt tour của tôi',
                    onTap: () => Get.find<ShellController>().openBookingsTab(),
                  ),
                  IosMenuTile(
                    icon: Icons.favorite_border_rounded,
                    title: 'Wishlist',
                    onTap: () => Get.toNamed(AppRoutes.wishlist),
                  ),
                  IosMenuTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Đánh giá của tôi',
                    onTap: () => Get.toNamed(AppRoutes.myReviews),
                  ),
                  IosMenuTile(
                    icon: Icons.local_offer_outlined,
                    title: 'Voucher đã lưu',
                    onTap: () => Get.toNamed(AppRoutes.vouchers),
                  ),
                  IosMenuTile(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Vé & QR của tôi',
                    onTap: () => Get.toNamed(AppRoutes.myTickets),
                  ),
                  IosMenuTile(
                    icon: Icons.psychology_outlined,
                    title: 'Trợ lý AI',
                    onTap: () =>
                        showAiAssistantPanel(context, AiPanelTab.assistant),
                  ),
                  IosMenuTile(
                    icon: Icons.rate_review_outlined,
                    title: 'Khảo sát A/B (User Study)',
                    onTap: () => Get.toNamed(AppRoutes.userStudy),
                  ),
                ],
              ),
              IosGroupedSection(
                header: 'Cộng đồng',
                margin: const EdgeInsets.only(top: 8),
                children: [
                  IosMenuTile(
                    icon: Icons.people_outline_rounded,
                    title: 'Bạn bè & nhóm',
                    onTap: () => Get.find<ShellController>().changeTab(2),
                  ),
                  IosMenuTile(
                    icon: Icons.map_outlined,
                    title: 'Social Map',
                    onTap: () => Get.toNamed(AppRoutes.socialMap),
                  ),
                  IosMenuTile(
                    icon: Icons.explore_outlined,
                    title: 'Dấu chân của tôi',
                    onTap: () => Get.toNamed(AppRoutes.footprint),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: 'Đăng xuất',
                outlined: true,
                onPressed: _controller.logout,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }),
    );
  }
}
