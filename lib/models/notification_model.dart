import 'package:stayhub_mobile/utils/json_utils.dart';

class NotificationModel {
  final int id;
  final String title;
  final String? message;
  final String? type;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    this.message,
    this.type,
    required this.isRead,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: JsonUtils.readInt(json['id']),
      title: JsonUtils.readString(
        JsonUtils.pick(json, ['title', 'subject']),
      ) ??
          '',
      message: JsonUtils.readString(
        JsonUtils.pick(json, ['message', 'content']),
      ),
      type: JsonUtils.readString(json['type']),
      isRead: JsonUtils.readBool(
        JsonUtils.pick(json, ['isRead', 'read']),
      ),
      createdAt: JsonUtils.readDateTime(json['createdAt']),
    );
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}