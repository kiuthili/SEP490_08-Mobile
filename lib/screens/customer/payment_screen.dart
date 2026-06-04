import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../controllers/feature_controllers.dart';
import '../../controllers/shell_controller.dart';
import '../../models/api_response.dart';
import '../../routes/app_routes.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_widget.dart';

/// Thanh toán VNPay/MoMo — WebView trong app để bắt URL return (giống redirect web).
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _payment = Get.find<PaymentService>();
  final _orderService = Get.find<OrderService>();
  late final int _orderId;
  late final int _amount;
  late PaymentProvider _provider;
  var _loading = true;
  var _confirming = false;
  var _autoConfirming = false;
  String? _paymentUrl;
  WebViewController? _webController;
  var _useExternalBrowser = false;
  var _returnHandled = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _orderId = args['orderId'] as int? ?? 0;
    _amount = args['amount'] as int? ?? 0;
    _provider = args['provider'] == 'momo'
        ? PaymentProvider.momo
        : PaymentProvider.vnpay;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPayment());
  }

  bool get _useInAppWebView =>
      !Platform.isLinux &&
      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> _initPayment() async {
    try {
      _paymentUrl = await _payment.createPaymentUrl(
        orderId: _orderId,
        amount: _amount,
        provider: _provider,
      );
      if (_paymentUrl == null) return;

      if (_useInAppWebView) {
        _webController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (mounted) setState(() => _loading = true);
              },
              onPageFinished: (_) {
                if (mounted) setState(() => _loading = false);
              },
              onNavigationRequest: (req) {
                if (_handlePaymentReturnUrl(req.url)) {
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
              onUrlChange: (change) {
                final url = change.url;
                if (url != null) _handlePaymentReturnUrl(url);
              },
            ),
          )
          ..loadRequest(Uri.parse(_paymentUrl!));
      } else {
        _useExternalBrowser = true;
        final uri = Uri.parse(_paymentUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      SnackbarHelper.error(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Bắt redirect sau VNPay/MoMo (gateway → FE) giống web `?payment=success`.
  bool _handlePaymentReturnUrl(String url) {
    if (_returnHandled) return false;
    final lower = url.toLowerCase();
    final isReturn = lower.contains('vnpay-return') ||
        lower.contains('momo-return') ||
        lower.contains('payment=success') ||
        lower.contains('payment=cancelled');
    if (!isReturn) return false;

    _returnHandled = true;
    final cancelled = lower.contains('cancelled') ||
        lower.contains('vnp_responsecode=24');
    if (cancelled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackbarHelper.info('Bạn đã hủy thanh toán trên cổng');
        _leave(result: false);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confirmAndLeave(auto: true);
      });
    }
    return true;
  }

  Future<void> _confirmAndLeave({bool auto = false}) async {
    if (_confirming || _autoConfirming) return;
    if (auto) {
      setState(() => _autoConfirming = true);
    } else {
      setState(() => _confirming = true);
    }

    try {
      // Đã Paid (callback gateway hoặc lần trước) → thoát ngay.
      if (await _isOrderAlreadyPaid()) {
        SnackbarHelper.success('Đơn đã được thanh toán');
        _leave(result: true);
        return;
      }

      // Retry: callback VNPay có thể chậm vài giây sau khi quay lại app.
      ApiError? lastError;
      for (var attempt = 0; attempt < 4; attempt++) {
        if (attempt > 0) {
          await Future.delayed(Duration(seconds: attempt * 2));
          if (await _isOrderAlreadyPaid()) {
            SnackbarHelper.success('Đơn đã được thanh toán');
            _leave(result: true);
            return;
          }
        }
        try {
          await _payment.confirmPayment(_orderId, provider: _provider);
          SnackbarHelper.success('Xác nhận thanh toán thành công');
          _leave(result: true);
          return;
        } on ApiError catch (e) {
          lastError = e;
          if (e.statusCode != 400) break;
        }
      }

      if (!mounted) return;
      await _showConfirmFailedDialog(
        lastError?.message ??
            'Hệ thống chưa ghi nhận thanh toán. Đợi vài giây rồi bấm «Thử lại».',
      );
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
          _autoConfirming = false;
        });
      }
    }
  }

  Future<bool> _isOrderAlreadyPaid() async {
    try {
      final order = await _orderService.getOrderDetail(_orderId);
      return order.status == 'Paid' || order.status == 'Completed';
    } catch (_) {
      return false;
    }
  }

  Future<void> _showConfirmFailedDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chưa xác nhận được'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _leave(result: false, goToOrders: true);
            },
            child: const Text('Về đơn hàng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmAndLeave();
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  void _leave({required bool result, bool goToOrders = false}) {
    if (!mounted) return;
    if (goToOrders) {
      Get.offAllNamed(AppRoutes.home);
      Get.find<ShellController>().changeTab(3);
      Get.find<OrderController>().fetchOrders(refresh: true);
      return;
    }
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back(result: result);
    } else {
      Get.offAllNamed(AppRoutes.home);
      Get.find<ShellController>().changeTab(3);
    }
  }

  Future<void> _cancelPayment() async {
    setState(() => _confirming = true);
    try {
      await _payment.cancelPayment(_orderId, provider: _provider);
      SnackbarHelper.info('Đã hủy thanh toán');
      _leave(result: false);
    } catch (e) {
      SnackbarHelper.error(e.toString());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _confirming || _autoConfirming;
    final providerLabel =
        _provider == PaymentProvider.momo ? 'MoMo' : 'VNPay';

    return AppScreen(
      title: providerLabel,
      bottomBar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_useExternalBrowser) ...[
            Text(
              'Sau khi thanh toán trên trình duyệt, quay lại app và bấm xác nhận.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          CustomButton(
            label: 'Đã thanh toán',
            isLoading: busy,
            onPressed: busy ? null : () => _confirmAndLeave(),
          ),
          const SizedBox(height: 8),
          CustomButton(
            label: 'Hủy thanh toán',
            outlined: true,
            onPressed: busy ? null : _cancelPayment,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_loading && _webController != null)
                const LinearProgressIndicator(minHeight: 2),
              if (_webController != null)
                Expanded(child: WebViewWidget(controller: _webController!))
              else if (!_loading)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.open_in_browser_rounded,
                          size: 64,
                          color: AppColors.brand,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _useExternalBrowser
                              ? 'Trình duyệt đã mở cổng $providerLabel.\n'
                                  'Hoàn tất thanh toán rồi quay lại đây.'
                              : 'Đang tải cổng thanh toán...',
                          textAlign: TextAlign.center,
                        ),
                        if (_paymentUrl != null) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(_paymentUrl!),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Text('Mở lại trang thanh toán'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                const Expanded(child: LoadingWidget()),
            ],
          ),
          if (busy)
            Container(
              color: Colors.black26,
              child: const Center(
                child: LoadingWidget(
                  message: 'Đang xác nhận thanh toán...',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
