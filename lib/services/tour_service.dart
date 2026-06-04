import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../models/tour_model.dart';
import '../utils/json_utils.dart';
import 'base_service.dart';

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

  Future<TourModel> getPublicTourDetail(int id) async {
    return request(() async {
      final response = await api.dio.get('${ApiConstants.tours}/public/$id');
      return parseData(response.data, TourModel.fromJson);
    });
  }

  Future<List<TourScheduleModel>> getSchedulesByTour(int tourId) async {
    return request(() async {
      // Ưu tiên lịch nhúng trong GET /api/tours/public/{id}
      try {
        final detail = await api.dio.get(
          '${ApiConstants.tours}/public/$tourId',
        );
        final map = JsonUtils.extractDataMap(detail.data);
        if (map != null) {
          final embedded = JsonUtils.readMapList(
            JsonUtils.pick(map, ['tourSchedules', 'TourSchedules']),
          );
          if (embedded.isNotEmpty) {
            return embedded.map(TourScheduleModel.fromJson).toList();
          }
        }
      } catch (_) {}

      final response = await api.dio.get(ApiConstants.tourSchedules);
      final all = parseList(response.data, TourScheduleModel.fromJson);
      return all.where((s) => s.tourId == tourId).toList();
    });
  }

  Future<TourScheduleModel> getScheduleDetail(int id) async {
    return request(() async {
      final response =
          await api.dio.get('${ApiConstants.tourSchedules}/$id');
      return parseData(response.data, TourScheduleModel.fromJson);
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
