import 'package:flutter_test/flutter_test.dart';
import 'package:stayhub_mobile/models/explore_filters.dart';
import 'package:stayhub_mobile/models/feature_models.dart';
import 'package:stayhub_mobile/models/tour_model.dart';
import 'package:stayhub_mobile/services/catalog_service.dart';
import 'package:stayhub_mobile/utils/text_encoding.dart';

void main() {
  test('tour list metadata uses available future tickets', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tour = TourModel.fromJson({
      'id': 1,
      'categoryId': 2,
      'name': 'Da Nang discovery',
      'city': 'Da Nang',
      'country': 'Vietnam',
      'tourSchedules': [
        {
          'departureDate': tomorrow.toIso8601String(),
          'returnDate': tomorrow.add(const Duration(days: 2)).toIso8601String(),
          'tourScheduleTickets': [
            {
              'price': 2500000,
              'availableQuantity': 3,
              'isActive': true,
            },
            {
              'price': 1000000,
              'availableQuantity': 0,
              'isActive': true,
            },
          ],
        },
      ],
    });

    expect(tour.locationLabel, 'Da Nang, Vietnam');
    expect(tour.startingPrice, 2500000);
    expect(tour.nextDeparture, isNotNull);
  });

  test('explore filters count and clear optional values', () {
    final filters = ExploreFilters(
      city: 'Da Nang',
      categoryId: 3,
      startDate: DateTime(2026, 7, 1),
      sortBy: 'price_asc',
    );

    expect(filters.activeFilterCount, 4);

    final cleared = filters.copyWith(
      city: '',
      clearCategory: true,
      clearStartDate: true,
      clearSort: true,
    );
    expect(cleared.activeFilterCount, 0);
  });

  test('tour itinerary parses full backend DTO details', () {
    final itinerary = TourItineraryModel.fromJson({
      'id': 10,
      'tourId': 4,
      'dayNumber': 2,
      'title': 'Visit the old town',
      'description': 'Walk through the historic center.',
      'startDuration': '08:30:00',
      'endDuration': '10:15:00',
      'locationName': 'Hoi An Ancient Town',
      'locationLat': 15.8801,
      'locationLng': 108.338,
      'tourismInfoId': 7,
    });

    expect(itinerary.dayNumber, 2);
    expect(itinerary.timeLabel, '08:30 - 10:15');
    expect(itinerary.startTimeLabel, '08:30');
    expect(itinerary.endTimeLabel, '10:15');
    expect(itinerary.locationName, 'Hoi An Ancient Town');
    expect(itinerary.hasCoordinates, isTrue);
    expect(itinerary.tourismInfoId, 7);
  });

  test('tour itinerary formats TimeOnly and TimeSpan variants', () {
    final itinerary = TourItineraryModel.fromJson({
      'id': 11,
      'tourId': 4,
      'dayNumber': 2,
      'startDuration': '0.08:30:00',
      'endDuration': '10:15:00.0000000',
    });

    expect(itinerary.startTimeLabel, '08:30');
    expect(itinerary.endTimeLabel, '10:15');
    expect(itinerary.timeLabel, '08:30 - 10:15');
  });

  test('tourism information parses heritage detail response', () {
    final heritage = TourismInformationModel.fromJson({
      'id': 7,
      'name': 'Hoi An Ancient Town',
      'type': 'Cultural Heritage',
      'description': 'A preserved trading port.',
      'address': 'Minh An Ward',
      'city': 'Hoi An',
      'country': 'Vietnam',
      'latitude': 15.8801,
      'longitude': 108.338,
      'imageUrl': 'https://example.com/hoi-an.jpg',
      'sourceName': 'UNESCO',
    });

    expect(heritage.id, 7);
    expect(heritage.name, 'Hoi An Ancient Town');
    expect(heritage.locationLabel, 'Minh An Ward, Hoi An, Vietnam');
    expect(heritage.imageUrl, 'https://example.com/hoi-an.jpg');
  });

  test('chat room parses SocialAPI room contract', () {
    final room = ChatRoomModel.fromJson({
      'id': 21,
      'roomName': 'Da Nang Summer Group',
      'isGroupChat': true,
      'scheduleId': 88,
      'avatarUrl': 'https://example.com/group.jpg',
      'latestMessage': 'See you at the airport',
      'latestMessageTime': '2026-06-07T08:30:00Z',
      'isPinned': true,
      'isMuted': false,
    });

    expect(room.name, 'Da Nang Summer Group');
    expect(room.isGroup, isTrue);
    expect(room.scheduleId, 88);
    expect(room.lastMessage, 'See you at the airport');
    expect(room.lastMessageAt, isNotNull);
    expect(room.isPinned, isTrue);
  });

  test('chat message parses SignalR payload contract', () {
    final message = ChatMessageModel.fromJson({
      'id': 31,
      'chatRoomId': 21,
      'senderId': 9,
      'senderName': 'Minh Anh',
      'senderAvatar': 'https://example.com/avatar.jpg',
      'content': 'Hello everyone',
      'isRead': false,
      'sentAt': '2026-06-07T08:35:00Z',
    });

    expect(message.chatRoomId, 21);
    expect(message.senderName, 'Minh Anh');
    expect(message.senderAvatar, 'https://example.com/avatar.jpg');
    expect(message.content, 'Hello everyone');
  });

  test('chat repairs UTF-8 text decoded as Windows-1252', () {
    expect(
      TextEncoding.repairMojibake('cÃ³ ai á»Ÿ Ä‘Ã³ k'),
      'có ai ở đó k',
    );
  });

  test('chat keeps valid Vietnamese text unchanged', () {
    const text = 'Có ai ở đó không?';
    expect(TextEncoding.repairMojibake(text), text);
  });

  test('tour schedule parses group chat identification details', () {
    final schedule = TourScheduleModel.fromJson({
      'id': 88,
      'tourId': 7,
      'departureDate': '2026-07-10T08:00:00',
      'returnDate': '2026-07-13T18:00:00',
      'note': 'Meet at the airport',
      'tour': {
        'id': 7,
        'categoryId': 2,
        'name': 'Da Nang Discovery',
        'city': 'Da Nang',
        'country': 'Vietnam',
        'imageUrl': 'https://example.com/da-nang.jpg',
      },
    });

    expect(schedule.id, 88);
    expect(schedule.tour?.name, 'Da Nang Discovery');
    expect(schedule.tour?.locationLabel, 'Da Nang, Vietnam');
    expect(schedule.note, 'Meet at the airport');
  });

  test('schedule itinerary parses order detail timeline contract', () {
    final itinerary = TourScheduleItineraryModel.fromJson({
      'id': 19,
      'scheduleId': 88,
      'itineraryDate': '2026-07-11T00:00:00',
      'dayNumber': 2,
      'title': 'Explore Hoi An',
      'description': 'Walk through the ancient town.',
      'startDuration': '08:30:00.0000000',
      'endDuration': '0.10:15:00',
      'locationName': 'Hoi An Ancient Town',
      'locationLat': 15.8801,
      'locationLng': 108.338,
      'tourismInfoId': 7,
    });

    expect(itinerary.scheduleId, 88);
    expect(itinerary.dayNumber, 2);
    expect(itinerary.itineraryDate, DateTime(2026, 7, 11));
    expect(itinerary.timeLabel, '08:30 - 10:15');
    expect(itinerary.locationName, 'Hoi An Ancient Town');
    expect(itinerary.tourismInfoId, 7);
  });
}
