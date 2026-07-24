import '../utils/json_utils.dart';
import 'ai_models.dart';

class TourModel {
  final int id;
  final int categoryId;
  final String name;
  final String? description;
  final String? country;
  final String? city;
  final String? address;
  final String? imageUrl;
  final List<String> tourImages;
  final String? status;
  final double? averageStar;
  final int? startingPrice;   // effective price (after discount)
  final int? originalPrice;   // raw price before discount (null if no discount)
  final double? discountPercentage; // percentage discount if applicable
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
    this.tourImages = const [],
    this.status,
    this.averageStar,
    this.startingPrice,
    this.originalPrice,
    this.discountPercentage,
    this.nextDeparture,
  });

  factory TourModel.fromJson(Map<String, dynamic> json) {
    final schedules = JsonUtils.readMapList(
      JsonUtils.pick(json, ['tourSchedules', 'TourSchedules']),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int? startingPrice;
    int? originalPrice;
    double? discountPercentage;
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
        final ticketModel = ScheduleTicketModel.fromJson(ticket);
        final effective = ticketModel.effectivePrice;
        final raw = ticketModel.price;
        if (startingPrice == null || effective < startingPrice) {
          startingPrice = effective;
          // track raw price only if there's a real discount
          if (effective < raw) {
            originalPrice = raw;
            final promo = ticketModel.promotion;
            if (promo != null && promo.status == 'Active' && promo.discountType.toLowerCase() == 'percentage') {
              discountPercentage = promo.discountValue;
            } else {
              discountPercentage = null;
            }
          } else {
            originalPrice = null;
            discountPercentage = null;
          }
        }
      }

      if (hasAvailableTicket &&
          (nextDeparture == null || departure.isBefore(nextDeparture))) {
        nextDeparture = departure;
      }
    }

    final List<String> extractedImages = [];
    final imagesList = JsonUtils.pick(json, ['tourImages', 'TourImages']);
    if (imagesList is List) {
      for (final img in imagesList) {
        final url = img['imageUrl']?.toString();
        if (url != null && url.isNotEmpty) {
          extractedImages.add(url);
        }
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
      tourImages: extractedImages,
      status: json['status'] as String?,
      averageStar: (json['averageStar'] as num?)?.toDouble(),
      startingPrice: startingPrice,
      originalPrice: originalPrice,
      discountPercentage: discountPercentage,
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
  final PromotionModel? promotion;

  ScheduleTicketModel({
    required this.id,
    required this.scheduleId,
    required this.ticketTypeId,
    required this.price,
    required this.quantity,
    required this.availableQuantity,
    this.isActive,
    this.promotion,
  });

  int get effectivePrice {
    if (promotion == null || promotion!.status != "Active") {
      return price;
    }

    final now = DateTime.now();
    if (now.isBefore(promotion!.startDate) || now.isAfter(promotion!.endDate)) {
      return price;
    }

    if (promotion!.discountValue <= 0) {
      return price;
    }

    double discountAmount = 0;
    if (promotion!.discountType.toLowerCase() == "percentage") {
      discountAmount = price * (promotion!.discountValue / 100);
      if (promotion!.maxDiscountAmount != null && discountAmount > promotion!.maxDiscountAmount!) {
        discountAmount = promotion!.maxDiscountAmount!;
      }
    } else {
      discountAmount = promotion!.discountValue;
    }

    final finalPrice = price - discountAmount.toInt();
    return finalPrice > 0 ? finalPrice : 0;
  }

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
      promotion: () {
        final p = JsonUtils.pick(json, ['promotion', 'Promotion']);
        if (p is Map<String, dynamic>) {
          return PromotionModel.fromJson(p);
        }
        return null;
      }(),
    );
  }
}

class PromotionModel {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String discountType;
  final double discountValue;
  final double? maxDiscountAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  PromotionModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: JsonUtils.readInt(JsonUtils.pick(json, ['id', 'Id'])),
      code: JsonUtils.readString(JsonUtils.pick(json, ['code', 'Code'])) ?? '',
      name: JsonUtils.readString(JsonUtils.pick(json, ['name', 'Name'])) ?? '',
      description: JsonUtils.readString(JsonUtils.pick(json, ['description', 'Description'])),
      discountType: JsonUtils.readString(JsonUtils.pick(json, ['discountType', 'DiscountType'])) ?? '',
      discountValue: JsonUtils.readDouble(JsonUtils.pick(json, ['discountValue', 'DiscountValue'])) ?? 0,
      maxDiscountAmount: JsonUtils.readDouble(JsonUtils.pick(json, ['maxDiscountAmount', 'MaxDiscountAmount'])),
      startDate: JsonUtils.readDateTime(JsonUtils.pick(json, ['startDate', 'StartDate'])) ?? DateTime.now(),
      endDate: JsonUtils.readDateTime(JsonUtils.pick(json, ['endDate', 'EndDate'])) ?? DateTime.now(),
      status: JsonUtils.readString(JsonUtils.pick(json, ['status', 'Status'])) ?? '',
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

class ScoreDimensionExplanationModel {
  final String dimensionKey;
  final String label;
  final double score;
  final double weight;
  final String explanation;

  ScoreDimensionExplanationModel({
    required this.dimensionKey,
    required this.label,
    required this.score,
    required this.weight,
    required this.explanation,
  });

  factory ScoreDimensionExplanationModel.fromJson(Map<String, dynamic> json) {
    return ScoreDimensionExplanationModel(
      dimensionKey: JsonUtils.readString(JsonUtils.pick(json, ['dimensionKey', 'DimensionKey'])) ?? '',
      label: JsonUtils.readString(JsonUtils.pick(json, ['label', 'Label'])) ?? '',
      score: JsonUtils.readDouble(JsonUtils.pick(json, ['score', 'Score'])) ?? 0.0,
      weight: JsonUtils.readDouble(JsonUtils.pick(json, ['weight', 'Weight'])) ?? 0.0,
      explanation: JsonUtils.readString(JsonUtils.pick(json, ['explanation', 'Explanation'])) ?? '',
    );
  }
}

class ScoreBreakdownModel {
  final double fairnessScore;
  final double minPersonaScore;
  final double meanPersonaScore;
  final double envyGap;
  final double dissatisfactionVariance;
  final Map<String, double> personaScores;
  final Map<String, double> dimensionScores;
  final List<ScoreDimensionExplanationModel> dimensionExplanations;
  final String aggregationFormula;
  final String? overallExplanation;

  ScoreBreakdownModel({
    required this.fairnessScore,
    required this.minPersonaScore,
    required this.meanPersonaScore,
    required this.envyGap,
    required this.dissatisfactionVariance,
    this.personaScores = const {},
    this.dimensionScores = const {},
    this.dimensionExplanations = const [],
    required this.aggregationFormula,
    this.overallExplanation,
  });

  factory ScoreBreakdownModel.fromJson(Map<String, dynamic> json) {
    final rawPersona = JsonUtils.pick(json, ['personaScores', 'PersonaScores']);
    final rawDimension = JsonUtils.pick(json, ['dimensionScores', 'DimensionScores']);
    final rawExplanations = JsonUtils.readMapList(
      JsonUtils.pick(json, ['dimensionExplanations', 'DimensionExplanations']),
    );

    return ScoreBreakdownModel(
      fairnessScore: JsonUtils.readDouble(JsonUtils.pick(json, ['fairnessScore', 'FairnessScore'])) ?? 0.0,
      minPersonaScore: JsonUtils.readDouble(JsonUtils.pick(json, ['minPersonaScore', 'MinPersonaScore'])) ?? 0.0,
      meanPersonaScore: JsonUtils.readDouble(JsonUtils.pick(json, ['meanPersonaScore', 'MeanPersonaScore'])) ?? 0.0,
      envyGap: JsonUtils.readDouble(JsonUtils.pick(json, ['envyGap', 'EnvyGap'])) ?? 0.0,
      dissatisfactionVariance: JsonUtils.readDouble(JsonUtils.pick(json, ['dissatisfactionVariance', 'DissatisfactionVariance'])) ?? 0.0,
      personaScores: rawPersona is Map
          ? rawPersona.map(
              (k, v) => MapEntry(k.toString(), JsonUtils.readDouble(v) ?? 0.0),
            )
          : const {},
      dimensionScores: rawDimension is Map
          ? rawDimension.map(
              (k, v) => MapEntry(k.toString(), JsonUtils.readDouble(v) ?? 0.0),
            )
          : const {},
      dimensionExplanations: rawExplanations
          .map(ScoreDimensionExplanationModel.fromJson)
          .toList(),
      aggregationFormula: JsonUtils.readString(JsonUtils.pick(json, ['aggregationFormula', 'AggregationFormula'])) ?? '',
      overallExplanation: JsonUtils.readString(JsonUtils.pick(json, ['overallExplanation', 'OverallExplanation'])),
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
  final List<String> matchReasons;
  final ScoreBreakdownModel? scoreBreakdown;
  final int? durationDays;
  final int? minPrice;
  final String? nextDeparture;
  final String? scheduleNote;
  final bool? matchesPreferredDates;
  final WeatherAdviceModel? destinationWeather;

  TourRecommendationModel({
    required this.tourId,
    required this.name,
    this.imageUrl,
    this.city,
    this.country,
    this.averageStar,
    this.score,
    this.reason,
    this.matchReasons = const [],
    this.scoreBreakdown,
    this.durationDays,
    this.minPrice,
    this.nextDeparture,
    this.scheduleNote,
    this.matchesPreferredDates,
    this.destinationWeather,
  });

  factory TourRecommendationModel.fromJson(Map<String, dynamic> json) {
    final rawReasons = JsonUtils.pick(json, ['matchReasons', 'MatchReasons']);
    final rawBreakdown = JsonUtils.pick(json, ['scoreBreakdown', 'ScoreBreakdown']);
    final rawWeather = JsonUtils.pick(json, ['destinationWeather', 'DestinationWeather']);
    final rawReasonsList = <String>[];
    if (rawReasons is List) {
      for (final e in rawReasons) {
        if (e != null) rawReasonsList.add(e.toString());
      }
    }

    return TourRecommendationModel(
      tourId: json['tourId'] as int? ?? json['id'] as int? ?? 0,
      name: json['name'] as String? ?? json['tourName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      averageStar: (json['averageStar'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble(),
      reason: json['reason'] as String? ?? json['explanation'] as String?,
      matchReasons: rawReasonsList,
      scoreBreakdown: rawBreakdown is Map<String, dynamic>
          ? ScoreBreakdownModel.fromJson(rawBreakdown)
          : null,
      durationDays: JsonUtils.readInt(JsonUtils.pick(json, ['durationDays', 'DurationDays'])),
      minPrice: JsonUtils.readInt(JsonUtils.pick(json, ['minPrice', 'MinPrice'])),
      nextDeparture: JsonUtils.readString(JsonUtils.pick(json, ['nextDeparture', 'NextDeparture'])),
      scheduleNote: JsonUtils.readString(JsonUtils.pick(json, ['scheduleNote', 'ScheduleNote'])),
      matchesPreferredDates: JsonUtils.readBool(JsonUtils.pick(json, ['matchesPreferredDates', 'MatchesPreferredDates'])),
      destinationWeather: rawWeather is Map<String, dynamic>
          ? WeatherAdviceModel.fromJson(rawWeather)
          : null,
    );
  }
}
