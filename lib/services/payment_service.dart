import 'package:get/get.dart';
import '../constants/api_constants.dart';
import 'base_service.dart';

enum PaymentProvider { vnpay, momo }

class PaymentService extends GetxService with BaseServiceMixin {
  Future<String> createPaymentUrl({
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
        },
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final url = body['paymentUrl'] ?? body['PaymentUrl'];
        if (url is String && url.isNotEmpty) return url;
      }
      if (body is String && body.isNotEmpty) return body;
      throw StateError('Không nhận được paymentUrl');
    });
  }

  Future<void> confirmPayment(
    int orderId, {
    PaymentProvider provider = PaymentProvider.vnpay,
  }) async {
    await request(() async {
      final base = provider == PaymentProvider.momo
          ? ApiConstants.momo
          : ApiConstants.vnpay;
      await api.dio.post('$base/confirm/$orderId');
    });
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
