import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/shell_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/shell_layout.dart';
import '../../theme/app_text_styles.dart';
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
    final cs = Theme.of(context).colorScheme;
    final textPrimary = cs.onSurface;
    final textSecondary = AppColors.textSecondary;

    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: 24,
          left: 16,
          right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Obx(() {
                if (!Get.isRegistered<NotificationController>()) return const SizedBox.shrink();
                final notifController = Get.find<NotificationController>();
                final unread = notifController.unreadCount;
                return IconButton(
                  onPressed: () => Get.toNamed(AppRoutes.notifications),
                  icon: Badge(
                    label: Text(unread > 99 ? '99+' : unread.toString()),
                    isLabelVisible: unread > 0,
                    backgroundColor: AppColors.error,
                    child: Icon(Icons.notifications_none_rounded, color: textPrimary),
                  ),
                );
              }),
              PopupMenuButton<String>(
                icon: Icon(Icons.settings_outlined, color: textPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _openEditProfile();
                  } else if (value == 'password') {
                    Get.toNamed(AppRoutes.changePassword);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 20, color: textPrimary),
                        const SizedBox(width: 8),
                        Text('edit_profile'.tr,
                            style:
                                TextStyle(color: textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 20, color: textPrimary),
                        const SizedBox(width: 8),
                        Text('change_password'.tr,
                            style:
                                TextStyle(color: textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          CircleAvatar(
            radius: 46,
            backgroundColor: AppColors.brandLight,
            backgroundImage: hasAvatar
                ? CachedNetworkImageProvider(user.avatarUrl!)
                : null,
            child: !hasAvatar
                ? Text(
                    initial,
                    style: AppTextStyles.textTheme.headlineLarge?.copyWith(
                      color: AppColors.brandDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName,
            style: AppTextStyles.textTheme.titleLarge?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: AppTextStyles.textTheme.bodyMedium?.copyWith(
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brandLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded,
                    size: 16, color: AppColors.brand),
                const SizedBox(width: 4),
                Text(
                  user.isStaff ? 'Staff Account' : 'pt_member'.tr,
                  style: const TextStyle(
                    color: AppColors.brandDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconGridItem(IconData icon, String label, VoidCallback onTap,
      {Color iconColor = AppColors.brand}) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title,
      required String viewAllText,
      required VoidCallback onViewAll,
      required Widget child}) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
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
                    color: textPrimary,
                  ),
                ),
                if (viewAllText.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onViewAll,
                    child: Row(
                      children: [
                        Text(
                          viewAllText,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSupportTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: textColor)),
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
              Icons.receipt_long_rounded,
              'pt_all'.tr,
              () => Get.toNamed(AppRoutes.orders, arguments: ''),
              iconColor: Colors.blue.shade500,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.check_circle_outline_rounded,
              'pt_paid'.tr,
              () => Get.toNamed(AppRoutes.orders, arguments: 'Paid'),
              iconColor: Colors.green.shade500,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.cancel_outlined,
              'pt_cancelled'.tr,
              () => Get.toNamed(AppRoutes.orders, arguments: 'Cancelled'),
              iconColor: Colors.red.shade400,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.assignment_return_outlined,
              'pt_cancel_req'.tr,
              () =>
                  Get.toNamed(AppRoutes.orders, arguments: 'Request to cancel'),
              iconColor: Colors.orange.shade400,
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
              Icons.local_offer_rounded,
              'pt_wallet_voucher'.tr,
              () => Get.toNamed(AppRoutes.vouchers),
              iconColor: Colors.deepOrange.shade400,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.favorite_rounded,
              'wl_title'.tr,
              () => Get.toNamed(AppRoutes.wishlist),
              iconColor: Colors.pink.shade400,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.confirmation_number_rounded,
              'pt_ticket_qr'.tr,
              () => Get.toNamed(AppRoutes.myTickets),
              iconColor: Colors.purple.shade400,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.star_rounded,
              'pt_reviews'.tr,
              () => Get.toNamed(AppRoutes.myReviews),
              iconColor: Colors.amber.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffWorkspace(UserModel user) {
    if (!user.isStaff) return const SizedBox.shrink();
    
    return _buildSectionCard(
      title: 'Staff Workspace',
      viewAllText: '',
      onViewAll: () {},
      child: Column(
        children: [
          _buildSupportTile(
            icon: Icons.chat_bubble_rounded,
            title: 'pt_messages'.tr,
            onTap: () => Get.toNamed(AppRoutes.chatInbox),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityAndExplore(UserModel user) {
    if (user.isStaff) return const SizedBox.shrink();

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
              Icons.psychology_rounded,
              'pt_ai_assistant'.tr,
              () {
                try {
                  Get.find<ShellController>().changeTab(3);
                } catch (_) {
                  Get.toNamed(AppRoutes.aiQuestionnaire);
                }
              },
              iconColor: Colors.blue.shade600,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.people_alt_rounded,
              'pt_friends'.tr,
              () => Get.find<ShellController>().changeTab(2),
              iconColor: Colors.teal.shade500,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.map_rounded,
              'Social Map',
              () => Get.find<ShellController>().changeTab(0),
              iconColor: AppColors.success,
            ),
          ),
          Expanded(
            child: _buildIconGridItem(
              Icons.chat_bubble_rounded,
              'pt_messages'.tr,
              () => Get.toNamed(AppRoutes.chatInbox),
              iconColor: Colors.indigo.shade500,
            ),
          ),
        ],
      ),
    );
  }

  /// Dark Mode toggle tile
  Widget _buildDarkModeToggle() {
    final themeCtrl = Get.find<ThemeController>();
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final dividerColor = Theme.of(context).dividerColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Obx(() {
          final isDark = themeCtrl.isDark;
          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                visualDensity: const VisualDensity(vertical: -2),
                leading: Icon(
                  isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: isDark
                      ? const Color(0xFFAC8FFF)
                      : Colors.amber.shade600,
                ),
                title: Text(
                  'pt_dark_mode'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: isDark,
                  activeColor: AppColors.brand,
                  onChanged: (_) => themeCtrl.toggleTheme(),
                ),
              ),
              Divider(height: 1, indent: 0, color: dividerColor),
              ListTile(
                contentPadding: EdgeInsets.zero,
                visualDensity: const VisualDensity(vertical: -2),
                leading:
                    const Icon(Icons.contrast_rounded, color: AppColors.textSecondary),
                title: Text(
                  'pt_theme_system'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                trailing: themeCtrl.themeMode.value == ThemeMode.system
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.brand, size: 22)
                    : null,
                onTap: themeCtrl.setSystem,
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      body: Obx(() {
        final user = _controller.currentUser.value;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _controller.loadProfile,
          child: ListView(
            padding: EdgeInsets.zero.copyWith(
              bottom: ShellLayout.bottomInset(context) + 32,
            ),
            children: [
              _buildHeader(user),

              if (!user.isStaff) _buildMyBookings(),
              if (!user.isStaff) _buildMyUtilities(),
              
              _buildStaffWorkspace(user),
              _buildCommunityAndExplore(user),

              _buildDarkModeToggle(),

              _buildSectionCard(
                title: 'pt_support_others'.tr,
                viewAllText: '',
                onViewAll: () {},
                child: Column(
                  children: [
                    _buildSupportTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'pt_notif_settings'.tr,
                      onTap: () => SnackbarHelper.info('pt_feature_dev'.tr),
                    ),
                    Divider(height: 1, indent: 0, color: dividerColor),
                    _buildSupportTile(
                      icon: Icons.location_on_outlined,
                      title: 'pt_privacy_location'.tr,
                      onTap: () => SnackbarHelper.info('pt_feature_dev'.tr),
                    ),
                    Divider(height: 1, indent: 0, color: dividerColor),
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
                    Divider(height: 1, indent: 0, color: dividerColor),
                    _buildSupportTile(
                      icon: Icons.policy_outlined,
                      title: 'pt_refund_policy'.tr,
                      onTap: () => Get.toNamed(AppRoutes.bookingTerms),
                    ),
                    Divider(height: 1, indent: 0, color: dividerColor),
                    _buildSupportTile(
                      icon: Icons.description_outlined,
                      title: 'pt_terms'.tr,
                      onTap: () => Get.toNamed(AppRoutes.terms),
                    ),
                    Divider(height: 1, indent: 0, color: dividerColor),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _controller.logout,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'pt_logout'.tr,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
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
    final textSecondary = AppColors.textSecondary;
    return Obx(() {
      final service = Get.isRegistered<SystemSettingService>()
          ? Get.find<SystemSettingService>()
          : null;

      final _ = service?.isLoading.value;

      final name =
          service?.getSettingSync('CompanyName') ?? 'pt_company_name'.tr;
      final address = service?.getSettingSync('CompanyAddress') ?? '';
      final phone = service?.getSettingSync('CompanyPhone') ?? '';
      final email = service?.getSettingSync('CompanyEmail') ?? '';

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StayHubLogo(variant: StayHubLogoVariant.full, iconSize: 32),
          const SizedBox(height: 12),
          Text(name,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: textSecondary)),
          if (address.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(top: 4, left: 32, right: 32),
              child: Text(address,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      height: 1.4)),
            ),
          const SizedBox(height: 4),
          if (phone.isNotEmpty || email.isNotEmpty)
            Text(
                '${phone.isNotEmpty ? "Hotline: $phone" : ""}${phone.isNotEmpty && email.isNotEmpty ? " • " : ""}${email.isNotEmpty ? "Email: $email" : ""}',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12, color: textSecondary)),
          const SizedBox(height: 16),
          Text('${'pt_version'.tr} 1.0.0',
              style: TextStyle(
                  fontSize: 11,
                  color: textSecondary.withValues(alpha: 0.5))),
        ],
      );
    });
  }
}
