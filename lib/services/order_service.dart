import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/models/check_in_result_model.dart';
import 'package:stayhub_mobile/models/schedule_customer_model.dart';
import 'package:stayhub_mobile/models/staff_ticket_model.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../models/feature_models.dart';
import '../models/order_model.dart';
import 'base_service.dart';
import 'storage_service.dart';

class OrderService extends GetxService with BaseServiceMixin {
  final StorageService _storage = Get.find<StorageService>();
  Future<OrderModel> createOrder({
    required int scheduleId,
    required int finalAmount,
    required List<Map<String, dynamic>> orderDetails,
    String? voucherCode,
    int? promotionValue,
    String? note,
    required String idempotencyKey,
  }) async {
    return request(() async {
      final response = await api.dio.post(
        ApiConstants.orders,
        data: {
          'scheduleId': scheduleId,
          'finalAmount': finalAmount,
          if (voucherCode != null) 'voucherCode': voucherCode,
          if (promotionValue != null) 'promotionValue': promotionValue,
          if (note != null) 'note': note,
          'orderDetails': orderDetails,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
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
    int scheduleId, {
    String? attendeeName,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.orders}/schedule/$scheduleId/customers',
        queryParameters: {
          if (attendeeName != null && attendeeName.trim().isNotEmpty)
            'attendeeName': attendeeName.trim(),
        },
      );
      return parseList(response.data, ScheduleCustomerModel.fromJson);
    });
  }

  Future<List<EligibleScheduleModel>> getEligibleSchedules() async {
    return request(() async {
      final user = _storage.user;
      if (user == null) return <EligibleScheduleModel>[];

      String url = '${ApiConstants.orders}/me/eligible-schedules';
      final isManagerOrAdmin = user.roles.any((r) {
        final role = r.toLowerCase();
        return role == 'manager' || role == 'admin' || role == 'operator';
      });
      final isStaff = user.roles.any((r) => r.toLowerCase() == 'staff');

      if (isManagerOrAdmin) {
        url = '${ApiConstants.tourSchedules}/my?page=1&pageSize=100';
      } else if (isStaff) {
        url = '${ApiConstants.tourScheduleStaffs}/assigned?page=1&pageSize=100';
      }

      final response = await api.dio.get(url);
      final rawData = response.data;

      // Parse list from paginated or flat data
      List<dynamic> list = [];
      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map) {
        final dataField = rawData['data'] ??
            rawData['Data'] ??
            rawData['items'] ??
            rawData['Items'];
        if (dataField is List) {
          list = dataField;
        } else if (dataField is Map) {
          final subData = dataField['data'] ??
              dataField['Data'] ??
              dataField['items'] ??
              dataField['Items'];
          if (subData is List) {
            list = subData;
          }
        } else {
          list = [rawData];
        }
      }

      final resultList = list
          .where((e) => e is Map)
          .map((e) => EligibleScheduleModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      // Format tour names with departure dates for Manager, Admin, and Staff:
      if (isManagerOrAdmin || isStaff) {
        for (var i = 0; i < resultList.length; i++) {
          final item = resultList[i];
          final dateStr =
              '${item.departureDate.day.toString().padLeft(2, '0')}/${item.departureDate.month.toString().padLeft(2, '0')}/${item.departureDate.year}';
          resultList[i] = EligibleScheduleModel(
            scheduleId: item.scheduleId,
            tourName: '${item.tourName} - $dateStr',
            departureDate: item.departureDate,
            returnDate: item.returnDate,
            statusContext: item.statusContext,
          );
        }
      }

      return resultList;
    });
  }

  Future<List<TicketModel>> getMyTickets() async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.tickets}/my-tickets');
      return parseList(response.data, TicketModel.fromJson);
    });
  }

  Future<List<TicketModel>> getTicketsForOrder(int orderId) async {
    final order = await getOrderDetail(orderId);
    return order.tickets;
  }

  Future<List<StaffTicketModel>> getTicketsBySchedule(
    int scheduleId, {
    String? attendeeName,
    String? checkInStatus,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tickets}/schedule/$scheduleId',
        queryParameters: {
          if (attendeeName != null) 'attendeeName': attendeeName,
          if (checkInStatus != null) 'checkInStatus': checkInStatus,
        },
      );
      return (response.data as List)
          .map((e) => StaffTicketModel.fromJson(e))
          .toList();
    });
  }

  Future<CheckInResultModel> checkIn({required String qrCode}) async {
    return request(() async {
      final response = await api.dio.put(
        '${ApiConstants.tickets}/check-in',
        data: {'qrCode': qrCode},
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] as Map<String, dynamic>? ?? body;
        return CheckInResultModel.fromJson(data);
      }
      throw StateError('Unexpected response format for check-in');
    });
  }
}
