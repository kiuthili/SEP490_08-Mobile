import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/payment_deep_link_service.dart';
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

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  final _payment = Get.find<PaymentService>();
  final _paymentDeepLinks = Get.find<PaymentDeepLinkService>();
  late final int _orderId;
  late final int _amount;
  late PaymentProvider _provider;
  var _loading = true;
  var _confirming = false;
  String? _paymentUrl;
  WebViewController? _webController;
  var _useExternalBrowser = false;
  var _returnHandled = false;
  var _launchedMomoApp = false;
  var _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _orderId = args['orderId'] as int? ?? 0;
    _amount = args['amount'] as int? ?? 0;
    _provider = args['provider'] == 'momo'
        ? PaymentProvider.momo
        : PaymentProvider.vnpay;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPayment());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasBackgrounded = true;
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _wasBackgrounded &&
        _launchedMomoApp &&
        !_returnHandled) {
      _wasBackgrounded = false;
      Future.delayed(
        const Duration(seconds: 2),
        () => mounted
            ? _paymentDeepLinks.completeOrder(orderId: _orderId)
            : null,
      );
    }
  }

  bool get _useInAppWebView =>
      !Platform.isLinux &&
      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> _initPayment() async {
    try {
      final payment = await _payment.createPayment(
        orderId: _orderId,
        amount: _amount,
        provider: _provider,
      );
      _paymentUrl = payment.paymentUrl;

      if (_provider == PaymentProvider.momo && payment.deeplink != null) {
        final deeplink = Uri.parse(payment.deeplink!);
        if (await canLaunchUrl(deeplink)) {
          _useExternalBrowser = true;
          _launchedMomoApp = await launchUrl(
            deeplink,
            mode: LaunchMode.externalApplication,
          );
          if (_launchedMomoApp) return;
        }
      }

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
      await _cancelOrderSilently();
      SnackbarHelper.error(e.toString());
      await _paymentDeepLinks.completeOrder(
        orderId: _orderId,
        expectedSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Bắt redirect sau VNPay/MoMo (gateway → FE) giống web `?payment=success`.
  bool _handlePaymentReturnUrl(String url) {
    if (_returnHandled) return false;
    final lower = url.toLowerCase();
    final isReturn = lower.contains('payment-result') ||
        lower.contains('payment=success') ||
        lower.contains('payment=cancelled');
    if (!isReturn) return false;

    _returnHandled = true;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processReturnUri(uri);
      });
    }
    return true;
  }

  Future<void> _processReturnUri(Uri uri) async {
    if (mounted) setState(() => _confirming = true);
    await _paymentDeepLinks.handleUri(uri);
    if (mounted) setState(() => _confirming = false);
  }

  Future<void> _cancelOrderSilently() async {
    try {
      await _payment.cancelPayment(_orderId, provider: _provider);
    } catch (_) {
      // The callback may already have settled the order.
    }
  }

  Future<void> _cancelPayment() async {
    setState(() => _confirming = true);
    try {
      await _payment.cancelPayment(_orderId, provider: _provider);
      await _paymentDeepLinks.completeOrder(
        orderId: _orderId,
        expectedSuccess: false,
      );
    } catch (e) {
      SnackbarHelper.error(e.toString());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _confirming;
    final providerLabel = _provider == PaymentProvider.momo ? 'MoMo' : 'VNPay';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) _cancelPayment();
      },
      child: AppScreen(
        title: providerLabel,
        bottomBar: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_useExternalBrowser) ...[
              Text(
                'Sau khi thanh toán, quay lại app để hệ thống tự kiểm tra kết quả.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            CustomButton(
              label: 'Hủy thanh toán',
              outlined: true,
              isLoading: busy,
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
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 240,
                              child: CustomButton(
                                label: 'Mở lại cổng thanh toán',
                                compact: true,
                                outlined: true,
                                onPressed: () => launchUrl(
                                  Uri.parse(_paymentUrl!),
                                  mode: LaunchMode.externalApplication,
                                ),
                              ),
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
      ),
    );
  }
}
