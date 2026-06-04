class OrderModel {
  final int id;
  final int customerId;
  final int scheduleId;
  final int totalQuantity;
  final int ticketCount;
  final int totalAmount;
  final int? discountValue;
  final String? voucherCode;
  final int finalAmount;
  final String? note;
  final String? status;
  final DateTime? orderedAt;
  final OrderTourInfo? tour;
  final OrderScheduleInfo? schedule;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.scheduleId,
    required this.totalQuantity,
    required this.ticketCount,
    required this.totalAmount,
    this.discountValue,
    this.voucherCode,
    required this.finalAmount,
    this.note,
    this.status,
    this.orderedAt,
    this.tour,
    this.schedule,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as int,
      customerId: json['customerId'] as int? ?? 0,
      scheduleId: json['scheduleId'] as int? ?? 0,
      totalQuantity: json['totalQuantity'] as int? ?? 0,
      ticketCount: json['ticketCount'] as int? ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
      discountValue: (json['discountValue'] as num?)?.toInt(),
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

class ScheduleCustomerModel {
  final int customerId;
  final String? fullName;
  final String? email;
  final String? phoneNumber;
  final int ticketCount;

  ScheduleCustomerModel({
    required this.customerId,
    this.fullName,
    this.email,
    this.phoneNumber,
    required this.ticketCount,
  });

  factory ScheduleCustomerModel.fromJson(Map<String, dynamic> json) {
    return ScheduleCustomerModel(
      customerId: json['customerId'] as int? ?? json['id'] as int? ?? 0,
      fullName: json['fullName'] as String? ?? json['customerName'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      ticketCount: json['ticketCount'] as int? ?? json['totalTickets'] as int? ?? 0,
    );
  }
}

class TicketModel {
  final int id;
  final int orderId;
  final String attendeeName;
  final String idCard;
  final String? qrCode;
  final String? checkInStatus;
  final int ticketTypeId;

  TicketModel({
    required this.id,
    required this.orderId,
    required this.attendeeName,
    required this.idCard,
    this.qrCode,
    this.checkInStatus,
    required this.ticketTypeId,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) => TicketModel(
        id: json['id'] as int,
        orderId: json['orderId'] as int? ?? 0,
        attendeeName: json['attendeeName'] as String? ?? '',
        idCard: json['idCard'] as String? ?? '',
        qrCode: json['qrCode'] as String?,
        checkInStatus: json['checkInStatus'] as String?,
        ticketTypeId: json['ticketTypeId'] as int? ?? 0,
      );
}
