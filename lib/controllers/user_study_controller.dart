import 'package:get/get.dart';
import '../models/api_response.dart';
import '../models/user_study_models.dart';
import '../services/user_study_service.dart';
import '../utils/ai_session.dart';
import '../utils/snackbar_helper.dart';

class UserStudyController extends GetxController {
  final UserStudyService _service = Get.find<UserStudyService>();

  final scenarios = <UserStudyScenarioModel>[].obs;
  final currentComparison = Rxn<UserStudyComparisonModel>();

  final isLoadingScenarios = false.obs;
  final isLoadingComparison = false.obs;
  final isSubmitting = false.obs;

  late final String sessionId;

  @override
  void onInit() {
    super.onInit();
    sessionId = getOrCreateAiSessionId();
    loadScenarios();
  }

  Future<void> loadScenarios() async {
    isLoadingScenarios.value = true;
    try {
      final res = await _service.getScenarios();
      scenarios.assignAll(res);
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Không thể tải danh sách kịch bản');
    } finally {
      isLoadingScenarios.value = false;
    }
  }

  Future<void> loadComparison(int scenarioId) async {
    isLoadingComparison.value = true;
    currentComparison.value = null;
    try {
      final res = await _service.getComparison(
        scenarioId: scenarioId,
        sessionId: sessionId,
      );
      currentComparison.value = res;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
    } catch (e) {
      SnackbarHelper.error('Không thể tải kịch bản so sánh');
    } finally {
      isLoadingComparison.value = false;
    }
  }

  Future<bool> submitResponse({
    required int assignmentId,
    required String preferredList,
    required int fairnessListA,
    required int fairnessListB,
    required int satisfactionListA,
    required int satisfactionListB,
    required int groupFairnessListA,
    required int groupFairnessListB,
    required int wouldBookListA,
    required int wouldBookListB,
    String? ageGroup,
    String? travelExperience,
    String? openComment,
  }) async {
    isSubmitting.value = true;
    try {
      final payload = SubmitUserStudyResponseModel(
        assignmentId: assignmentId,
        sessionId: sessionId,
        preferredList: preferredList,
        fairnessListA: fairnessListA,
        fairnessListB: fairnessListB,
        satisfactionListA: satisfactionListA,
        satisfactionListB: satisfactionListB,
        groupFairnessListA: groupFairnessListA,
        groupFairnessListB: groupFairnessListB,
        wouldBookListA: wouldBookListA,
        wouldBookListB: wouldBookListB,
        ageGroup: ageGroup,
        travelExperience: travelExperience,
        openComment: openComment,
      );

      final result = await _service.submitResponse(payload);
      SnackbarHelper.success(result.message.isNotEmpty
          ? result.message
          : 'Đã lưu phản hồi khảo sát.');

      // Reload current comparison to reflect alreadySubmitted = true
      if (currentComparison.value != null) {
        await loadComparison(currentComparison.value!.scenarioId);
      }
      return true;
    } on ApiError catch (e) {
      SnackbarHelper.error(e.message);
      return false;
    } catch (e) {
      SnackbarHelper.error('Không thể gửi đánh giá');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
