// import 'package:dio/dio.dart';
// import 'package:get/get.dart' hide FormData, MultipartFile;
// import '../constants/api_constants.dart';
// import '../constants/app_constants.dart';
// import '../models/ai_models.dart';
// import '../models/feature_models.dart';
// import '../models/social_models.dart';
// import 'base_service.dart';
//
// /// Complete SocialService with all moments and location tracking endpoints
// class SocialService extends GetxService with BaseServiceMixin {
//   // ======================== USER SEARCH & PROFILE ========================
//
//   Future<PaginationModel<UserSearchModel>> searchUsers({
//     required String query,
//     int page = 1,
//     int pageSize = AppConstants.defaultPageSize,
//   }) async {
//     return request(() async {
//       final response = await api.dio.get(
//         '${ApiConstants.users}/search',
//         queryParameters: {
//           'query': query,
//           'page': page,
//           'pageSize': pageSize,
//         },
//       );
//       return parsePagination(response.data, UserSearchModel.fromJson);
//     });
//   }
//
//   Future<UserSearchModel> getUserProfile(int id) async {
//     return request(() async {
//       final response = await api.dio.get('${ApiConstants.users}/$id/profile');
//       final body = response.data;
//       if (body is Map<String, dynamic>) {
//         return UserSearchModel.fromJson(body);
//       }
//       throw StateError('Invalid profile response');
//     });
//   }
//
//   // ======================== FRIEND MANAGEMENT ========================
//
//   Future<void> sendFriendRequest(int receiverId) async {
//     await request(() async {
//       await api.dio.post(
//         '${ApiConstants.friends}/request',
//         data: {'receiverId': receiverId},
//       );
//     });
//   }
//
//   Future<List<FriendRequestModel>> getPendingRequests() async {
//     return request(() async {
//       final response = await api.dio.get('${ApiConstants.friends}/pending');
//       return parseList(response.data, FriendRequestModel.fromJson);
//     });
//   }
//
//   Future<void> respondFriendRequest({
//     required int requestId,
//     required bool accept,
//   }) async {
//     await request(() async {
//       await api.dio.put(
//         '${ApiConstants.friends}/request/$requestId',
//         data: {'accept': accept},
//       );
//     });
//   }
//
//   Future<List<FriendModel>> getFriends() async {
//     return request(() async {
//       final response = await api.dio.get(ApiConstants.friends);
//       return parseList(response.data, FriendModel.fromJson);
//     });
//   }
//
//   Future<void> unfriend(int friendshipId) async {
//     await request(() async {
//       await api.dio.delete('${ApiConstants.friends}/$friendshipId');
//     });
//   }
//
//   // ======================== MOMENTS - FEED & DETAIL ========================
//
//   /// Get moments feed with optional schedule filter
//   /// API: GET /api/moments?scheduleId={id}&$skip={skip}&$top={top}
//   Future<List<MomentModel>> getMoments({
//     int? scheduleId,
//     int skip = 0,
//     int top = 20,
//   }) async {
//     return request(() async {
//       final params = {
//         '\$skip': skip,
//         '\$top': top,
//       };
//       if (scheduleId != null) {
//         params['scheduleId'] = scheduleId;
//       }
//
//       final response = await api.dio.get(
//         ApiConstants.moments,
//         queryParameters: params,
//       );
//       return parseList(response.data, MomentModel.fromJson);
//     });
//   }
//
//   /// Get user's moments
//   /// API: GET /api/moments/user/{targetUserId}
//   Future<List<MomentModel>> getUserMoments(int targetUserId) async {
//     return request(() async {
//       final response =
//           await api.dio.get('${ApiConstants.moments}/user/$targetUserId');
//       return parseList(response.data, MomentModel.fromJson);
//     });
//   }
//
//   /// Get my footprints (location history)
//   /// API: GET /api/moments/my-footprints
//   Future<List<FootprintDto>> getMyFootprints() async {
//     return request(() async {
//       final response =
//           await api.dio.get('${ApiConstants.moments}/my-footprints');
//       return parseList(response.data, FootprintDto.fromJson);
//     });
//   }
//
//   // ======================== MOMENTS - CREATE ========================
//
//   /// Create a new moment
//   /// API: POST /api/moments (FormData)
//   Future<MomentModel> createMoment({
//     required int scheduleId,
//     required String imagePath,
//     required double lat,
//     required double lng,
//     String? caption,
//     String privacy = 'Public',
//   }) async {
//     return request(() async {
//       final formData = FormData.fromMap({
//         'scheduleId': scheduleId,
//         'caption': caption ?? '',
//         'lat': lat,
//         'lng': lng,
//         'privacy': privacy,
//         'image': await MultipartFile.fromFile(imagePath),
//       });
//
//       final response = await api.dio.post(
//         ApiConstants.moments,
//         data: formData,
//       );
//
//       final body = response.data;
//       if (body is Map<String, dynamic>) {
//         return MomentModel.fromJson(body);
//       }
//       throw StateError('Invalid moment creation response');
//     });
//   }
//
//   // ======================== MOMENTS - REACTIONS (LIKES) ========================
//
//   /// Toggle reaction on a moment
//   /// API: POST /api/moments/{id}/reactions
//   /// Body: { "isLike": true/false }
//   Future<void> toggleReaction(int momentId, bool isLike) async {
//     await request(() async {
//       await api.dio.post(
//         '${ApiConstants.moments}/$momentId/reactions',
//         data: {'isLike': isLike},
//       );
//     });
//   }
//
//   // ======================== MOMENTS - COMMENTS ========================
//
//   /// Add comment to moment
//   /// API: POST /api/moments/{id}/comments
//   Future<SocialCommentModel> addComment(
//     int momentId,
//     String content,
//   ) async {
//     return request(() async {
//       final response = await api.dio.post(
//         '${ApiConstants.moments}/$momentId/comments',
//         data: {'content': content},
//       );
//
//       final body = response.data;
//       if (body is Map<String, dynamic>) {
//         return SocialCommentModel.fromJson(body);
//       }
//       throw StateError('Invalid comment response');
//     });
//   }
//
//   /// Update existing comment
//   /// API: PUT /api/moments/comments/{cId}
//   Future<void> updateComment(int commentId, String content) async {
//     await request(() async {
//       await api.dio.put(
//         '${ApiConstants.moments}/comments/$commentId',
//         data: {'content': content},
//       );
//     });
//   }
//
//   /// Delete comment
//   /// API: DELETE /api/moments/comments/{cId}?userId={userId}
//   Future<void> deleteComment(int commentId, int userId) async {
//     await request(() async {
//       await api.dio.delete(
//         '${ApiConstants.moments}/comments/$commentId',
//         queryParameters: {'userId': userId},
//       );
//     });
//   }
//
//   // ======================== MOMENTS - DELETE ========================
//
//   /// Delete moment
//   /// API: DELETE /api/moments/{id}?userId={userId}
//   Future<void> deleteMoment(int momentId, int userId) async {
//     await request(() async {
//       await api.dio.delete(
//         '${ApiConstants.moments}/$momentId',
//         queryParameters: {'userId': userId},
//       );
//     });
//   }
//
//   // ======================== CHAT ROOMS & MESSAGES ========================
//
//   Future<List<ChatRoomModel>> getChatRooms() async {
//     return request(() async {
//       final response = await api.dio.get('${ApiConstants.chat}/rooms');
//       return parseList(response.data, ChatRoomModel.fromJson);
//     });
//   }
//
//   Future<List<ChatMessageModel>> getChatMessages(
//     int roomId, {
//     int skip = 0,
//     int top = 50,
//   }) async {
//     return request(() async {
//       final response = await api.dio.get(
//         '${ApiConstants.chat}/rooms/$roomId/messages',
//         queryParameters: {
//           '\$skip': skip,
//           '\$top': top,
//         },
//       );
//       return parseList(response.data, ChatMessageModel.fromJson);
//     });
//   }
//
//   Future<ChatRoomModel> createDirectChat(int friendId) async {
//     return request(() async {
//       final response = await api.dio.post(
//         '${ApiConstants.chat}/rooms/direct',
//         data: {'friendId': friendId},
//       );
//
//       final body = response.data;
//       if (body is Map<String, dynamic>) {
//         return ChatRoomModel.fromJson(body);
//       }
//       throw StateError('Invalid chat room response');
//     });
//   }
//
//   Future<ChatRoomModel> addMembersToRoom(int roomId, List<int> userIds) async {
//     return request(() async {
//       final response = await api.dio.post(
//         '${ApiConstants.chat}/rooms/$roomId/members',
//         data: {'userIds': userIds},
//       );
//
//       final body = response.data;
//       if (body is Map<String, dynamic>) {
//         return ChatRoomModel.fromJson(body);
//       }
//       throw StateError('Invalid response');
//     });
//   }
//
//   Future<void> leaveChatRoom(int roomId) async {
//     await request(() async {
//       await api.dio.delete('${ApiConstants.chat}/rooms/$roomId/leave');
//     });
//   }
//
//   // ======================== LOCATIONS - TRACKING ========================
//
//   /// Ping user location
//   /// API: POST /api/locations/ping
//   /// Body: { lat, lng, scheduleId }
//   Future<void> pingLocation({
//     required double lat,
//     required double lng,
//     int? scheduleId,
//   }) async {
//     await request(() async {
//       await api.dio.post(
//         '${ApiConstants.locations}/ping',
//         data: {
//           'lat': lat,
//           'lng': lng,
//           if (scheduleId != null) 'scheduleId': scheduleId,
//         },
//       );
//     });
//   }
//
//   /// Get live locations of friends in a schedule
//   /// API: GET /api/locations/schedules/{scheduleId}/live
//   Future<List<LiveLocationModel>> getScheduleLiveLocations(
//     int scheduleId,
//   ) async {
//     return request(() async {
//       final response = await api.dio.get(
//         '${ApiConstants.locations}/schedules/$scheduleId/live',
//       );
//       return parseList(response.data, LiveLocationModel.fromJson);
//     });
//   }
//
//   /// Get live locations of all friends
//   /// API: GET /api/locations/friends/live
//   Future<List<LiveLocationModel>> getLiveFriendLocations() async {
//     return request(() async {
//       final response =
//           await api.dio.get('${ApiConstants.locations}/friends/live');
//       return parseList(response.data, LiveLocationModel.fromJson);
//     });
//   }
//
//   /// Share location via token
//   Future<String> shareLocation() async {
//     return request(() async {
//       final response = await api.dio.post('${ApiConstants.locations}/share');
//       final body = response.data as Map<String, dynamic>;
//       final data = body['data'];
//       if (data is String) return data;
//       if (data is Map<String, dynamic>) {
//         return data['shareToken'] as String? ?? '';
//       }
//       return '';
//     });
//   }
//
//   /// Get public location via token
//   Future<PublicLocationModel> getPublicLocation(String token) async {
//     return request(() async {
//       final response = await api.dio.get(
//         '${ApiConstants.locations}/share/$token',
//       );
//
//       final body = response.data;
//       if (body is Map<String, dynamic>) {
//         return PublicLocationModel.fromJson(body);
//       }
//       throw StateError('Invalid tracking response');
//     });
//   }
//
//   /// Get tour route waypoints
//   Future<List<Map<String, double>>> getTourRoute(int scheduleId) async {
//     return request(() async {
//       final response = await api.dio.get(
//         '${ApiConstants.tourSchedules}/$scheduleId/route',
//       );
//
//       final data = response.data;
//       if (data is List) {
//         return data
//             .map((item) => {
//                   'lat': (item['lat'] as num?)?.toDouble() ?? 0.0,
//                   'lng': (item['lng'] as num?)?.toDouble() ?? 0.0,
//                 })
//             .toList();
//       }
//       return [];
//     });
//   }
// }
//
// /// Footprint DTO for location history
// class FootprintDto {
//   final double lat;
//   final double lng;
//   final DateTime timestamp;
//
//   FootprintDto({
//     required this.lat,
//     required this.lng,
//     required this.timestamp,
//   });
//
//   factory FootprintDto.fromJson(Map<String, dynamic> json) {
//     return FootprintDto(
//       lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
//       lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
//       timestamp: json['timestamp'] != null
//           ? DateTime.parse(json['timestamp'] as String)
//           : DateTime.now(),
//     );
//   }
// }
