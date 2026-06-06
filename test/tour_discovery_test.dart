import 'package:flutter_test/flutter_test.dart';
import 'package:stayhub_mobile/models/explore_filters.dart';
import 'package:stayhub_mobile/models/tour_model.dart';
import 'package:stayhub_mobile/services/catalog_service.dart';

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
}
