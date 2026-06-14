import 'package:get/get.dart';
import '../constants/api_constants.dart';
import 'base_service.dart';

enum PaymentProvider { vnpay, momo }

class PaymentLaunchData {
  const PaymentLaunchData({
    required this.paymentUrl,
    this.deeplink,
    this.qrCodeUrl,
  });

  final String paymentUrl;
  final String? deeplink;
  final String? qrCodeUrl;
}

class PaymentService extends GetxService with BaseServiceMixin {
  Future<PaymentLaunchData> createPayment({
    required int orderId,
    required int amount,
    PaymentProvider provider = PaymentProvider.vnpay,
  }) async {
    return request(() async {
      final path = provider == PaymentProvider.momo
          ? '${ApiConstants.momo}/create-payment'
          : '${ApiConstants.vnpay}/create-payment';
      final response = await api.dio.post(
        path,
        data: {
          'orderId': orderId,
          'amount': amount,
          'provider': provider == PaymentProvider.momo ? 'MoMo' : 'VNPay',
          'clientType': 'mobile',
        },
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final url = body['paymentUrl'] ?? body['PaymentUrl'];
        if (url is String && url.isNotEmpty) {
          return PaymentLaunchData(
            paymentUrl: url,
            deeplink: _optionalString(body['deeplink'] ?? body['Deeplink']),
            qrCodeUrl: _optionalString(
              body['qrCodeUrl'] ?? body['QrCodeUrl'],
            ),
          );
        }
      }
      if (body is String && body.isNotEmpty) {
        return PaymentLaunchData(paymentUrl: body);
      }
      throw StateError('Không nhận được paymentUrl');
    });
  }

  String? _optionalString(dynamic value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<void> cancelPayment(
    int orderId, {
    PaymentProvider provider = PaymentProvider.vnpay,
  }) async {
    await request(() async {
      final base = provider == PaymentProvider.momo
          ? ApiConstants.momo
          : ApiConstants.vnpay;
      await api.dio.post('$base/cancel/$orderId');
    });
  }
}
