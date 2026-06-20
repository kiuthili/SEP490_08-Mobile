import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // debugPrint (chan doan)
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../models/ai_models.dart';
import '../models/feature_models.dart';
import '../models/social_models.dart'; // Đã thêm import này
import 'base_service.dart';
import '../models/map_models.dart';
class SocialService extends GetxService with BaseServiceMixin {
  // ================= USERS & FRIENDS =================
  Future<PaginationModel<UserSearchModel>> searchUsers({required String query, int page = 1, int pageSize = AppConstants.defaultPageSize}) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.users}/search', queryParameters: {'q': query, 'page': page, 'pageSize': pageSize, 'role': 'Customer'});
      return parsePagination(response.data, UserSearchModel.fromJson);
    });
  }

  Future<UserSearchModel> getUserProfile(int id) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.users}/$id/profile');
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] ?? body;
        return UserSearchModel.fromJson(data as Map<String, dynamic>);
      }
      throw StateError('Invalid profile response');
    });
  }

  Future<void> sendFriendRequest(int receiverId) async {
    await request(() async { await api.dio.post(ApiConstants.friends, data: {'receiverId': receiverId}); });
  }

  Future<List<FriendRequestModel>> getPendingRequests() async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.friends}/pending');
      return parseList(response.data, FriendRequestModel.fromJson);
    });
  }

  Future<void> respondFriendRequest({required int requestId, required bool accept}) async {
    await request(() async { await api.dio.put('${ApiConstants.friends}/respond', data: {'requestId': requestId, 'status': accept ? 'Accepted' : 'Declined'}); });
  }

  Future<List<FriendModel>> getFriends() async {
    return request(() async {
      final response = await api.dio.get(ApiConstants.friends);
      return parseList(response.data, FriendModel.fromJson);
    });
  }

  Future<void> unfriend(int friendshipId) async {
    await request(() async { await api.dio.delete('${ApiConstants.friends}/$friendshipId'); });
  }

  // ================= MOMENTS & COMMENTS =================
  Future<List<MomentModel>> getMoments({int? scheduleId, int skip = 0, int top = 20}) async {
    return request(() async {
      final response = await api.dio.get(ApiConstants.moments, queryParameters: {
        if (scheduleId != null) 'scheduleId': scheduleId,
        r'$skip': skip,
        r'$top': top,
      });
      return parseList(response.data, MomentModel.fromJson);
    });
  }

  Future<MomentModel> getMomentById(int momentId) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.moments}/$momentId');
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] ?? body;
        return MomentModel.fromJson(data as Map<String, dynamic>);
      }
      throw StateError('Invalid moment response');
    });
  }

  Future<void> createMoment({required int userId, int? scheduleId, required String imagePath, required double lat, required double lng, String? caption, String privacy = 'Public'}) async {
    await request(() async {
      final formData = FormData.fromMap({
        'UserId': userId,
        if (scheduleId != null) 'ScheduleId': scheduleId,
        'Lat': lat,
        'Lng': lng,
        'Privacy': privacy,
        if (caption != null && caption.isNotEmpty) 'Caption': caption,
        'Image': await MultipartFile.fromFile(imagePath),
      });
      await api.dio.post(ApiConstants.moments, data: formData);
    });
  }

  Future<void> deleteMoment(int momentId, int userId) async {
    await request(() async {
      await api.dio.delete('${ApiConstants.moments}/$momentId', queryParameters: {'userId': userId});
    });
  }

  Future<void> toggleReaction(int momentId, int userId, bool isLike) async {
    await request(() async {
      final payload = {'momentId': momentId, 'userId': userId, 'isLike': isLike, 'type': isLike ? 'Like' : 'None'};
      final resp = await api.dio.post('${ApiConstants.moments}/$momentId/reactions', data: payload);
      // CHẨN ĐOÁN: in payload + kết quả để xác minh BE có nhận đúng userId không.
      debugPrint('[REACTION] POST /moments/$momentId/reactions userId=$userId isLike=$isLike '
          '-> status=${resp.statusCode} body=${resp.data}');
    });
  }

  Future<List<SocialReactionModel>> getMomentReactions(int momentId) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.moments}/$momentId/reactions');
      return parseList(response.data, SocialReactionModel.fromJson);
    });
  }

  Future<SocialCommentModel?> addComment(int momentId, String comment, int userId) async {
    return request(() async {
      // Gửi đủ biến thể field 'comment'/'content'/'text' để khớp CommentRequestDto.
      final payload = {'momentId': momentId, 'userId': userId, 'comment': comment, 'content': comment, 'text': comment};
      final resp = await api.dio.post('${ApiConstants.moments}/$momentId/comments', data: payload);
      debugPrint('[COMMENT] POST /moments/$momentId/comments userId=$userId '
          '-> status=${resp.statusCode} body=${resp.data}');
      if (resp.data != null) {
        return SocialCommentModel.fromJson(resp.data);
      }
      return null;
    });
  }

  Future<List<SocialCommentModel>> getMomentComments(int momentId, {int skip = 0, int top = 50}) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.moments}/$momentId/comments', queryParameters: {r'$skip': skip, r'$top': top});
      return parseList(response.data, SocialCommentModel.fromJson);
    });
  }

  Future<void> updateComment(int commentId, String comment, int userId) async {
    await request(() async {
      // FIX: gửi cả 'comment' lẫn 'content' để khớp CommentRequestDto.
      await api.dio.put('${ApiConstants.moments}/comments/$commentId', data: {'userId': userId, 'comment': comment, 'content': comment});
    });
  }

  Future<void> deleteComment(int commentId, int userId) async {
    await request(() async {
      await api.dio.delete('${ApiConstants.moments}/comments/$commentId', queryParameters: {'userId': userId});
    });
  }

  // ================= CHAT =================
  Future<List<ChatRoomModel>> getChatRooms() async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.chat}/rooms');
      return parseList(response.data, ChatRoomModel.fromJson);
    });
  }

  Future<List<ChatMessageModel>> getChatMessages(int roomId, {int skip = 0, int top = 50}) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.chat}/rooms/$roomId/messages', queryParameters: {'skip': skip, 'top': top});
      return parseList(response.data, ChatMessageModel.fromJson);
    });
  }

  Future<ChatRoomModel> createDirectChat(int friendId) async {
    return request(() async {
      final response = await api.dio.post('${ApiConstants.chat}/rooms', data: {'friendId': friendId});
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] ?? body;
        return ChatRoomModel.fromJson(data as Map<String, dynamic>);
      }
      throw StateError('Invalid chat room response');
    });
  }

  Future<void> leaveChatRoom(int roomId) async {
    await request(() async { await api.dio.delete('${ApiConstants.chat}/rooms/$roomId/leave'); });
  }

  // ================= LOCATION & TRACKING =================
  Future<void> pingLocation({required double lat, required double lng, int? scheduleId}) async {
    await request(() async {
      await api.dio.post('${ApiConstants.locations}/ping', data: {
        'latitude': lat,
        'longitude': lng,
        if (scheduleId != null) 'scheduleId': scheduleId,
      });
    });
  }

  Future<List<LiveLocationModel>> getScheduleLiveLocations(int scheduleId) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.locations}/schedules/$scheduleId/live');
      return parseList(response.data, LiveLocationModel.fromJson);
    });
  }

  Future<String> generateTrackingToken() async {
    return request(() async {
      final response = await api.dio.post('${ApiConstants.locations}/share');
      final body = response.data as Map<String, dynamic>;
      final data = body['data'];
      if (data is String) return data;
      if (data is Map<String, dynamic>) return data['token'] as String? ?? '';
      return '';
    });
  }

  Future<PublicLocationModel> getPublicLocation(String token) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.locations}/track/$token');
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] ?? body;
        if (data is Map<String, dynamic>) return PublicLocationModel.fromJson(data);
      }
      throw StateError('Invalid tracking response');
    });
  }

  // ================= TOUR ROUTE (Polyline) =================
  /// Danh sách các Ngày của lộ trình tour (Day 1, Day 2 ...).
  Future<List<RouteDayModel>> getTourRouteDays(int scheduleId) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tours}/schedules/$scheduleId/itinerary/days',
      );
      return parseList(response.data, RouteDayModel.fromJson);
    });
  }

  /// Toạ độ các điểm đến trong 1 ngày (đã sắp theo thứ tự để nối Polyline).
  Future<List<RoutePointModel>> getTourRoutePoints(
      int scheduleId,
      int dayNumber,
      ) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tours}/schedules/$scheduleId/itinerary/route',
        queryParameters: {'day': dayNumber},
      );
      final points = parseList(response.data, RoutePointModel.fromJson);
      points.sort((a, b) => a.order.compareTo(b.order));
      return points;
    });
  }

  // ================= FOOTPRINTS ("Cào Map") =================
  /// Toàn bộ dấu chân tích luỹ của 1 user để tô vùng đã đi qua.
  Future<List<FootprintDto>> getUserFootprints({
    required int userId,
    DateTime? from,
    DateTime? to,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.locations}/footprints',
        queryParameters: {
          'userId': userId,
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
        },
      );
      return parseList(response.data, FootprintDto.fromJson);
    });
  }

  /// GET /api/locations/friends/live  (token-based)
  Future<List<LiveLocationModel>> getLiveFriendsLocations() async {
    return request(() async {
      final response =
      await api.dio.get('${ApiConstants.locations}/friends/live');
      return parseList(response.data, LiveLocationModel.fromJson);
    });
  }

  // ============ 2) MOMENTS ON MAP (Photo Map) ============
  /// Dùng lại feed moments rồi lọc lat/lng != null ở client.
  /// GET /api/moments?scheduleId=&$skip=&$top=
  Future<List<MomentModel>> getMomentsWithLocation({
    int? scheduleId,
    int top = 200,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        ApiConstants.moments,
        queryParameters: {
          if (scheduleId != null) 'scheduleId': scheduleId,
          r'$skip': 0,
          r'$top': top,
        },
      );
      final all = parseList(response.data, MomentModel.fromJson);
      return all.where((m) => m.lat != null && m.lng != null).toList();
    });
  }

  // ============ 3) LỘ TRÌNH TOUR (Polyline) ============
  /// Lấy toàn bộ điểm lộ trình của 1 schedule; controller tự gom theo ngày.
  /// GET /api/tourschedules/{scheduleId}/itineraries
  /// Trả [{ id, dayNumber, title, locationName, locationLat, locationLng, ... }]
  Future<List<RoutePointModel>> getScheduleItineraries(int scheduleId) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tourSchedules}/$scheduleId/itineraries',
        // Không ném lỗi khi 4xx -> trả rỗng để bản đồ vẫn chạy.
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (response.statusCode != 200) return <RoutePointModel>[];
      return parseList(response.data, RoutePointModel.fromJson);
    });
  }

  // ============ 4) FOOTPRINTS ("Cào Map") ============
  /// GET /api/moments/my-footprints  (token-based, KHÔNG truyền userId)
  Future<List<FootprintDto>> getMyFootprints() async {
    return request(() async {
      final response =
      await api.dio.get('${ApiConstants.moments}/my-footprints');
      return parseList(response.data, FootprintDto.fromJson);
    });
  }

  // ============ 5) HEATMAP ============
  /// ⚠️ Backend HIỆN CHƯA có endpoint heatmap.
  /// Để nguyên hàm này (sẽ ném lỗi/404) — controller bắt lỗi và tự dựng
  /// heatmap client-side từ moments + footprints + live locations.
  /// Khi backend bổ sung (vd GET /api/locations/heatmap) thì hàm này dùng được ngay.
  Future<List<HeatPointModel>> getHeatmapData({int? scheduleId}) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.locations}/heatmap',
        queryParameters: {
          if (scheduleId != null) 'scheduleId': scheduleId,
        },
      );
      return parseList(response.data, HeatPointModel.fromJson);
    });
  }
}