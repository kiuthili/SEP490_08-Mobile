import '../utils/json_utils.dart';
import '../utils/text_encoding.dart';

class VoucherModel {
  final int id;
  final int voucherId;
  final int? tourId;
  final String? tourName;
  final String code;
  final String? description;
  final int? discountValue;
  final String? discountType;
  final int? maxDiscountAmount;
  final String? status;
  final String? voucherStatus;
  final int quantity;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? expiryDate;

  VoucherModel({
    required this.id,
    required this.voucherId,
    this.tourId,
    this.tourName,
    required this.code,
    this.description,
    this.discountValue,
    this.discountType,
    this.maxDiscountAmount,
    this.status,
    this.voucherStatus,
    required this.quantity,
    required this.isActive,
    this.startDate,
    this.endDate,
    this.expiryDate,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) => VoucherModel(
        id: JsonUtils.readInt(
          JsonUtils.pick(json, ['userVoucherId', 'id']),
        ),
        voucherId: JsonUtils.readInt(
          JsonUtils.pick(json, ['voucherId', 'id']),
        ),
        tourId: () {
          final v = JsonUtils.pick(json, ['tourId', 'TourId']);
          if (v == null) return null;
          final id = JsonUtils.readInt(v);
          return id > 0 ? id : null;
        }(),
        tourName: JsonUtils.readString(
          JsonUtils.pick(json, ['tourName', 'TourName']),
        ),
        code: JsonUtils.readString(json['code']) ?? '',
        description: JsonUtils.readString(json['description']),
        discountValue: () {
          final v = json['discountValue'];
          if (v == null) return null;
          return JsonUtils.readInt(v);
        }(),
        discountType: JsonUtils.readString(json['discountType']),
        maxDiscountAmount: () {
          final v = JsonUtils.pick(json, ['maxDiscountAmount']);
          if (v == null) return null;
          return JsonUtils.readInt(v);
        }(),
        status: JsonUtils.readString(json['status']),
        voucherStatus: JsonUtils.readString(json['voucherStatus']),
        quantity: JsonUtils.readInt(json['quantity'], fallback: 1),
        isActive: JsonUtils.readBool(json['isActive'], fallback: true),
        startDate: JsonUtils.readDateTime(json['startDate']),
        endDate: JsonUtils.readDateTime(json['endDate']),
        expiryDate: JsonUtils.readDateTime(
          JsonUtils.pick(json, ['expiryDate', 'endDate']),
        ),
      );

  bool get isAvailable =>
      isActive &&
      quantity > 0 &&
      (status ?? '').toLowerCase() == 'available' &&
      (voucherStatus == null ||
          voucherStatus!.isEmpty ||
          voucherStatus!.toLowerCase() == 'active');
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
  final String? status;
  final DateTime? createdAt;

  FriendModel({
    required this.friendshipId,
    required this.userId,
    required this.fullName,
    this.email,
    this.avatarUrl,
    this.status,
    this.createdAt,
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
        status: JsonUtils.readString(json['status']),
        createdAt: JsonUtils.readDateTime(json['createdAt']),
      );
}

class FriendRequestModel {
  final int id;
  final int senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? status;
  final DateTime? createdAt;

  FriendRequestModel({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    this.status,
    this.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) =>
      FriendRequestModel(
        id: JsonUtils.readInt(json['id']),
        senderId: JsonUtils.readInt(
          JsonUtils.pick(json, ['senderId', 'fromUserId', 'friendId']),
        ),
        senderName: JsonUtils.readString(
          JsonUtils.pick(json, ['senderName', 'fullName']),
        ),
        senderAvatarUrl: JsonUtils.readString(
          JsonUtils.pick(json, ['senderAvatarUrl', 'avatarUrl']),
        ),
        status: JsonUtils.readString(json['status']),
        createdAt: JsonUtils.readDateTime(json['createdAt']),
      );
}

class UserSearchModel {
  final int id;
  final String fullName;
  final String? email;
  final String? avatarUrl;
  final String? gender;
  final String? dateOfBirth;
  final String? phoneNumber;
  final String? status;
  final DateTime? createdAt;

  UserSearchModel({
    required this.id,
    required this.fullName,
    this.email,
    this.avatarUrl,
    this.gender,
    this.dateOfBirth,
    this.phoneNumber,
    this.status,
    this.createdAt,
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
        gender: JsonUtils.readString(json['gender']),
        dateOfBirth: JsonUtils.readString(json['dateOfBirth']),
        phoneNumber: JsonUtils.readString(json['phoneNumber']),
        status: JsonUtils.readString(json['status']),
        createdAt: JsonUtils.readDateTime(json['createdAt']),
      );
}

class LegacyMomentCommentModel {
  final int id;
  final int userId;
  final String? userName;
  final String content;

  LegacyMomentCommentModel({
    required this.id,
    required this.userId,
    this.userName,
    required this.content,
  });

  factory LegacyMomentCommentModel.fromJson(Map<String, dynamic> json) =>
      LegacyMomentCommentModel(
        id: JsonUtils.readInt(json['id']),
        userId: JsonUtils.readInt(json['userId']),
        userName: JsonUtils.readString(
          JsonUtils.pick(json, ['userName', 'fullName']),
        ),
        content: JsonUtils.readString(json['content']) ?? '',
      );
}

class LegacyMomentModel {
  final int id;
  final int userId;
  final String? userName;
  final String? content;
  final String? imageUrl;
  final DateTime? createdAt;
  final bool hasReacted;
  final int reactionCount;
  final int commentCount;
  final List<LegacyMomentCommentModel> comments;

  LegacyMomentModel({
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

  factory LegacyMomentModel.fromJson(Map<String, dynamic> json) {
    final rawComments = JsonUtils.readMapList(
      JsonUtils.pick(json, ['comments', 'Comments']),
    );
    return LegacyMomentModel(
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
      comments: rawComments.map(LegacyMomentCommentModel.fromJson).toList(),
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
  final DateTime? lastMessageAt;
  final bool isPinned;
  final bool isMuted;
  final int unreadCount;

  ChatRoomModel({
    required this.id,
    this.name,
    this.isGroup = false,
    this.scheduleId,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.isPinned = false,
    this.isMuted = false,
    this.unreadCount = 0,
  });

  ChatRoomModel copyWith({
    int? unreadCount,
  }) =>
      ChatRoomModel(
        id: id,
        name: name,
        isGroup: isGroup,
        scheduleId: scheduleId,
        avatarUrl: avatarUrl,
        lastMessage: lastMessage,
        lastMessageAt: lastMessageAt,
        isPinned: isPinned,
        isMuted: isMuted,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) => ChatRoomModel(
        id: JsonUtils.readInt(JsonUtils.pick(json, ['id', 'Id'])),
        name: _readChatText(
          JsonUtils.pick(json, ['roomName', 'RoomName', 'name', 'Name']),
        ),
        isGroup: JsonUtils.readBool(
          JsonUtils.pick(
            json,
            ['isGroupChat', 'IsGroupChat', 'isGroup', 'group'],
          ),
        ),
        scheduleId: () {
          final v = JsonUtils.pick(json, ['scheduleId', 'ScheduleId']);
          if (v == null) return null;
          return JsonUtils.readInt(v);
        }(),
        avatarUrl: JsonUtils.readString(
          JsonUtils.pick(
            json,
            ['avatarUrl', 'AvatarUrl', 'roomAvatarUrl', 'RoomAvatarUrl'],
          ),
        ),
        lastMessage: _readChatText(
          JsonUtils.pick(
            json,
            ['latestMessage', 'LatestMessage', 'lastMessage'],
          ),
        ),
        lastMessageAt: JsonUtils.readDateTime(
          JsonUtils.pick(
            json,
            ['latestMessageTime', 'LatestMessageTime', 'lastMessageAt'],
          ),
        ),
        isPinned: JsonUtils.readBool(
          JsonUtils.pick(json, ['isPinned', 'IsPinned']),
        ),
        isMuted: JsonUtils.readBool(
          JsonUtils.pick(json, ['isMuted', 'IsMuted']),
        ),
        unreadCount: JsonUtils.readInt(
          JsonUtils.pick(json, ['unreadCount', 'UnreadCount']),
        ),
      );
}

class ChatMessageModel {
  final int id;
  final int chatRoomId;
  final int senderId;
  final String? senderName;
  final String? senderAvatar;
  final String content;
  final bool isRead;
  final DateTime? sentAt;

  ChatMessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.content,
    this.isRead = false,
    this.sentAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      ChatMessageModel(
        id: JsonUtils.readInt(json['id']),
        chatRoomId: JsonUtils.readInt(
          JsonUtils.pick(json, ['chatRoomId', 'ChatRoomId', 'roomId']),
        ),
        senderId: JsonUtils.readInt(
          JsonUtils.pick(json, ['senderId', 'userId']),
        ),
        senderName: _readChatText(
          JsonUtils.pick(json, ['senderName', 'fullName']),
        ),
        senderAvatar: JsonUtils.readString(
          JsonUtils.pick(json, ['senderAvatar', 'SenderAvatar', 'avatarUrl']),
        ),
        content: _readChatText(
                JsonUtils.pick(json, ['content', 'message', 'text'])) ??
            '',
        isRead: JsonUtils.readBool(
          JsonUtils.pick(json, ['isRead', 'IsRead']),
        ),
        sentAt: JsonUtils.readDateTime(
          JsonUtils.pick(json, ['sentAt', 'createdAt', 'timestamp']),
        ),
      );
}

String? _readChatText(dynamic value) {
  final text = JsonUtils.readString(value);
  return text == null ? null : TextEncoding.repairMojibake(text);
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
class SocialReactionModel {
  final int userId;
  final String? userName;
  final String type;

  SocialReactionModel({
    required this.userId,
    this.userName,
    required this.type,
  });

  factory SocialReactionModel.fromJson(Map<String, dynamic> json) => SocialReactionModel(
    userId: JsonUtils.readInt(json['userId']),
    userName: JsonUtils.readString(json['userName']),
    type: JsonUtils.readString(json['type']) ?? '',
  );
}

