import 'package:flutter_test/flutter_test.dart';
import 'package:stayhub_mobile/models/feature_models.dart';

void main() {
  group('Friend social models', () {
    test('parses friendship response from SocialAPI', () {
      final friend = FriendModel.fromJson({
        'id': 21,
        'friendId': 7,
        'fullName': 'Nguyen Van A',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'status': 'Accepted',
        'createdAt': '2026-06-15T10:00:00Z',
      });

      expect(friend.friendshipId, 21);
      expect(friend.userId, 7);
      expect(friend.fullName, 'Nguyen Van A');
      expect(friend.avatarUrl, 'https://example.com/avatar.jpg');
      expect(friend.status, 'Accepted');
      expect(friend.createdAt, isNotNull);
    });

    test('uses friendId as sender id for received request', () {
      final request = FriendRequestModel.fromJson({
        'id': 33,
        'friendId': 9,
        'fullName': 'Tran Thi B',
        'avatarUrl': 'https://example.com/request-avatar.jpg',
        'status': 'Pending',
        'createdAt': '2026-06-15T11:00:00Z',
      });

      expect(request.id, 33);
      expect(request.senderId, 9);
      expect(request.senderName, 'Tran Thi B');
      expect(
        request.senderAvatarUrl,
        'https://example.com/request-avatar.jpg',
      );
      expect(request.status, 'Pending');
    });

    test('parses public user profile fields', () {
      final user = UserSearchModel.fromJson({
        'id': 5,
        'fullName': 'Le Van C',
        'avatarUrl': 'https://example.com/profile.jpg',
        'gender': 'Male',
        'dateOfBirth': '2000-01-02',
        'createdAt': '2025-01-01T00:00:00Z',
      });

      expect(user.id, 5);
      expect(user.fullName, 'Le Van C');
      expect(user.gender, 'Male');
      expect(user.dateOfBirth, '2000-01-02');
      expect(user.createdAt, isNotNull);
    });
  });
}
