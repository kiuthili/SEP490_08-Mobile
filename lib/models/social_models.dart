import 'dart:convert';
import '../utils/json_utils.dart';

// Model đại diện cho một bài đăng du lịch (Moment)
class MomentModel {
  final int id;
  final int scheduleId;
  final int userId;
  final String? fullName;
  final String? avatarUrl;
  final String imageUrl;
  final String? caption;
  final double? lat;
  final double? lng;
  final String privacy;
  final DateTime createdAt;
  final int reactionCount;
  final bool isLikedByMe;
  final List<SocialCommentModel> comments;

  MomentModel({
    required this.id,
    required this.scheduleId,
    required this.userId,
    this.fullName,
    this.avatarUrl,
    required this.imageUrl,
    this.caption,
    this.lat,
    this.lng,
    required this.privacy,
    required this.createdAt,
    required this.reactionCount,
    required this.isLikedByMe,
    this.comments = const [],
  });

  // ---- Helpers parse an toàn (chấp nhận int/double/string/null) ----
  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  factory MomentModel.fromJson(Map<String, dynamic> json) {
    // Một số API trả thông tin người đăng ở object lồng `user`/`User`.
    final user = (json['user'] ?? json['User']);
    final userMap = user is Map ? Map<String, dynamic>.from(user) : null;

    int pickUserId() {
      final flat = _asInt(json['userId'] ?? json['UserId'] ?? json['authorId']);
      if (flat != 0) return flat;
      if (userMap != null) return _asInt(userMap['id'] ?? userMap['Id']);
      return 0;
    }

    String? pickName() {
      return _asString(json['fullName'] ??
              json['FullName'] ??
              json['userName'] ??
              json['UserName']) ??
          (userMap != null
              ? _asString(
                  userMap['fullName'] ?? userMap['FullName'] ?? userMap['name'])
              : null);
    }

    String? pickAvatar() {
      return _asString(json['avatarUrl'] ?? json['AvatarUrl']) ??
          (userMap != null
              ? _asString(userMap['avatarUrl'] ?? userMap['AvatarUrl'])
              : null);
    }

    DateTime parseCreated() {
      final raw = json['createdAt'] ?? json['CreatedAt'] ?? json['createdDate'];
      if (raw == null) return DateTime.now();
      return JsonUtils.readDateTime(raw) ?? DateTime.now();
    }

    bool pickLiked() {
      final v = json['isLikedByMe'] ?? json['IsLikedByMe'] ?? json['liked'];
      if (v is bool) return v;
      if (v is num) return v != 0;
      return v?.toString().toLowerCase() == 'true';
    }

    return MomentModel(
      id: _asInt(json['id'] ?? json['Id']),
      scheduleId: _asInt(json['scheduleId'] ?? json['ScheduleId']),
      userId: pickUserId(),
      fullName: pickName(),
      avatarUrl: pickAvatar(),
      imageUrl: _asString(json['imageUrl'] ?? json['ImageUrl']) ?? '',
      caption: _asString(json['caption'] ?? json['Caption']),
      lat: _asDouble(json['lat'] ?? json['Lat'] ?? json['latitude']),
      lng: _asDouble(json['lng'] ?? json['Lng'] ?? json['longitude']),
      privacy: _asString(json['privacy'] ?? json['Privacy']) ?? 'Public',
      createdAt: parseCreated(),
      reactionCount: _asInt(json['reactionCount'] ??
          json['ReactionCount'] ??
          json['totalLikes'] ??
          json['TotalLikes'] ??
          json['likeCount']),
      isLikedByMe: pickLiked(),
      comments: ((json['comments'] ?? json['Comments']) is List)
          ? ((json['comments'] ?? json['Comments']) as List)
              .whereType<Map>()
              .map((e) =>
                  SocialCommentModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  /// Ban sao voi mot vai field thay doi (optimistic update like/unlike).
  MomentModel copyWith({
    int? reactionCount,
    bool? isLikedByMe,
    String? caption,
    List<SocialCommentModel>? comments,
  }) {
    return MomentModel(
      id: id,
      scheduleId: scheduleId,
      userId: userId,
      fullName: fullName,
      avatarUrl: avatarUrl,
      imageUrl: imageUrl,
      caption: caption ?? this.caption,
      lat: lat,
      lng: lng,
      privacy: privacy,
      createdAt: createdAt,
      reactionCount: reactionCount ?? this.reactionCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'userId': userId,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'imageUrl': imageUrl,
      'caption': caption,
      'lat': lat,
      'lng': lng,
      'privacy': privacy,
      'createdAt': createdAt.toIso8601String(),
      'reactionCount': reactionCount,
      'isLikedByMe': isLikedByMe,
    };
  }
}

// Model đại diện cho bình luận của Moment
class SocialCommentModel {
  final int id;
  final int momentId;
  final int userId;
  final String? userName;
  final String? avatarUrl;
  final String comment;
  final DateTime timestamp;

  SocialCommentModel({
    required this.id,
    required this.momentId,
    required this.userId,
    this.userName,
    this.avatarUrl,
    required this.comment,
    required this.timestamp,
  });

  SocialCommentModel copyWith({
    int? id,
    int? momentId,
    int? userId,
    String? userName,
    String? avatarUrl,
    String? comment,
    DateTime? timestamp,
  }) {
    return SocialCommentModel(
      id: id ?? this.id,
      momentId: momentId ?? this.momentId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      comment: comment ?? this.comment,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory SocialCommentModel.fromJson(Map<String, dynamic> json) {
    // Comment trong feed có thể lồng user: { id, fullName, avatarUrl }.
    final user = json['user'] ?? json['User'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : null;

    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    return SocialCommentModel(
      id: _asInt(json['id'] ?? json['Id'] ?? json['commentId']),
      momentId: _asInt(json['momentId'] ?? json['MomentId']),
      userId: _asInt(json['userId'] ??
          json['UserId'] ??
          (userMap != null ? (userMap['id'] ?? userMap['Id']) : null)),
      userName: str(json['fullName'] ??
              json['userName'] ??
              json['customerName'] ??
              json['FullName']) ??
          (userMap != null
              ? str(userMap['fullName'] ?? userMap['name'])
              : null),
      avatarUrl: str(json['avatarUrl'] ?? json['AvatarUrl']) ??
          (userMap != null
              ? str(userMap['avatarUrl'] ?? userMap['AvatarUrl'])
              : null),
      // Backend/web dùng 'text'; bản cũ dùng 'comment'/'content'.
      comment: str(json['text'] ??
              json['comment'] ??
              json['Comment'] ??
              json['content']) ??
          '',
      timestamp: JsonUtils.readDateTime(
            json['createdAt'] ??
                json['CreatedAt'] ??
                json['timestamp'] ??
                json['Timestamp']) ??
          DateTime.now(),
    );
  }
}

class FootprintDto {
  final double lat;
  final double lng;
  final DateTime timestamp;

  FootprintDto({required this.lat, required this.lng, required this.timestamp});

  factory FootprintDto.fromJson(Map<String, dynamic> json) {
    return FootprintDto(
      lat: (json['lat'] ?? json['Lat'])?.toDouble() ?? 0.0,
      lng: (json['lng'] ?? json['Lng'])?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}
