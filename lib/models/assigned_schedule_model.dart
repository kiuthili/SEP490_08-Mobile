import '../utils/json_utils.dart';

class AssignedScheduleModel {
  final int scheduleId;
  final int tourId;
  final DateTime departureDate;
  final DateTime returnDate;
  final String? tourName;
  final String? tourImageUrl;
  final String? assignedRole;

  const AssignedScheduleModel({
    required this.scheduleId,
    required this.tourId,
    required this.departureDate,
    required this.returnDate,
    this.tourName,
    this.tourImageUrl,
    this.assignedRole,
  });

  factory AssignedScheduleModel.fromJson(Map<String, dynamic> json) =>
      AssignedScheduleModel(
        scheduleId: JsonUtils.readInt(json['scheduleId']),
        tourId: JsonUtils.readInt(json['tourId']),
        departureDate: JsonUtils.readDateTime(json['departureDate']) ??
            DateTime.now(),
        returnDate: JsonUtils.readDateTime(json['returnDate']) ??
            DateTime.now(),
        tourName: JsonUtils.readString(json['tourName']),
        tourImageUrl: JsonUtils.readString(json['tourImageUrl']),
        assignedRole: JsonUtils.readString(json['assignedRole']),
      );
}