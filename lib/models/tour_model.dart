import '../utils/json_utils.dart';

class TourModel {
  final int id;
  final int categoryId;
  final String name;
  final String? description;
  final String? country;
  final String? city;
  final String? address;
  final String? imageUrl;
  final String? status;
  final double? averageStar;
  final int? startingPrice;
  final DateTime? nextDeparture;

  TourModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    this.country,
    this.city,
    this.address,
    this.imageUrl,
    this.status,
    this.averageStar,
    this.startingPrice,
    this.nextDeparture,
  });

  factory TourModel.fromJson(Map<String, dynamic> json) {
    final schedules = JsonUtils.readMapList(
      JsonUtils.pick(json, ['tourSchedules', 'TourSchedules']),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int? startingPrice;
    DateTime? nextDeparture;

    for (final schedule in schedules) {
      final departure = JsonUtils.readDateTime(
        JsonUtils.pick(schedule, ['departureDate', 'DepartureDate']),
      );
      if (departure == null || departure.isBefore(today)) continue;

      final tickets = JsonUtils.readMapList(
        JsonUtils.pick(
          schedule,
          ['tourScheduleTickets', 'TourScheduleTickets'],
        ),
      );
      var hasAvailableTicket = false;
      for (final ticket in tickets) {
        final isActive = JsonUtils.readBool(
          JsonUtils.pick(ticket, ['isActive', 'IsActive']),
          fallback: true,
        );
        final available = JsonUtils.readInt(
          JsonUtils.pick(
            ticket,
            ['availableQuantity', 'AvailableQuantity'],
          ),
        );
        if (!isActive || available <= 0) continue;

        hasAvailableTicket = true;
        final price = JsonUtils.readInt(
          JsonUtils.pick(ticket, ['price', 'Price']),
        );
        if (startingPrice == null || price < startingPrice) {
          startingPrice = price;
        }
      }

      if (hasAvailableTicket &&
          (nextDeparture == null || departure.isBefore(nextDeparture))) {
        nextDeparture = departure;
      }
    }

    return TourModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      country: json['country'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      imageUrl: json['imageUrl'] as String?,
      status: json['status'] as String?,
      averageStar: (json['averageStar'] as num?)?.toDouble(),
      startingPrice: startingPrice,
      nextDeparture: nextDeparture,
    );
  }

  String get locationLabel {
    final parts = [city, country].where((e) => e != null && e.isNotEmpty);
    return parts.isEmpty ? 'Chưa cập nhật' : parts.join(', ');
  }
}

class TourScheduleModel {
  final int id;
  final int tourId;
  final DateTime departureDate;
  final DateTime returnDate;
  final String? note;
  final TourModel? tour;
  final List<ScheduleTicketModel> tickets;

  TourScheduleModel({
    required this.id,
    required this.tourId,
    required this.departureDate,
    required this.returnDate,
    this.note,
    this.tour,
    this.tickets = const [],
  });

  factory TourScheduleModel.fromJson(Map<String, dynamic> json) {
    final rawTickets = JsonUtils.readMapList(
      JsonUtils.pick(json, ['tourScheduleTickets', 'TourScheduleTickets']),
    );
    final dep = JsonUtils.readDateTime(
      JsonUtils.pick(json, ['departureDate', 'DepartureDate']),
    );
    final ret = JsonUtils.readDateTime(
      JsonUtils.pick(json, ['returnDate', 'ReturnDate']),
    );
    return TourScheduleModel(
      id: JsonUtils.readInt(JsonUtils.pick(json, ['id', 'Id'])),
      tourId: JsonUtils.readInt(JsonUtils.pick(json, ['tourId', 'TourId'])),
      departureDate: dep ?? DateTime.now(),
      returnDate: ret ?? DateTime.now(),
      note: JsonUtils.readString(JsonUtils.pick(json, ['note', 'Note'])),
      tour: () {
        final t = JsonUtils.pick(json, ['tour', 'Tour']);
        if (t is Map<String, dynamic>) {
          return TourModel.fromJson(t);
        }
        return null;
      }(),
      tickets: rawTickets.map(ScheduleTicketModel.fromJson).toList(),
    );
  }
}

class TourScheduleItineraryModel {
  final int id;
  final int scheduleId;
  final DateTime? itineraryDate;
  final int dayNumber;
  final String? title;
  final String? description;
  final String? startDuration;
  final String? endDuration;
  final String? locationName;
  final double? locationLat;
  final double? locationLng;
  final int? tourismInfoId;

  const TourScheduleItineraryModel({
    required this.id,
    required this.scheduleId,
    required this.dayNumber,
    this.itineraryDate,
    this.title,
    this.description,
    this.startDuration,
    this.endDuration,
    this.locationName,
    this.locationLat,
    this.locationLng,
    this.tourismInfoId,
  });

  factory TourScheduleItineraryModel.fromJson(Map<String, dynamic> json) {
    final tourismInfoValue = JsonUtils.pick(
      json,
      ['tourismInfoId', 'TourismInfoId'],
    );
    return TourScheduleItineraryModel(
      id: JsonUtils.readInt(JsonUtils.pick(json, ['id', 'Id'])),
      scheduleId: JsonUtils.readInt(
        JsonUtils.pick(json, ['scheduleId', 'ScheduleId']),
      ),
      itineraryDate: JsonUtils.readDateTime(
        JsonUtils.pick(json, ['itineraryDate', 'ItineraryDate']),
      ),
      dayNumber: JsonUtils.readInt(
        JsonUtils.pick(json, ['dayNumber', 'DayNumber']),
      ),
      title: JsonUtils.readString(JsonUtils.pick(json, ['title', 'Title'])),
      description: JsonUtils.readString(
        JsonUtils.pick(json, ['description', 'Description']),
      ),
      startDuration: JsonUtils.readString(
        JsonUtils.pick(json, ['startDuration', 'StartDuration']),
      ),
      endDuration: JsonUtils.readString(
        JsonUtils.pick(json, ['endDuration', 'EndDuration']),
      ),
      locationName: JsonUtils.readString(
        JsonUtils.pick(json, ['locationName', 'LocationName']),
      ),
      locationLat: JsonUtils.readDouble(
        JsonUtils.pick(json, ['locationLat', 'LocationLat']),
      ),
      locationLng: JsonUtils.readDouble(
        JsonUtils.pick(json, ['locationLng', 'LocationLng']),
      ),
      tourismInfoId:
          tourismInfoValue == null ? null : JsonUtils.readInt(tourismInfoValue),
    );
  }

  String? get timeLabel {
    final start = _formatTime(startDuration);
    final end = _formatTime(endDuration);
    if (start != null && end != null) return '$start - $end';
    return start ?? end;
  }

  static String? _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final match = RegExp(
      r'^(?:\d+\.)?(\d{1,2}):(\d{2})',
    ).firstMatch(value.trim());
    if (match == null) return value.trim();
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }
}

class ScheduleTicketModel {
  final int id;
  final int scheduleId;
  final int ticketTypeId;
  final int price;
  final int quantity;
  final int availableQuantity;
  final bool? isActive;

  ScheduleTicketModel({
    required this.id,
    required this.scheduleId,
    required this.ticketTypeId,
    required this.price,
    required this.quantity,
    required this.availableQuantity,
    this.isActive,
  });

  factory ScheduleTicketModel.fromJson(Map<String, dynamic> json) {
    return ScheduleTicketModel(
      id: JsonUtils.readInt(json['id']),
      scheduleId: JsonUtils.readInt(json['scheduleId']),
      ticketTypeId: JsonUtils.readInt(json['ticketTypeId']),
      price: JsonUtils.readInt(json['price']),
      quantity: JsonUtils.readInt(json['quantity']),
      availableQuantity: JsonUtils.readInt(
        JsonUtils.pick(json, ['availableQuantity', 'AvailableQuantity']),
      ),
      isActive: JsonUtils.readBool(json['isActive']),
    );
  }
}

class AssignedScheduleModel {
  final int scheduleId;
  final int tourId;
  final DateTime departureDate;
  final DateTime returnDate;
  final String? tourName;
  final String? tourImageUrl;
  final String? assignedRole;

  AssignedScheduleModel({
    required this.scheduleId,
    required this.tourId,
    required this.departureDate,
    required this.returnDate,
    this.tourName,
    this.tourImageUrl,
    this.assignedRole,
  });

  factory AssignedScheduleModel.fromJson(Map<String, dynamic> json) {
    return AssignedScheduleModel(
      scheduleId: JsonUtils.readInt(
        JsonUtils.pick(json, ['scheduleId', 'ScheduleId']),
      ),
      tourId: JsonUtils.readInt(JsonUtils.pick(json, ['tourId', 'TourId'])),
      departureDate: JsonUtils.readDateTime(
            JsonUtils.pick(json, ['departureDate', 'DepartureDate']),
          ) ??
          DateTime.now(),
      returnDate: JsonUtils.readDateTime(
            JsonUtils.pick(json, ['returnDate', 'ReturnDate']),
          ) ??
          DateTime.now(),
      tourName: json['tourName'] as String?,
      tourImageUrl: json['tourImageUrl'] as String?,
      assignedRole: json['assignedRole'] as String?,
    );
  }
}

class TourRecommendationModel {
  final int tourId;
  final String name;
  final String? imageUrl;
  final String? city;
  final String? country;
  final double? averageStar;
  final double? score;
  final String? reason;

  TourRecommendationModel({
    required this.tourId,
    required this.name,
    this.imageUrl,
    this.city,
    this.country,
    this.averageStar,
    this.score,
    this.reason,
  });

  factory TourRecommendationModel.fromJson(Map<String, dynamic> json) {
    return TourRecommendationModel(
      tourId: json['tourId'] as int? ?? json['id'] as int? ?? 0,
      name: json['name'] as String? ?? json['tourName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      averageStar: (json['averageStar'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble(),
      reason: json['reason'] as String? ?? json['explanation'] as String?,
    );
  }
}
