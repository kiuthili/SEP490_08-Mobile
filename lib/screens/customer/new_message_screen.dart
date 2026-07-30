import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../models/feature_models.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';
import 'package:stayhub_mobile/theme/app_radius.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final _social = Get.find<SocialController>();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_social.friends.isEmpty) {
        _social.fetchFriends();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FriendModel> get _filteredFriends {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _social.friends;
    return _social.friends.where((f) {
      final name = f.fullName.toLowerCase();
      final email = (f.email ?? '').toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'sc_nm_title'.tr,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'sc_nm_search_hint'.tr,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_social.isLoading.value && _social.friends.isEmpty) {
                return LoadingWidget(message: 'sc_nm_loading'.tr);
              }
              if (_social.friends.isEmpty) {
                return EmptyStateWidget(
                  title: 'sc_nm_empty_friends_title'.tr,
                  subtitle: 'sc_nm_empty_friends_desc'.tr,
                  icon: Icons.person_add_alt_1_rounded,
                );
              }

              final friends = _filteredFriends;
              if (friends.isEmpty) {
                return EmptyStateWidget(
                  title: 'sc_nm_empty_search_title'.tr,
                  subtitle: 'sc_nm_empty_search_desc'.tr,
                  icon: Icons.search_off_rounded,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: friends.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return _FriendListTile(
                    friend: friend,
                    onTap: () {
                      Get.offNamed(
                        AppRoutes.chatRoom,
                        arguments: friend.userId,
                      );
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FriendListTile extends StatelessWidget {
  const _FriendListTile({
    required this.friend,
    required this.onTap,
  });

  final FriendModel friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.button,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.button,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _FriendAvatar(
              imageUrl: friend.avatarUrl,
              name: friend.fullName,
              size: 50,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.fullName,
                    style: AppTextStyles.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    friend.email ?? 'sc_nm_stayhub_friend'.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.brandLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: AppColors.brand,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({
    required this.imageUrl,
    required this.name,
    required this.size,
  });

  final String? imageUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.brandLight,
        shape: BoxShape.circle,
      ),
      child: imageUrl?.isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _fallback(initial),
            )
          : _fallback(initial),
    );
  }

  Widget _fallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.brand,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}
