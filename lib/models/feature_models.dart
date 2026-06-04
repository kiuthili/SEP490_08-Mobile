import '../utils/json_utils.dart';

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
}

class VoucherModel {
  final int id;
  final String code;
  final String? description;
  final int? discountValue;
  final String? discountType;
  final String? status;
  final DateTime? expiryDate;

  VoucherModel({
    required this.id,
    required this.code,
    this.description,
    this.discountValue,
    this.discountType,
    this.status,
    this.expiryDate,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) => VoucherModel(
        id: JsonUtils.readInt(
          JsonUtils.pick(json, ['id', 'voucherId']),
        ),
        code: JsonUtils.readString(json['code']) ?? '',
        description: JsonUtils.readString(json['description']),
        discountValue: () {
          final v = json['discountValue'];
          if (v == null) return null;
          return JsonUtils.readInt(v);
        }(),
        discountType: JsonUtils.readString(json['discountType']),
        status: JsonUtils.readString(json['status']),
        expiryDate: JsonUtils.readDateTime(json['expiryDate']),
      );
}

class ReviewModel {
  final int id;
  final int tourId;
  final int customerId;
  final String? customerName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  ReviewModel({
    required this.id,
    required this.tourId,
    required this.customerId,
    this.customerName,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id: JsonUtils.readInt(json['id']),
        tourId: JsonUtils.readInt(json['tourId']),
        customerId: JsonUtils.readInt(
          JsonUtils.pick(json, ['customerId', 'userId']),
        ),
        customerName: JsonUtils.readString(
          JsonUtils.pick(json, ['customerName', 'userName', 'fullName']),
        ),
        rating: JsonUtils.readInt(json['rating'], fallback: 5),
        comment: JsonUtils.readString(json['comment']),
        createdAt: JsonUtils.readDateTime(json['createdAt']),
      );
}

/// API: ReadWishlistItemDTO — tourId, tourName, tourImageUrl (không có nested tour).
class WishlistItemModel {
  final int tourId;
  final TourWishlistInfo tour;
  final DateTime? addedAt;

  WishlistItemModel({
    required this.tourId,
    required this.tour,
    this.addedAt,
  });

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    final flatName = JsonUtils.readString(
      JsonUtils.pick(json, ['tourName', 'TourName']),
    );
    if (flatName != null && flatName.isNotEmpty) {
      final tourId = JsonUtils.readInt(
        JsonUtils.pick(json, ['tourId', 'TourId']),
      );
      return WishlistItemModel(
        tourId: tourId,
        tour: TourWishlistInfo(
          id: tourId,
          name: flatName,
          imageUrl: JsonUtils.readString(
            JsonUtils.pick(json, ['tourImageUrl', 'TourImageUrl']),
          ),
          city: null,
          averageStar: null,
        ),
        addedAt: JsonUtils.readDateTime(
          JsonUtils.pick(json, ['addedAt', 'createdAt']),
        ),
      );
    }

    final tourJson = json['tour'] as Map<String, dynamic>? ?? json;
    final tourId = JsonUtils.readInt(
      JsonUtils.pick(json, ['tourId', 'TourId']) ??
          JsonUtils.pick(tourJson, ['id', 'tourId']),
    );
    return WishlistItemModel(
      tourId: tourId,
      tour: TourWishlistInfo.fromJson(tourJson),
      addedAt: JsonUtils.readDateTime(
        JsonUtils.pick(json, ['addedAt', 'createdAt']),
      ),
    );
  }
}

class TourWishlistInfo {
  final int id;
  final String name;
  final String? imageUrl;
  final String? city;
  final double? averageStar;

  TourWishlistInfo({
    required this.id,
    required this.name,
    this.imageUrl,
    this.city,
    this.averageStar,
  });

  factory TourWishlistInfo.fromJson(Map<String, dynamic> json) =>
      TourWishlistInfo(
        id: JsonUtils.readInt(
          JsonUtils.pick(json, ['id', 'tourId', 'TourId']),
        ),
        name: JsonUtils.readString(
              JsonUtils.pick(json, ['name', 'tourName', 'TourName']),
            ) ??
            '',
        imageUrl: JsonUtils.readString(
          JsonUtils.pick(json, ['imageUrl', 'tourImageUrl', 'TourImageUrl']),
        ),
        city: JsonUtils.readString(json['city']),
        averageStar: JsonUtils.readDouble(
          JsonUtils.pick(json, ['averageStar', 'AverageStar']),
        ),
      );
}

class FriendModel {
  final int friendshipId;
  final int userId;
  final String fullName;
  final String? email;
  final String? avatarUrl;

  FriendModel({
    required this.friendshipId,
    required this.userId,
    required this.fullName,
    this.email,
    this.avatarUrl,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) => FriendModel(
        friendshipId: JsonUtils.readInt(
          JsonUtils.pick(json, ['friendshipId', 'id']),
        ),
        userId: JsonUtils.readInt(
          JsonUtils.pick(json, ['userId', 'friendId', 'friendUserId']),
        ),
        fullName: JsonUtils.readString(
              JsonUtils.pick(json, ['fullName', 'friendName', 'name']),
            ) ??
            '',
        email: JsonUtils.readString(json['email']),
        avatarUrl: JsonUtils.readString(
          JsonUtils.pick(json, ['avatarUrl', 'friendAvatarUrl']),
        ),
      );
}

class FriendRequestModel {
  final int id;
  final int senderId;
  final String? senderName;
  final String? status;

  FriendRequestModel({
    required this.id,
    required this.senderId,
    this.senderName,
    this.status,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) =>
      FriendRequestModel(
        id: JsonUtils.readInt(json['id']),
        senderId: JsonUtils.readInt(
          JsonUtils.pick(json, ['senderId', 'fromUserId']),
        ),
        senderName: JsonUtils.readString(
          JsonUtils.pick(json, ['senderName', 'fullName']),
        ),
        status: JsonUtils.readString(json['status']),
      );
}

class UserSearchModel {
  final int id;
  final String fullName;
  final String? email;
  final String? avatarUrl;

  UserSearchModel({
    required this.id,
    required this.fullName,
    this.email,
    this.avatarUrl,
  });

  factory UserSearchModel.fromJson(Map<String, dynamic> json) =>
      UserSearchModel(
        id: JsonUtils.readInt(json['id']),
        fullName: JsonUtils.readString(
              JsonUtils.pick(json, ['fullName', 'name']),
            ) ??
            '',
        email: JsonUtils.readString(json['email']),
        avatarUrl: JsonUtils.readString(json['avatarUrl']),
      );
}

class MomentCommentModel {
  final int id;
  final int userId;
  final String? userName;
  final String content;

  MomentCommentModel({
    required this.id,
    required this.userId,
    this.userName,
    required this.content,
  });

  factory MomentCommentModel.fromJson(Map<String, dynamic> json) =>
      MomentCommentModel(
        id: JsonUtils.readInt(json['id']),
        userId: JsonUtils.readInt(json['userId']),
        userName: JsonUtils.readString(
          JsonUtils.pick(json, ['userName', 'fullName']),
        ),
        content: JsonUtils.readString(json['content']) ?? '',
      );
}

class MomentModel {
  final int id;
  final int userId;
  final String? userName;
  final String? content;
  final String? imageUrl;
  final DateTime? createdAt;
  final bool hasReacted;
  final int reactionCount;
  final int commentCount;
  final List<MomentCommentModel> comments;

  MomentModel({
    required this.id,
    required this.userId,
    this.userName,
    this.content,
    this.imageUrl,
    this.createdAt,
    this.hasReacted = false,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.comments = const [],
  });

  factory MomentModel.fromJson(Map<String, dynamic> json) {
    final rawComments = JsonUtils.readMapList(
      JsonUtils.pick(json, ['comments', 'Comments']),
    );
    return MomentModel(
      id: JsonUtils.readInt(json['id']),
      userId: JsonUtils.readInt(json['userId']),
      userName: JsonUtils.readString(
        JsonUtils.pick(json, ['userName', 'fullName']),
      ),
      content: JsonUtils.readString(
        JsonUtils.pick(json, ['content', 'caption', 'Caption']),
      ),
      imageUrl: JsonUtils.readString(
        JsonUtils.pick(json, ['imageUrl', 'ImageUrl']),
      ),
      createdAt: JsonUtils.readDateTime(json['createdAt']),
      hasReacted: JsonUtils.readBool(
        JsonUtils.pick(json, ['hasReacted', 'isLiked', 'liked']),
      ),
      reactionCount: JsonUtils.readInt(
        JsonUtils.pick(json, ['reactionCount', 'likeCount']),
      ),
      commentCount: JsonUtils.readInt(
        JsonUtils.pick(json, ['commentCount', 'commentsCount']),
      ),
      comments: rawComments
          .map(MomentCommentModel.fromJson)
          .toList(),
    );
  }
}

class ChatRoomModel {
  final int id;
  final String? name;
  final bool isGroup;
  final int? scheduleId;
  final String? avatarUrl;
  final String? lastMessage;

  ChatRoomModel({
    required this.id,
    this.name,
    this.isGroup = false,
    this.scheduleId,
    this.avatarUrl,
    this.lastMessage,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) => ChatRoomModel(
        id: JsonUtils.readInt(json['id']),
        name: JsonUtils.readString(json['name']),
        isGroup: JsonUtils.readBool(
          JsonUtils.pick(json, ['isGroup', 'group']),
        ),
        scheduleId: () {
          final v = JsonUtils.pick(json, ['scheduleId', 'ScheduleId']);
          if (v == null) return null;
          return JsonUtils.readInt(v);
        }(),
        avatarUrl: JsonUtils.readString(
          JsonUtils.pick(json, ['avatarUrl', 'roomAvatarUrl']),
        ),
        lastMessage: JsonUtils.readString(
          JsonUtils.pick(json, ['lastMessage', 'latestMessage']),
        ),
      );
}

class ChatMessageModel {
  final int id;
  final int senderId;
  final String? senderName;
  final String content;
  final DateTime? sentAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.content,
    this.sentAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      ChatMessageModel(
        id: JsonUtils.readInt(json['id']),
        senderId: JsonUtils.readInt(
          JsonUtils.pick(json, ['senderId', 'userId']),
        ),
        senderName: JsonUtils.readString(
          JsonUtils.pick(json, ['senderName', 'fullName']),
        ),
        content: JsonUtils.readString(
              JsonUtils.pick(json, ['content', 'message', 'text']),
            ) ??
            '',
        sentAt: JsonUtils.readDateTime(
          JsonUtils.pick(json, ['sentAt', 'createdAt', 'timestamp']),
        ),
      );
}

class LiveLocationModel {
  final int userId;
  final String? fullName;
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  LiveLocationModel({
    required this.userId,
    this.fullName,
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  });

  factory LiveLocationModel.fromJson(Map<String, dynamic> json) =>
      LiveLocationModel(
        userId: JsonUtils.readInt(
          JsonUtils.pick(json, ['userId', 'customerId']),
        ),
        fullName: JsonUtils.readString(
          JsonUtils.pick(json, ['fullName', 'userName']),
        ),
        latitude: JsonUtils.readDouble(
              JsonUtils.pick(json, ['latitude', 'lat', 'Lat']),
            ) ??
            0,
        longitude: JsonUtils.readDouble(
              JsonUtils.pick(json, ['longitude', 'lng', 'Lng']),
            ) ??
            0,
        updatedAt: JsonUtils.readDateTime(
          JsonUtils.pick(json, ['updatedAt', 'lastSeen']),
        ),
      );
}

class EligibleScheduleModel {
  final int scheduleId;
  final String tourName;
  final DateTime departureDate;
  final DateTime returnDate;
  final String statusContext;

  EligibleScheduleModel({
    required this.scheduleId,
    required this.tourName,
    required this.departureDate,
    required this.returnDate,
    required this.statusContext,
  });

  factory EligibleScheduleModel.fromJson(Map<String, dynamic> json) =>
      EligibleScheduleModel(
        scheduleId: JsonUtils.readInt(
          JsonUtils.pick(json, ['scheduleId', 'ScheduleId', 'id']),
        ),
        tourName: JsonUtils.readString(
              JsonUtils.pick(json, ['tourName', 'TourName']),
            ) ??
            '',
        departureDate: JsonUtils.readDateTime(
              JsonUtils.pick(json, ['departureDate', 'DepartureDate']),
            ) ??
            DateTime.now(),
        returnDate: JsonUtils.readDateTime(
              JsonUtils.pick(json, ['returnDate', 'ReturnDate']),
            ) ??
            DateTime.now(),
        statusContext: JsonUtils.readString(
              JsonUtils.pick(json, ['statusContext', 'StatusContext']),
            ) ??
            '',
      );
}
