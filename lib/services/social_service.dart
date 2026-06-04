import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../models/ai_models.dart';
import '../models/feature_models.dart';
import 'base_service.dart';

class SocialService extends GetxService with BaseServiceMixin {
  Future<PaginationModel<UserSearchModel>> searchUsers({
    required String query,
    int page = 1,
    int pageSize = AppConstants.defaultPageSize,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.users}/search',
        queryParameters: {'q': query, 'page': page, 'pageSize': pageSize},
      );
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
    await request(() async {
      await api.dio.post(
        ApiConstants.friends,
        data: {'receiverId': receiverId},
      );
    });
  }

  Future<List<FriendRequestModel>> getPendingRequests() async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.friends}/pending');
      return parseList(response.data, FriendRequestModel.fromJson);
    });
  }

  Future<void> respondFriendRequest({
    required int requestId,
    required bool accept,
  }) async {
    await request(() async {
      await api.dio.put(
        '${ApiConstants.friends}/respond',
        data: {
          'requestId': requestId,
          'status': accept ? 'Accepted' : 'Declined',
        },
      );
    });
  }

  Future<PaginationModel<FriendModel>> getFriends({
    int page = 1,
    int pageSize = AppConstants.defaultPageSize,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.friends}/list',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return parsePagination(response.data, FriendModel.fromJson);
    });
  }

  Future<void> unfriend(int friendshipId) async {
    await request(() async {
      await api.dio.delete('${ApiConstants.friends}/$friendshipId');
    });
  }

  Future<List<MomentModel>> getMoments({
    int? scheduleId,
    int skip = 0,
    int top = 20,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        ApiConstants.moments,
        queryParameters: {
          if (scheduleId != null) 'scheduleId': scheduleId,
          r'$skip': skip,
          r'$top': top,
        },
      );
      return parseList(response.data, MomentModel.fromJson);
    });
  }

  Future<void> createMoment({
    required int userId,
    required int scheduleId,
    required String imagePath,
    required double lat,
    required double lng,
    String? caption,
    String privacy = 'Public',
  }) async {
    await request(() async {
      final formData = FormData.fromMap({
        'UserId': userId,
        'ScheduleId': scheduleId,
        'Lat': lat,
        'Lng': lng,
        'Privacy': privacy,
        if (caption != null && caption.isNotEmpty) 'Caption': caption,
        'Image': await MultipartFile.fromFile(imagePath),
      });
      await api.dio.post(ApiConstants.moments, data: formData);
    });
  }

  Future<void> toggleReaction(int momentId, int userId) async {
    await request(() async {
      await api.dio.post(
        '${ApiConstants.moments}/$momentId/reactions',
        data: {'userId': userId, 'isLike': true},
      );
    });
  }

  Future<void> addComment(int momentId, String comment, int userId) async {
    await request(() async {
      await api.dio.post(
        '${ApiConstants.moments}/$momentId/comments',
        data: {'userId': userId, 'comment': comment},
      );
    });
  }

  Future<void> updateComment(int commentId, String comment, int userId) async {
    await request(() async {
      await api.dio.put(
        '${ApiConstants.moments}/comments/$commentId',
        data: {'userId': userId, 'comment': comment},
      );
    });
  }

  Future<void> deleteComment(int commentId, int userId) async {
    await request(() async {
      await api.dio.delete(
        '${ApiConstants.moments}/comments/$commentId',
        queryParameters: {'userId': userId},
      );
    });
  }

  Future<void> deleteMoment(int momentId, int userId) async {
    await request(() async {
      await api.dio.delete(
        '${ApiConstants.moments}/$momentId',
        queryParameters: {'userId': userId},
      );
    });
  }

  Future<List<ChatRoomModel>> getChatRooms() async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.chat}/rooms');
      return parseList(response.data, ChatRoomModel.fromJson);
    });
  }

  Future<List<ChatMessageModel>> getChatMessages(
    int roomId, {
    int skip = 0,
    int top = 50,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.chat}/rooms/$roomId/messages',
        queryParameters: {'skip': skip, 'top': top},
      );
      return parseList(response.data, ChatMessageModel.fromJson);
    });
  }

  Future<ChatRoomModel> createDirectChat(int friendId) async {
    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.chat}/rooms',
        data: {'friendId': friendId},
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] ?? body;
        return ChatRoomModel.fromJson(data as Map<String, dynamic>);
      }
      throw StateError('Invalid chat room response');
    });
  }

  Future<ChatRoomModel> addMembersToRoom(int roomId, List<int> userIds) async {
    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.chat}/rooms/$roomId/members',
        data: {'userIds': userIds},
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] ?? body;
        return ChatRoomModel.fromJson(data as Map<String, dynamic>);
      }
      throw StateError('Invalid response');
    });
  }

  Future<void> leaveChatRoom(int roomId) async {
    await request(() async {
      await api.dio.delete('${ApiConstants.chat}/rooms/$roomId/leave');
    });
  }

  Future<void> pingLocation({
    required double lat,
    required double lng,
    int? scheduleId,
  }) async {
    await request(() async {
      await api.dio.post(
        '${ApiConstants.locations}/ping',
        data: {
          'lat': lat,
          'lng': lng,
          if (scheduleId != null) 'scheduleId': scheduleId,
        },
      );
    });
  }

  Future<List<LiveLocationModel>> getScheduleLiveLocations(
    int scheduleId,
  ) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.locations}/schedules/$scheduleId/live',
      );
      return parseList(response.data, LiveLocationModel.fromJson);
    });
  }

  Future<String> shareLocation() async {
    return request(() async {
      final response = await api.dio.post('${ApiConstants.locations}/share');
      final body = response.data as Map<String, dynamic>;
      final data = body['data'];
      if (data is String) return data;
      if (data is Map<String, dynamic>) {
        return data['token'] as String? ?? '';
      }
      return '';
    });
  }

  /// Vị trí công khai qua token chia sẻ (không cần đăng nhập).
  Future<PublicLocationModel> getPublicLocation(String token) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.locations}/track/$token',
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] ?? body;
        if (data is Map<String, dynamic>) {
          return PublicLocationModel.fromJson(data);
        }
      }
      throw StateError('Invalid tracking response');
    });
  }
}
