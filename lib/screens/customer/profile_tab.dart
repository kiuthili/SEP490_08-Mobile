import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/shell_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/shell_layout.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/ios_grouped.dart';

class ProfileTab extends GetView<AuthController> {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (controller.currentUser.value == null) {
      controller.loadProfile();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: Obx(() {
        final user = controller.currentUser.value;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0).copyWith(
            bottom: ShellLayout.bottomInset(context),
          ),
          children: [
            IosSurfaceCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.brandLight,
                    backgroundImage: user.avatarUrl != null
                        ? CachedNetworkImageProvider(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.textTheme.headlineMedium,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.fullName,
                    style: AppTextStyles.textTheme.headlineMedium,
                  ),
                  Text(user.email, style: AppTextStyles.textTheme.bodySmall),
                  if (user.roles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        children: user.roles
                            .map((r) => Chip(label: Text(r)))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            IosGroupedSection(
              header: 'Tài khoản',
              margin: const EdgeInsets.only(top: 20),
              children: [
                IosMenuTile(
                  icon: Icons.edit_rounded,
                  title: 'Cập nhật hồ sơ',
                  onTap: () => Get.toNamed(AppRoutes.editProfile),
                ),
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
                  title: 'Trợ lý AI — khảo sát',
                  onTap: () => Get.toNamed(AppRoutes.aiQuestionnaire),
                ),
                IosMenuTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Gợi ý tour AI',
                  onTap: () => Get.toNamed(AppRoutes.aiRecommendations),
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
              ],
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Đăng xuất',
              outlined: true,
              onPressed: controller.logout,
            ),
            const SizedBox(height: 16),
          ],
        );
      }),
    );
  }
}
