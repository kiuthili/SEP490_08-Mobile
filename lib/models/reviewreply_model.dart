// models/review_reply_model.dart
import '../utils/json_utils.dart';

class ReviewReplyModel {
  final int id;
  final int reviewId;
  final int userId;
  final String? userName;
  final String? userAvatar;
  final String? content;
  final DateTime? createdAt;

  ReviewReplyModel({
    required this.id,
    required this.reviewId,
    required this.userId,
    this.userName,
    this.userAvatar,
    this.content,
    this.createdAt,
  });

  factory ReviewReplyModel.fromJson(Map<String, dynamic> json) =>
      ReviewReplyModel(
        id: JsonUtils.readInt(json['id']),
        reviewId: JsonUtils.readInt(json['reviewId']),
        userId: JsonUtils.readInt(json['userId']),
        userName: JsonUtils.readString(
          JsonUtils.pick(json, ['userName', 'fullName']),
        ),
        userAvatar: JsonUtils.readString(json['userAvatar']),
        content: JsonUtils.readString(json['content']),
        createdAt: JsonUtils.readDateTime(json['createdAt']),
      );
}