import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../utils/json_utils.dart';
import 'base_service.dart';

class CategoryModel {
  final int id;
  final String name;

  CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as int,
        name: json['name'] as String? ?? json['categoryName'] as String? ?? '',
      );
}

class BannerModel {
  final int id;
  final String? title;
  final String? imageUrl;
  final String? linkUrl;

  BannerModel({
    required this.id,
    this.title,
    this.imageUrl,
    this.linkUrl,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) => BannerModel(
        id: json['id'] as int,
        title: json['title'] as String?,
        imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
        linkUrl: json['linkUrl'] as String?,
      );
}

class TicketTypeModel {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int? minAge;
  final int? maxAge;

  TicketTypeModel({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    this.minAge,
    this.maxAge,
  });

  factory TicketTypeModel.fromJson(Map<String, dynamic> json) =>
      TicketTypeModel(
        id: JsonUtils.readInt(JsonUtils.pick(json, ['id', 'Id'])),
        name:
            JsonUtils.readString(JsonUtils.pick(json, ['name', 'Name'])) ?? '',
        description: JsonUtils.readString(
          JsonUtils.pick(json, ['description', 'Description']),
        ),
        isActive: JsonUtils.readBool(
          JsonUtils.pick(json, ['isActive', 'IsActive']),
          fallback: true,
        ),
        minAge: JsonUtils.readInt(JsonUtils.pick(json, ['minAge', 'MinAge'])),
        maxAge: JsonUtils.readInt(JsonUtils.pick(json, ['maxAge', 'MaxAge'])),
      );
}

class TourismInformationModel {
  final int id;
  final String name;
  final String? type;
  final String? description;
  final String? address;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? sourceName;
  final String? sourceUrl;

  TourismInformationModel({
    required this.id,
    required this.name,
    this.type,
    this.description,
    this.address,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.sourceName,
    this.sourceUrl,
  });

  factory TourismInformationModel.fromJson(Map<String, dynamic> json) {
    return TourismInformationModel(
      id: JsonUtils.readInt(JsonUtils.pick(json, ['id', 'Id'])),
      name: JsonUtils.readString(JsonUtils.pick(json, ['name', 'Name'])) ?? '',
      type: JsonUtils.readString(JsonUtils.pick(json, ['type', 'Type'])),
      description: JsonUtils.readString(
        JsonUtils.pick(json, ['description', 'Description']),
      ),
      address: JsonUtils.readString(
        JsonUtils.pick(json, ['address', 'Address']),
      ),
      city: JsonUtils.readString(JsonUtils.pick(json, ['city', 'City'])),
      country:
          JsonUtils.readString(JsonUtils.pick(json, ['country', 'Country'])),
      latitude: JsonUtils.readDouble(
        JsonUtils.pick(json, ['latitude', 'Latitude']),
      ),
      longitude: JsonUtils.readDouble(
        JsonUtils.pick(json, ['longitude', 'Longitude']),
      ),
      imageUrl: JsonUtils.readString(
        JsonUtils.pick(json, ['imageUrl', 'ImageUrl']),
      ),
      sourceName: JsonUtils.readString(
        JsonUtils.pick(json, ['sourceName', 'SourceName']),
      ),
      sourceUrl: JsonUtils.readString(
        JsonUtils.pick(json, ['sourceUrl', 'SourceUrl']),
      ),
    );
  }

  String? get locationLabel {
    final parts = <String>[];
    for (final value in [address, city, country]) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty && !parts.contains(text)) {
        parts.add(text);
      }
    }
    return parts.isEmpty ? null : parts.join(', ');
  }
}

class TourItineraryModel {
  final int id;
  final int tourId;
  final String? title;
  final String? description;
  final int? dayNumber;
  final String? startDuration;
  final String? endDuration;
  final String? locationName;
  final double? locationLat;
  final double? locationLng;
  final int? tourismInfoId;

  TourItineraryModel({
    required this.id,
    required this.tourId,
    this.title,
    this.description,
    this.dayNumber,
    this.startDuration,
    this.endDuration,
    this.locationName,
    this.locationLat,
    this.locationLng,
    this.tourismInfoId,
  });

  factory TourItineraryModel.fromJson(Map<String, dynamic> json) {
    return TourItineraryModel(
      id: JsonUtils.readInt(JsonUtils.pick(json, ['id', 'Id'])),
      tourId: JsonUtils.readInt(JsonUtils.pick(json, ['tourId', 'TourId'])),
      title: JsonUtils.readString(JsonUtils.pick(json, ['title', 'Title'])),
      description: JsonUtils.readString(
        JsonUtils.pick(json, ['description', 'Description']),
      ),
      dayNumber: JsonUtils.readInt(
        JsonUtils.pick(json, ['dayNumber', 'DayNumber', 'day']),
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
      tourismInfoId: () {
        final value = JsonUtils.pick(
          json,
          ['tourismInfoId', 'TourismInfoId'],
        );
        return value == null ? null : JsonUtils.readInt(value);
      }(),
    );
  }

  String? get timeLabel {
    final start = startTimeLabel;
    final end = endTimeLabel;
    if (start != null && end != null) return '$start - $end';
    return start ?? end;
  }

  String? get startTimeLabel => _formatTime(startDuration);

  String? get endTimeLabel => _formatTime(endDuration);

  bool get hasCoordinates => locationLat != null && locationLng != null;

  static String? _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    final match = RegExp(
      r'^(?:\d+\.)?(\d{1,2}):(\d{2})',
    ).firstMatch(trimmed);
    if (match == null) return trimmed;
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }
}

class CatalogService extends GetxService with BaseServiceMixin {
  Future<List<CategoryModel>> getCategories() async {
    return request(() async {
      final response = await api.dio.get(ApiConstants.categories);
      return parseList(response.data, CategoryModel.fromJson);
    });
  }

  Future<List<BannerModel>> getBanners() async {
    return request(() async {
      final response = await api.dio.get(ApiConstants.banners);
      return parseList(response.data, BannerModel.fromJson);
    });
  }

  Future<TicketTypeModel> getTicketTypeById(int id) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.ticketTypes}/$id');
      final map = JsonUtils.extractDataMap(response.data);
      if (map == null) {
        throw const FormatException('Invalid ticket type response');
      }
      return TicketTypeModel.fromJson(map);
    });
  }

  Future<TourismInformationModel> getTourismInformationById(int id) async {
    return request(() async {
      final response =
          await api.dio.get('${ApiConstants.tourismInformation}/$id');
      final map = JsonUtils.extractDataMap(response.data);
      if (map == null) {
        throw const FormatException('Invalid tourism information response');
      }
      return TourismInformationModel.fromJson(map);
    });
  }

  Future<List<TourItineraryModel>> getTourItineraries(int tourId) async {
    return request(() async {
      final detail = await api.dio.get('${ApiConstants.tours}/public/$tourId');
      final map = JsonUtils.extractDataMap(detail.data);
      final embedded = map == null
          ? const <Map<String, dynamic>>[]
          : JsonUtils.readMapList(
              JsonUtils.pick(map, ['tourItineraries', 'TourItineraries']),
            );
      if (embedded.isNotEmpty) {
        final itineraries = embedded.map(TourItineraryModel.fromJson).toList();
        itineraries.sort(_compareItineraries);
        return itineraries;
      }

      final response =
          await api.dio.get('${ApiConstants.tours}/$tourId/itineraries');
      final itineraries = parseList(response.data, TourItineraryModel.fromJson);
      itineraries.sort(_compareItineraries);
      return itineraries;
    });
  }

  static int _compareItineraries(
    TourItineraryModel a,
    TourItineraryModel b,
  ) {
    final byDay = (a.dayNumber ?? 0).compareTo(b.dayNumber ?? 0);
    if (byDay != 0) return byDay;
    return (a.startDuration ?? '').compareTo(b.startDuration ?? '');
  }
}
