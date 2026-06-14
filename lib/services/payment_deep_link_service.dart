import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';

import '../controllers/shell_controller.dart';
import '../routes/app_routes.dart';
import '../utils/snackbar_helper.dart';
import 'order_service.dart';

class PaymentDeepLinkService extends GetxService {
  final AppLinks _appLinks = AppLinks();
  final OrderService _orderService = Get.find<OrderService>();

  StreamSubscription<Uri>? _subscription;
  final Set<String> _processing = {};

  void start() {
    _subscription ??= _appLinks.uriLinkStream.listen(handleUri);
  }

  bool isPaymentResult(Uri uri) {
    return uri.scheme == 'stayhub' && uri.host == 'payment-result';
  }

  Future<void> handleUri(Uri uri) async {
    if (!isPaymentResult(uri)) return;

    final orderId = int.tryParse(uri.queryParameters['orderId'] ?? '');
    if (orderId == null || orderId <= 0) return;

    await completeOrder(
      orderId: orderId,
      expectedSuccess: uri.queryParameters['status'] == 'success',
    );
  }

  Future<void> completeOrder({
    required int orderId,
    bool? expectedSuccess,
  }) async {
    final processingKey = '$orderId:$expectedSuccess';
    if (!_processing.add(processingKey)) return;

    String? status;
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }

        try {
          final order = await _orderService.getOrderDetail(orderId);
          status = order.status;
          if (status == 'Paid' ||
              status == 'Completed' ||
              status == 'Cancelled') {
            break;
          }
        } catch (_) {
          // The signed provider callback can arrive shortly after app resume.
        }
      }

      await _openOrderDetail(orderId);

      if (status == 'Paid' || status == 'Completed') {
        SnackbarHelper.success('Thanh toán thành công');
      } else if (status == 'Cancelled') {
        SnackbarHelper.info('Thanh toán không thành công. Đơn đã được hủy.');
      } else if (expectedSuccess == true) {
        SnackbarHelper.info('Giao dịch đang được hệ thống xác nhận.');
      } else {
        SnackbarHelper.info('Đơn đang được cập nhật trạng thái thanh toán.');
      }
    } finally {
      _processing.remove(processingKey);
    }
  }

  Future<void> _openOrderDetail(int orderId) async {
    while (Get.context == null) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    Get.offAllNamed(AppRoutes.home);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (Get.isRegistered<ShellController>()) {
      Get.find<ShellController>().openBookingsTab();
    }

    Get.toNamed(AppRoutes.orderDetail, arguments: orderId);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
