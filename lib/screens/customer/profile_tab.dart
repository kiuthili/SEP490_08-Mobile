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
import '../../utils/snackbar_helper.dart';

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

  Future<void> _openEditProfile() async {
    await Get.toNamed(AppRoutes.editProfile);
    await _controller.loadProfile();
  }

  Widget _buildHeader(UserModel user) {
    final hasAvatar = user.avatarUrl?.isNotEmpty == true;
    final initial = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()[0].toUpperCase()
        : '?';

    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 20,
          left: 16,
          right: 16),
      decoration: const BoxDecoration(
        gradient: AppColors.homeHeroGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => Get.toNamed(AppRoutes.notifications),
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Colors.white),
              ),
              IconButton(
                onPressed: _openEditProfile,
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.brandLight,
                  backgroundImage: hasAvatar
                      ? CachedNetworkImageProvider(user.avatarUrl!)
                      : null,
                  child: !hasAvatar
                      ? Text(
                          initial,
                          style:
                              AppTextStyles.textTheme.headlineSmall?.copyWith(
                            color: AppColors.brandDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: AppTextStyles.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: AppTextStyles.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_rounded,
                              size: 14, color: Color(0xFF8FE5B0)),
                          SizedBox(width: 4),
                          Text(
                            'Thành viên StayHub',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconGridItem(IconData icon, String label, VoidCallback onTap,
      {Color iconColor = AppColors.brand}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: iconColor),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title,
      required String viewAllText,
      required VoidCallback onViewAll,
      required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              if (viewAllText.isNotEmpty)
                InkWell(
                  onTap: onViewAll,
                  child: Row(
                    children: [
                      Text(
                        viewAllText,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSupportTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Icon(icon, color: AppColors.brand),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 20, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  Widget _buildMyBookings() {
    return _buildSectionCard(
      title: 'Đơn đặt tour của tôi',
      viewAllText: 'Xem lịch sử',
      onViewAll: () => Get.toNamed(AppRoutes.orders, arguments: ''),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildIconGridItem(
              Icons.account_balance_wallet_outlined,
              'Chờ\nthanh toán',
              () => Get.toNamed(AppRoutes.orders, arguments: 'Pending'),
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.check_circle_outline_rounded,
              'Đã\nxác nhận',
              () => Get.toNamed(AppRoutes.orders, arguments: 'Paid'),
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.flight_takeoff_rounded,
              'Hoàn thành',
              () => Get.toNamed(AppRoutes.orders, arguments: 'Completed'),
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.cancel_outlined,
              'Đã hủy',
              () => Get.toNamed(AppRoutes.orders, arguments: 'Cancelled'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyUtilities() {
    return _buildSectionCard(
      title: 'Tiện ích & Ưu đãi',
      viewAllText: '',
      onViewAll: () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildIconGridItem(
              Icons.local_offer_outlined,
              'Ví\nVoucher',
              () => Get.toNamed(AppRoutes.vouchers),
              iconColor: Colors.deepOrange,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.favorite_border_rounded,
              'Wishlist',
              () => Get.toNamed(AppRoutes.wishlist),
              iconColor: Colors.pink,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.confirmation_number_outlined,
              'Vé & QR',
              () => Get.toNamed(AppRoutes.myTickets),
              iconColor: Colors.purple,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.star_outline_rounded,
              'Đánh giá',
              () => Get.toNamed(AppRoutes.myReviews),
              iconColor: Colors.amber.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityAndExplore() {
    return _buildSectionCard(
      title: 'Cộng đồng & Khám phá',
      viewAllText: '',
      onViewAll: () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildIconGridItem(
              Icons.psychology_outlined,
              'Trợ lý\nAI',
              () {
                try {
                  Get.find<ShellController>().changeTab(3);
                } catch (_) {
                  Get.toNamed(AppRoutes.aiQuestionnaire);
                }
              },
              iconColor: Colors.blue.shade700,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.people_outline_rounded,
              'Bạn bè',
              () => Get.find<ShellController>().changeTab(2),
              iconColor: Colors.teal,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.map_outlined,
              'Social\nMap',
              () => Get.find<ShellController>().changeTab(0),
              iconColor: AppColors.success,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.chat_bubble_outline_rounded,
              'Tin nhắn',
              () => Get.toNamed(AppRoutes.chatInbox),
              iconColor: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F6F8), // Lighter background for Shopee style
      body: Obx(() {
        final user = _controller.currentUser.value;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _controller.loadProfile,
          child: ListView(
            padding: EdgeInsets.zero.copyWith(
              bottom: ShellLayout.bottomInset(context) + 16,
            ),
            children: [
              _buildHeader(user),
              _buildMyBookings(),
              _buildMyUtilities(),
              _buildCommunityAndExplore(),
              _buildSectionCard(
                title: 'Hỗ trợ & Khác',
                viewAllText: '',
                onViewAll: () {},
                child: Column(
                  children: [
                    _buildSupportTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Cài đặt thông báo',
                      onTap: () =>
                          SnackbarHelper.info('Tính năng đang phát triển'),
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.location_on_outlined,
                      title: 'Cài đặt quyền riêng tư định vị',
                      onTap: () =>
                          SnackbarHelper.info('Tính năng đang phát triển'),
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.language_rounded,
                      title: 'Cài đặt ngôn ngữ',
                      onTap: () =>
                          SnackbarHelper.info('Tính năng đang phát triển'),
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.policy_outlined,
                      title: 'Chính sách hoàn hủy',
                      onTap: () => Get.toNamed(AppRoutes.bookingTerms),
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.description_outlined,
                      title: 'Điều khoản dịch vụ',
                      onTap: () => Get.toNamed(AppRoutes.terms),
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Chính sách bảo mật',
                      onTap: () => Get.toNamed(AppRoutes.privacy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CustomButton(
                  label: 'Đăng xuất',
                  outlined: true,
                  onPressed: _controller.logout,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
