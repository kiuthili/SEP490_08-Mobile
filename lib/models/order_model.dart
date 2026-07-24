class OrderModel {
  final int id;
  final int customerId;
  final int scheduleId;
  final int totalQuantity;
  final int ticketCount;
  final int totalAmount;
  final int? discountValue;
  final int? promotionDiscountValue;
  final String? voucherCode;
  final int finalAmount;
  final String? note;
  final String? status;
  final DateTime? orderedAt;
  final OrderTourInfo? tour;
  final OrderScheduleInfo? schedule;
  final List<OrderDetailModel> orderDetails;
  final List<TicketModel> tickets;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.scheduleId,
    required this.totalQuantity,
    required this.ticketCount,
    required this.totalAmount,
    this.discountValue,
    this.promotionDiscountValue,
    this.voucherCode,
    required this.finalAmount,
    this.note,
    this.status,
    this.orderedAt,
    this.tour,
    this.schedule,
    this.orderDetails = const [],
    this.tickets = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final orderDetails = _readMapList(json['orderDetails'])
        .map(OrderDetailModel.fromJson)
        .toList();
    final detailTickets =
        orderDetails.expand((detail) => detail.tickets).toList();
    final topLevelTickets =
        _readMapList(json['tickets']).map(TicketModel.fromJson).toList();
    final tickets = detailTickets.isNotEmpty ? detailTickets : topLevelTickets;

    return OrderModel(
      id: json['id'] as int,
      customerId: json['customerId'] as int? ?? 0,
      scheduleId: json['scheduleId'] as int? ?? 0,
      totalQuantity: json['totalQuantity'] as int? ?? 0,
      ticketCount: json['ticketCount'] as int? ?? tickets.length,
      totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
      discountValue: (json['discountValue'] as num?)?.toInt(),
      promotionDiscountValue: (json['promotionDiscountValue'] as num?)?.toInt(),
      voucherCode: json['voucherCode'] as String?,
      finalAmount: (json['finalAmount'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
      status: json['status'] as String?,
      orderedAt: json['orderedAt'] != null
          ? DateTime.tryParse(json['orderedAt'].toString())
          : null,
      tour: json['tour'] != null
          ? OrderTourInfo.fromJson(json['tour'] as Map<String, dynamic>)
          : null,
      schedule: json['schedule'] != null
          ? OrderScheduleInfo.fromJson(json['schedule'] as Map<String, dynamic>)
          : null,
      orderDetails: orderDetails,
      tickets: tickets,
    );
  }
}

List<Map<String, dynamic>> _readMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class OrderDetailModel {
  final int id;
  final int orderId;
  final int ticketTypeId;
  final int tourScheduleTicketId;
  final int quantity;
  final int unitPrice;
  final int totalPrice;
  final int? promotionDiscountValue;
  final List<TicketModel> tickets;

  OrderDetailModel({
    required this.id,
    required this.orderId,
    required this.ticketTypeId,
    required this.tourScheduleTicketId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.promotionDiscountValue,
    this.tickets = const [],
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    final detailId = (json['id'] as num?)?.toInt() ?? 0;
    final orderId = (json['orderId'] as num?)?.toInt();
    final ticketTypeId = (json['ticketTypeId'] as num?)?.toInt() ?? 0;

    return OrderDetailModel(
      id: detailId,
      orderId: orderId ?? 0,
      ticketTypeId: ticketTypeId,
      tourScheduleTicketId:
          (json['tourScheduleTicketId'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
      totalPrice: (json['totalPrice'] as num?)?.toInt() ?? 0,
      promotionDiscountValue: (json['promotionDiscountValue'] as num?)?.toInt(),
      tickets: _readMapList(json['tickets'])
          .map(
            (ticket) => TicketModel.fromJson(
              ticket,
              fallbackOrderId: orderId,
              fallbackOrderDetailId: detailId,
              fallbackTicketTypeId: ticketTypeId,
            ),
          )
          .toList(),
    );
  }
}

class OrderTourInfo {
  final int id;
  final String name;
  final String? imageUrl;
  final String? city;
  final String? country;

  OrderTourInfo({
    required this.id,
    required this.name,
    this.imageUrl,
    this.city,
    this.country,
  });

  factory OrderTourInfo.fromJson(Map<String, dynamic> json) => OrderTourInfo(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        city: json['city'] as String?,
        country: json['country'] as String?,
      );
}

class OrderScheduleInfo {
  final int id;
  final DateTime departureDate;
  final DateTime returnDate;

  OrderScheduleInfo({
    required this.id,
    required this.departureDate,
    required this.returnDate,
  });

  factory OrderScheduleInfo.fromJson(Map<String, dynamic> json) =>
      OrderScheduleInfo(
        id: json['id'] as int,
        departureDate: DateTime.parse(json['departureDate'].toString()),
        returnDate: DateTime.parse(json['returnDate'].toString()),
      );
}



class TicketModel {
  final int id;
  final int? orderId;
  final int orderDetailId;
  final String attendeeName;
  final String idCard;
  final String? qrCode;
  final String? checkInStatus;
  final int ticketTypeId;

  TicketModel({
    required this.id,
    this.orderId,
    required this.orderDetailId,
    required this.attendeeName,
    required this.idCard,
    this.qrCode,
    this.checkInStatus,
    required this.ticketTypeId,
  });

  factory TicketModel.fromJson(
    Map<String, dynamic> json, {
    int? fallbackOrderId,
    int? fallbackOrderDetailId,
    int? fallbackTicketTypeId,
  }) =>
      TicketModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        orderId: (json['orderId'] as num?)?.toInt() ?? fallbackOrderId,
        orderDetailId: (json['orderDetailId'] as num?)?.toInt() ??
            fallbackOrderDetailId ??
            0,
        attendeeName: json['attendeeName'] as String? ?? '',
        idCard: json['idCard'] as String? ?? '',
        qrCode: json['qrCode'] as String?,
        checkInStatus: json['checkInStatus'] as String?,
        ticketTypeId: (json['ticketTypeId'] as num?)?.toInt() ??
            fallbackTicketTypeId ??
            0,
      );
}
