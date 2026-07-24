import 'package:stayhub_mobile/models/reviewreply_model.dart';
import '../utils/json_utils.dart';

class ReviewModel {
  final int id;
  final int tourId;
  final int customerId;
  final String? tourName; // ← thêm
  final String? customerName;
  final String? customerAvatar;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final List<ReviewReplyModel> replies;

  ReviewModel({
    required this.id,
    required this.tourId,
    required this.customerId,
    this.tourName,
    this.customerName,
    this.customerAvatar,
    required this.rating,
    this.comment,
    this.createdAt,
    this.replies = const [],
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id: JsonUtils.readInt(json['id']),
        tourId: JsonUtils.readInt(json['tourId']),
        customerId: JsonUtils.readInt(
          JsonUtils.pick(json, ['customerId', 'userId']),
        ),
        tourName: JsonUtils.readString(json['tourName']),
        customerName: JsonUtils.readString(
          JsonUtils.pick(json, ['customerName', 'userName', 'fullName']),
        ),
        customerAvatar: JsonUtils.readString(json['customerAvatar']),
        rating: JsonUtils.readInt(json['rating'], fallback: 5),
        comment: JsonUtils.readString(json['comment']),
        createdAt: JsonUtils.readDateTime(json['createdAt']),
        replies: (json['replies'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ReviewReplyModel.fromJson)
                .toList() ??
            [],
      );
}
