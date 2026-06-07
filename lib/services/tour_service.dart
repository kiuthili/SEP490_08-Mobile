import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../models/tour_model.dart';
import '../utils/json_utils.dart';
import 'base_service.dart';

class TourDetailResult {
  const TourDetailResult({
    required this.tour,
    required this.schedules,
  });

  final TourModel tour;
  final List<TourScheduleModel> schedules;
}

class TourService extends GetxService with BaseServiceMixin {
  Future<PaginationModel<TourModel>> getPublicTours({
    int page = 1,
    int pageSize = AppConstants.defaultPageSize,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tours}/public',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return parsePagination(response.data, TourModel.fromJson);
    });
  }

  Future<PaginationModel<TourModel>> searchTours({
    int page = 1,
    int pageSize = AppConstants.defaultPageSize,
    String? searchTerm,
    String? country,
    String? city,
    int? categoryId,
    int? minPrice,
    int? maxPrice,
    String? startDate,
    String? endDate,
    int? duration,
    String? sortBy,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tours}/search',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (searchTerm != null && searchTerm.isNotEmpty)
            'searchTerm': searchTerm,
          if (country != null && country.isNotEmpty) 'country': country,
          if (city != null && city.isNotEmpty) 'city': city,
          if (categoryId != null) 'categoryId': categoryId,
          if (minPrice != null && minPrice > 0) 'minPrice': minPrice,
          if (maxPrice != null && maxPrice > 0) 'maxPrice': maxPrice,
          if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
          if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
          if (duration != null && duration > 0) 'duration': duration,
          if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
        },
      );
      return parsePagination(response.data, TourModel.fromJson);
    });
  }

  Future<TourDetailResult> getPublicTourDetail(int id) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.tours}/public/$id');
      final map = JsonUtils.extractDataMap(response.data);
      if (map == null) {
        throw StateError('Unexpected tour detail response');
      }

      final schedules = JsonUtils.readMapList(
        JsonUtils.pick(map, ['tourSchedules', 'TourSchedules']),
      ).map(TourScheduleModel.fromJson).toList()
        ..sort((a, b) => a.departureDate.compareTo(b.departureDate));

      return TourDetailResult(
        tour: TourModel.fromJson(map),
        schedules: schedules,
      );
    });
  }

  Future<TourScheduleModel> getScheduleById(int id) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.tourSchedules}/$id');
      return parseData(response.data, TourScheduleModel.fromJson);
    });
  }

  Future<TourScheduleModel> getScheduleDetail(int id) => getScheduleById(id);

  Future<List<TourScheduleItineraryModel>> getScheduleItineraries(
    int scheduleId,
  ) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tourScheduleItineraries}/schedule/$scheduleId',
      );
      final itineraries = parseList(
        response.data,
        TourScheduleItineraryModel.fromJson,
      );
      itineraries.sort((a, b) {
        final byDay = a.dayNumber.compareTo(b.dayNumber);
        if (byDay != 0) return byDay;
        return (a.startDuration ?? '').compareTo(b.startDuration ?? '');
      });
      return itineraries;
    });
  }

  Future<List<ScheduleTicketModel>> getScheduleTickets(int scheduleId) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tourScheduleTickets}/schedule/$scheduleId',
      );
      return parseList(response.data, ScheduleTicketModel.fromJson);
    });
  }

  Future<List<AssignedScheduleModel>> getAssignedSchedules() async {
    return request(() async {
      final response =
          await api.dio.get('${ApiConstants.tourSchedules}/assigned');
      return parseList(response.data, AssignedScheduleModel.fromJson);
    });
  }
}
