// models/schedule_customer_model.dart
import '../utils/json_utils.dart';

class ScheduleCustomerModel {
  final int ticketId;
  final int orderId;
  final int? userId;
  final String attendeeName;
  final String idCard;
  final String? dateOfBirth;
  final String? gender;
  final String? nationality;
  final String? phoneNumber;

  const ScheduleCustomerModel({
    required this.ticketId,
    required this.orderId,
    this.userId,
    required this.attendeeName,
    required this.idCard,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.phoneNumber,
  });

  factory ScheduleCustomerModel.fromJson(Map<String, dynamic> json) =>
      ScheduleCustomerModel(
        ticketId: JsonUtils.readInt(json['ticketId']),
        orderId: JsonUtils.readInt(json['orderId']),
        userId: () {
          final v = json['userId'];
          if (v == null) return null;
          final id = JsonUtils.readInt(v);
          return id > 0 ? id : null;
        }(),
        attendeeName: JsonUtils.readString(json['attendeeName']) ?? '',
        idCard: JsonUtils.readString(json['idCard']) ?? '',
        dateOfBirth: JsonUtils.readString(json['dateOfBirth']),
        gender: JsonUtils.readString(json['gender']),
        nationality: JsonUtils.readString(json['nationality']),
        phoneNumber: JsonUtils.readString(json['phoneNumber']),
      );

  /// Hiển thị tên + fallback
  String get displayName =>
      attendeeName.trim().isNotEmpty ? attendeeName : 'Hành khách #$ticketId';

  String get genderLabel {
    switch (gender?.toLowerCase()) {
      case 'male':
      case 'nam':
        return 'Nam';
      case 'female':
      case 'nữ':
      case 'nu':
        return 'Nữ';
      default:
        return gender ?? '';
    }
  }
}
