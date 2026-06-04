import '../models/tour_model.dart';

/// Tham số checkout — tương đương `location.state` trên web (`/tours/:id/book`).
class BookingRouteArgs {
  final int tourId;
  final String tourName;
  final String? tourImageUrl;
  final String? tourLocation;
  final int scheduleId;
  final DateTime departureDate;
  final DateTime returnDate;

  const BookingRouteArgs({
    required this.tourId,
    required this.tourName,
    this.tourImageUrl,
    this.tourLocation,
    required this.scheduleId,
    required this.departureDate,
    required this.returnDate,
  });

  factory BookingRouteArgs.fromTourSchedule({
    required TourModel tour,
    required TourScheduleModel schedule,
  }) {
    return BookingRouteArgs(
      tourId: tour.id,
      tourName: tour.name,
      tourImageUrl: tour.imageUrl,
      tourLocation: tour.locationLabel,
      scheduleId: schedule.id,
      departureDate: schedule.departureDate,
      returnDate: schedule.returnDate,
    );
  }

  Map<String, dynamic> toMap() => {
        'tourId': tourId,
        'tourName': tourName,
        'tourImageUrl': tourImageUrl,
        'tourLocation': tourLocation,
        'scheduleId': scheduleId,
        'departureDate': departureDate.toIso8601String(),
        'returnDate': returnDate.toIso8601String(),
      };

  factory BookingRouteArgs.fromMap(Map<String, dynamic> map) {
    return BookingRouteArgs(
      tourId: (map['tourId'] as num).toInt(),
      tourName: map['tourName'] as String? ?? 'Tour',
      tourImageUrl: map['tourImageUrl'] as String?,
      tourLocation: map['tourLocation'] as String?,
      scheduleId: (map['scheduleId'] as num).toInt(),
      departureDate: DateTime.parse(map['departureDate'].toString()),
      returnDate: DateTime.parse(map['returnDate'].toString()),
    );
  }
}

BookingRouteArgs? parseBookingArgs(dynamic arguments) {
  if (arguments is BookingRouteArgs) return arguments;
  if (arguments is Map) {
    try {
      return BookingRouteArgs.fromMap(Map<String, dynamic>.from(arguments));
    } catch (_) {
      return null;
    }
  }
  return null;
}
