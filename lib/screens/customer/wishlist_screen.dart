import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feature_controllers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/ios_grouped.dart';
import '../../widgets/loading_widget.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late final WishlistController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<WishlistController>();
    _controller.fetchWishlist();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Tour yêu thích',
      body: RefreshIndicator(
        onRefresh: _controller.fetchWishlist,
        child: Obx(() => _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    const physics = AlwaysScrollableScrollPhysics();

    if (_controller.isLoading.value && _controller.items.isEmpty) {
      return ListView(
        physics: physics,
        children: const [
          SizedBox(height: 120),
          LoadingWidget(message: 'Đang tải wishlist...'),
        ],
      );
    }

    if (_controller.items.isEmpty) {
      return ListView(
        physics: physics,
        children: const [
          SizedBox(height: 80),
          EmptyStateWidget(
            title: 'Chưa có tour yêu thích',
            subtitle: 'Nhấn ♥ ở chi tiết tour để lưu',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: physics,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _controller.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _controller.items[index];
        return IosSurfaceCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: ListTile(
            onTap: () => Get.toNamed(
              AppRoutes.tourDetail,
              arguments: item.tourId,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.tour.imageUrl != null &&
                      item.tour.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.tour.imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.favorite_rounded,
                        size: 32,
                      ),
                    )
                  : const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.favorite_rounded),
                    ),
            ),
            title: Text(item.tour.name),
            subtitle: Text(item.tour.city ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.favorite_rounded, color: Colors.red),
              onPressed: () => _controller.toggleWishlist(
                item.tourId,
                isInWishlist: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
