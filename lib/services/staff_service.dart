import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../models/assigned_schedule_model.dart';
import 'base_service.dart';

class StaffScheduleService extends GetxService with BaseServiceMixin {
  /// GET /api/TourScheduleStaffs/assigned
  Future<PaginationModel<AssignedScheduleModel>> getAssignedSchedules({
    int page = 1,
    int pageSize = 10,
    bool upcomingOnly = false,
    String? tourName,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.tourScheduleStaffs}/assigned',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'upcomingOnly': upcomingOnly,
          if (tourName != null && tourName.trim().isNotEmpty)
            'tourName': tourName.trim(),
        },
      );

      final body = response.data;
      if (body is Map<String, dynamic>) {
        return PaginationModel.fromJson(body, AssignedScheduleModel.fromJson);
      }
      throw StateError('Unexpected response format for assigned schedules');
    });
  }

}