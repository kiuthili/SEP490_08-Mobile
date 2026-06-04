import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../models/feature_models.dart';
import '../models/order_model.dart';
import 'base_service.dart';

class OrderService extends GetxService with BaseServiceMixin {
  Future<OrderModel> createOrder({
    required int scheduleId,
    required int finalAmount,
    required List<Map<String, dynamic>> orderDetails,
    String? voucherCode,
    String? note,
  }) async {
    return request(() async {
      final response = await api.dio.post(
        ApiConstants.orders,
        data: {
          'scheduleId': scheduleId,
          'finalAmount': finalAmount,
          if (voucherCode != null) 'voucherCode': voucherCode,
          if (note != null) 'note': note,
          'orderDetails': orderDetails,
        },
      );
      return parseData(response.data, OrderModel.fromJson);
    });
  }

  Future<PaginationModel<OrderModel>> getMyOrders({
    required int userId,
    int page = 1,
    int pageSize = AppConstants.defaultPageSize,
    String? status,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.orders}/user/$userId',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (status != null) 'status': status,
        },
      );
      return parsePagination(response.data, OrderModel.fromJson);
    });
  }

  Future<OrderModel> getOrderDetail(int id) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.orders}/my/$id');
      return parseData(response.data, OrderModel.fromJson);
    });
  }

  Future<void> cancelOrder(int id) async {
    await request(() async {
      await api.dio.patch('${ApiConstants.orders}/$id/cancel');
    });
  }

  Future<void> requestCancellation({
    required int orderId,
    required String reason,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
  }) async {
    await request(() async {
      await api.dio.post(
        ApiConstants.cancellationRequest,
        data: {
          'orderId': orderId,
          'reason': reason,
          'bankName': bankName,
          'accountNumber': accountNumber,
          'accountHolderName': accountHolderName,
        },
      );
    });
  }

  Future<List<ScheduleCustomerModel>> getScheduleCustomers(
    int scheduleId,
  ) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.orders}/schedule/$scheduleId/customers',
      );
      return parseList(response.data, ScheduleCustomerModel.fromJson);
    });
  }

  Future<List<EligibleScheduleModel>> getEligibleSchedules() async {
    return request(() async {
      final response =
          await api.dio.get('${ApiConstants.orders}/me/eligible-schedules');
      return parseList(response.data, EligibleScheduleModel.fromJson);
    });
  }

  Future<List<TicketModel>> getMyTickets() async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.tickets}/my-tickets');
      return parseList(response.data, TicketModel.fromJson);
    });
  }

  Future<List<TicketModel>> getTicketsForOrder(int orderId) async {
    final all = await getMyTickets();
    return all.where((t) => t.orderId == orderId).toList();
  }

  Future<List<TicketModel>> getTicketsBySchedule(int scheduleId) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tickets}/schedule/$scheduleId',
      );
      return parseList(response.data, TicketModel.fromJson);
    });
  }

  Future<Map<String, dynamic>> checkIn({
    required String qrCode,
    required int scheduleId,
  }) async {
    return request(() async {
      final response = await api.dio.put(
        '${ApiConstants.tickets}/check-in',
        data: {'qrCode': qrCode, 'scheduleId': scheduleId},
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>? ?? body;
      }
      return {};
    });
  }
}
