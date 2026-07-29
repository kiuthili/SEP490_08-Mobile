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
import '../../utils/snackbar_helper.dart';
import '../../services/system_setting_service.dart';
import '../../widgets/stayhub_logo.dart';
import '../../widgets/language_bottom_sheet.dart';

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
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _openEditProfile();
                  } else if (value == 'password') {
                    Get.toNamed(AppRoutes.changePassword);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20, color: AppColors.textPrimary),
                        SizedBox(width: 8),
                        Text('Sửa hồ sơ', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textPrimary),
                        SizedBox(width: 8),
                        Text('Đổi mật khẩu', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
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
                        children: [
                          const Icon(Icons.verified_rounded,
                              size: 14, color: Color(0xFF8FE5B0)),
                          const SizedBox(width: 4),
                          Text(
                            'pt_member'.tr,
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
      title: 'pt_my_orders'.tr,
      viewAllText: 'pt_view_history'.tr,
      onViewAll: () => Get.toNamed(AppRoutes.orders, arguments: ''),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildIconGridItem(
              Icons.receipt_long_outlined,
              'pt_all'.tr,
              () => Get.toNamed(AppRoutes.orders, arguments: ''),
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.check_circle_outline_rounded,
              'pt_paid'.tr,
              () => Get.toNamed(AppRoutes.orders, arguments: 'Paid'),
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.cancel_outlined,
              'pt_cancelled'.tr,
              () => Get.toNamed(AppRoutes.orders, arguments: 'Cancelled'),
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.assignment_return_outlined,
              'pt_cancel_req'.tr,
              () => Get.toNamed(AppRoutes.orders, arguments: 'Request to cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyUtilities() {
    return _buildSectionCard(
      title: 'pt_utilities_offers'.tr,
      viewAllText: '',
      onViewAll: () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildIconGridItem(
              Icons.local_offer_outlined,
              'pt_wallet_voucher'.tr,
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
              'pt_ticket_qr'.tr,
              () => Get.toNamed(AppRoutes.myTickets),
              iconColor: Colors.purple,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.star_outline_rounded,
              'pt_reviews'.tr,
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
      title: 'pt_community_explore'.tr,
      viewAllText: '',
      onViewAll: () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildIconGridItem(
              Icons.psychology_outlined,
              'pt_ai_assistant'.tr,
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
              'pt_friends'.tr,
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
              'pt_messages'.tr,
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
                title: 'pt_support_others'.tr,
                viewAllText: '',
                onViewAll: () {},
                child: Column(
                  children: [
                    _buildSupportTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'pt_notif_settings'.tr,
                      onTap: () =>
                          SnackbarHelper.info('pt_feature_dev'.tr),
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.location_on_outlined,
                      title: 'pt_privacy_location'.tr,
                      onTap: () =>
                          SnackbarHelper.info('pt_feature_dev'.tr),
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.language_rounded,
                      title: 'pt_language_settings'.tr,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (_) => LanguageBottomSheet(
                            selected: Get.locale?.languageCode ?? 'vi',
                            onSelect: (lang) {
                              if (lang == 'vi') {
                                Get.updateLocale(const Locale('vi', 'VN'));
                              } else {
                                Get.updateLocale(const Locale('en', 'US'));
                              }
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.policy_outlined,
                      title: 'pt_refund_policy'.tr,
                      onTap: () => Get.toNamed(AppRoutes.bookingTerms),
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.description_outlined,
                      title: 'pt_terms'.tr,
                      onTap: () => Get.toNamed(AppRoutes.terms),
                    ),
                    const Divider(
                        height: 1, indent: 40, color: Color(0xFFF0F0F0)),
                    _buildSupportTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'pt_privacy_policy'.tr,
                      onTap: () => Get.toNamed(AppRoutes.privacy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CustomButton(
                  label: 'pt_logout'.tr,
                  outlined: true,
                  onPressed: _controller.logout,
                ),
              ),
              const SizedBox(height: 32),
              _buildCompanyInfo(),
              const SizedBox(height: 16),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCompanyInfo() {
    return Obx(() {
      final service = Get.isRegistered<SystemSettingService>() 
          ? Get.find<SystemSettingService>() 
          : null;
          
      final _ = service?.isLoading.value;
      
      final name = service?.getSettingSync('CompanyName') ?? 'Công ty TNHH StayHub';
      final address = service?.getSettingSync('CompanyAddress') ?? '';
      final phone = service?.getSettingSync('CompanyPhone') ?? '';
      final email = service?.getSettingSync('CompanyEmail') ?? '';
      
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StayHubLogo(variant: StayHubLogoVariant.full, iconSize: 32),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 32, right: 32),
              child: Text(address, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
            ),
          const SizedBox(height: 4),
          if (phone.isNotEmpty || email.isNotEmpty)
            Text('${phone.isNotEmpty ? "Hotline: $phone" : ""}${phone.isNotEmpty && email.isNotEmpty ? " • " : ""}${email.isNotEmpty ? "Email: $email" : ""}', 
                 textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Text('Phiên bản 1.0.0', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5))),
        ],
      );
    });
  }
}
