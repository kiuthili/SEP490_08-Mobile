import '../utils/json_utils.dart';

class CheckInResultModel {
  final int ticketId;
  final String attendeeName;
  final String ticketTypeName;
  final String checkInStatus;
  final int scheduleId;
  final DateTime departureDate;

  const CheckInResultModel({
    required this.ticketId,
    required this.attendeeName,
    required this.ticketTypeName,
    required this.checkInStatus,
    required this.scheduleId,
    required this.departureDate,
  });

  factory CheckInResultModel.fromJson(Map<String, dynamic> json) =>
      CheckInResultModel(
        ticketId: JsonUtils.readInt(json['ticketId']),
        attendeeName: JsonUtils.readString(json['attendeeName']) ?? '',
        ticketTypeName: JsonUtils.readString(json['ticketTypeName']) ?? '',
        checkInStatus: JsonUtils.readString(json['checkInStatus']) ?? '',
        scheduleId: JsonUtils.readInt(json['scheduleId']),
        departureDate:
        JsonUtils.readDateTime(json['departureDate']) ?? DateTime.now(),
      );
}