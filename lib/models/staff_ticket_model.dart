import '../utils/json_utils.dart';

class StaffTicketModel {
  final int id;
  final int orderId;
  final int orderDetailId;
  final int? userId;
  final int ticketTypeId;
  final String? ticketTypeName;
  final String attendeeName;
  final String idCard;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? nationality;
  final String? qrCode;
  final String? checkInStatus;

  const StaffTicketModel({
    required this.id,
    required this.orderId,
    required this.orderDetailId,
    this.userId,
    required this.ticketTypeId,
    this.ticketTypeName,
    required this.attendeeName,
    required this.idCard,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.qrCode,
    this.checkInStatus,
  });

  /// Trả về true nếu đã check-in (không phân biệt hoa thường)
  bool get isCheckedIn {
    final s = checkInStatus?.toLowerCase() ?? '';
    return s == 'checkedin' || s == 'checked_in' || s == 'checked';
  }

  factory StaffTicketModel.fromJson(Map<String, dynamic> json) =>
      StaffTicketModel(
        id: JsonUtils.readInt(json['id']),
        orderId: JsonUtils.readInt(json['orderId']),
        orderDetailId: JsonUtils.readInt(json['orderDetailId']),
        userId:
            json['userId'] != null ? JsonUtils.readInt(json['userId']) : null,
        ticketTypeId: JsonUtils.readInt(json['ticketTypeId']),
        ticketTypeName: JsonUtils.readString(json['ticketTypeName']),
        attendeeName: JsonUtils.readString(json['attendeeName']) ?? '',
        idCard: JsonUtils.readString(json['idCard']) ?? '',
        // DateOnly từ C# serialize thành "yyyy-MM-dd", DateTime.tryParse đọc được
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.tryParse(json['dateOfBirth'].toString())
            : null,
        gender: JsonUtils.readString(json['gender']),
        nationality: JsonUtils.readString(json['nationality']),
        qrCode: JsonUtils.readString(json['qrCode']),
        checkInStatus: JsonUtils.readString(json['checkInStatus']),
      );
}
