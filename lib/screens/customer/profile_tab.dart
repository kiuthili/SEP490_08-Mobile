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

  Widget _trailingValue(String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: AppTextStyles.textTheme.bodySmall,
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
              IosSurfaceCard(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.brandLight,
                      backgroundImage: user.avatarUrl?.isNotEmpty == true
                          ? CachedNetworkImageProvider(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl?.isNotEmpty != true
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
                      textAlign: TextAlign.center,
                      style: AppTextStyles.textTheme.headlineMedium,
                    ),
                    Text(user.email, style: AppTextStyles.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    const Chip(
                      avatar: Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: AppColors.success,
                      ),
                      label: Text('Tài khoản đã xác minh'),
                    ),
                    if (user.roles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 8,
                          children: user.roles
                              .map((role) => Chip(label: Text(role)))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              IosGroupedSection(
                header: 'Thông tin cá nhân',
                margin: const EdgeInsets.only(top: 20),
                children: [
                  IosMenuTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Họ và tên',
                    trailing: _trailingValue(user.fullName),
                  ),
                  IosMenuTile(
                    icon: Icons.mail_outline_rounded,
                    title: 'Email',
                    trailing: _trailingValue(user.email),
                  ),
                  IosMenuTile(
                    icon: Icons.phone_outlined,
                    title: 'Số điện thoại',
                    trailing: _trailingValue(
                      _valueOrFallback(user.phoneNumber),
                    ),
                  ),
                  IosMenuTile(
                    icon: Icons.people_outline_rounded,
                    title: 'Giới tính',
                    trailing: _trailingValue(_genderLabel(user.gender)),
                  ),
                  IosMenuTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'Ngày sinh',
                    trailing: _trailingValue(
                      _valueOrFallback(user.dateOfBirth),
                    ),
                  ),
                  IosMenuTile(
                    icon: Icons.login_rounded,
                    title: 'Phương thức đăng nhập',
                    trailing: _trailingValue(
                      _valueOrFallback(user.provider),
                    ),
                  ),
                ],
              ),
              IosGroupedSection(
                header: 'Tài khoản',
                margin: const EdgeInsets.only(top: 8),
                children: [
                  IosMenuTile(
                    icon: Icons.edit_rounded,
                    title: 'Cập nhật hồ sơ',
                    onTap: () async {
                      await Get.toNamed(AppRoutes.editProfile);
                      await _controller.loadProfile();
                    },
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
                    title: 'Trợ lý AI',
                    onTap: () =>
                        showAiAssistantPanel(context, AiPanelTab.assistant),
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
