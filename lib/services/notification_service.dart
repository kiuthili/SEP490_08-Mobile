import 'package:get/get.dart';
import 'package:stayhub_mobile/constants/api_constants.dart';
import 'package:stayhub_mobile/models/notification_model.dart';
import 'package:stayhub_mobile/services/base_service.dart';

class NotificationService extends GetxService with BaseServiceMixin {
  Future<List<NotificationModel>> getNotifications() async {
    return request(() async {
      final response = await api.dio.get(ApiConstants.notifications);
      return parseList(response.data, NotificationModel.fromJson);
    });
  }

  Future<void> markAsRead(int id) async {
    await request(() async {
      await api.dio.put('${ApiConstants.notifications}/$id/read');
    });
  }

  Future<void> deleteNotification(int id) async {
    await request(() async {
      await api.dio.delete('${ApiConstants.notifications}/$id');
    });
  }
}