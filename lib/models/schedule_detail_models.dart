import '../utils/json_utils.dart';

class ScheduleCustomerModel {
  final int customerId;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String? phone;

  const ScheduleCustomerModel({
    required this.customerId,
    this.fullName,
    this.email,
    this.avatarUrl,
    this.phone,
  });

  factory ScheduleCustomerModel.fromJson(Map<String, dynamic> json) =>
      ScheduleCustomerModel(
        customerId: JsonUtils.readInt(
          JsonUtils.pick(json, ['customerId', 'userId', 'id']),
        ),
        fullName: JsonUtils.readString(
          JsonUtils.pick(json, ['fullName', 'customerName', 'name']),
        ),
        email: JsonUtils.readString(json['email']),
        avatarUrl: JsonUtils.readString(
          JsonUtils.pick(json, ['avatarUrl', 'avatar']),
        ),
        phone: JsonUtils.readString(
          JsonUtils.pick(json, ['phone', 'phoneNumber']),
        ),
      );
}
