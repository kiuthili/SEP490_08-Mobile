import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:stayhub_mobile/constants/api_constants.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import 'package:stayhub_mobile/services/api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Đã nhận thông báo khi tắt app: ${message.messageId}");
}

class PushNotificationService extends GetxService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<PushNotificationService> init() async {
    // 1. Xin quyền thông báo
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2. Lấy FCM Token
    String? token = await _fcm.getToken();
    if (token != null) {
      print("🔔 FCM TOKEN: $token");
      await _sendTokenToBackend(token);
    }
    _fcm.onTokenRefresh.listen(_sendTokenToBackend);

    // 3. Cấu hình local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // ✅ Tạo Android Notification Channel (bắt buộc Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'stayhub_channel',
      'Thông báo StayHub',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation
    <AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ✅ Xử lý tap khi app đang TẮT HOÀN TOÀN
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotificationTap(message.data);
    });

    // ✅ Xử lý tap khi app đang BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });

    // 4. Foreground - app đang mở
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _localNotifications.show(
          id: DateTime.now().millisecondsSinceEpoch % 100000, // ✅ fix tránh trùng id
          title: message.notification!.title,
          body: message.notification!.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'stayhub_channel',
              'Thông báo StayHub',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              presentBadge: true,
            ),
          ),
        );

        if (Get.isRegistered<NotificationController>()) {
          Get.find<NotificationController>().fetchNotifications();
        }
      }
    });

    // 5. Background - app đang tắt ngầm
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    return this;
  }

  // ✅ Xử lý khi user tap vào thông báo
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().fetchNotifications();
    }
    // Điều hướng nếu cần, ví dụ:
    // Get.toNamed('/notifications');
  }

  // Gửi FCM Token lên Backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final apiClient = Get.find<ApiClient>();
      await apiClient.put(
        ApiConstants.users + '/fcm-token',
        data: {'fcmToken': token},
      );
      print("✅ Đã gửi FCM Token lên Backend thành công!");
    } catch (e) {
      if (e is DioException) {
        final apiError = Get.find<ApiClient>().parseError(e);
        print("❌ Lỗi gửi FCM Token: ${apiError.message}");
      } else {
        print("❌ Lỗi không xác định: $e");
      }
    }
  }
}