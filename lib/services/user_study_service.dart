import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../models/user_study_models.dart';
import 'base_service.dart';

class UserStudyService extends GetxService with BaseServiceMixin {
  Future<List<UserStudyScenarioModel>> getScenarios() async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.aiEvaluation}/user-study/scenarios',
      );
      return parseList(response.data, UserStudyScenarioModel.fromJson);
    });
  }

  Future<UserStudyComparisonModel> getComparison({
    required int scenarioId,
    required String sessionId,
  }) async {
    return request(() async {
      final response = await api.dio.get(
        '${ApiConstants.aiEvaluation}/user-study/scenarios/$scenarioId/comparison',
        queryParameters: {'sessionId': sessionId},
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return UserStudyComparisonModel.fromJson(body);
      }
      throw StateError('Invalid comparison response');
    });
  }

  Future<SubmitUserStudyResponseResultModel> submitResponse(
    SubmitUserStudyResponseModel responseModel,
  ) async {
    return request(() async {
      final response = await api.dio.post(
        '${ApiConstants.aiEvaluation}/user-study/responses',
        data: responseModel.toJson(),
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return SubmitUserStudyResponseResultModel.fromJson(body);
      }
      throw StateError('Invalid submit response');
    });
  }
}
