import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:flutter/scheduler.dart' as scheduler;
import 'package:stayhub_mobile/constants/api_constants.dart';
import 'package:stayhub_mobile/controllers/notification_controller.dart';
import 'package:stayhub_mobile/routes/app_routes.dart';
import 'package:stayhub_mobile/services/api_client.dart';
import 'package:stayhub_mobile/services/signalr_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Hệ thống Android sẽ tự hiển thị notification khi có payload notification.
}

class PushNotificationService extends GetxService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'stayhub_channel';
  static const _channelName = 'Thông báo StayHub';

  Future<PushNotificationService> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    String? token = await _fcm.getToken();
    if (token != null) {
      await syncTokenToBackend();
    }
    _fcm.onTokenRefresh.listen((_) => syncTokenToBackend());

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.startsWith('chat:')) {
          final roomId = int.tryParse(payload.substring(5));
          if (roomId != null) {
            _openChatRoom(roomId);
          }
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotificationTap(message.data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    return this;
  }

  Future<void> syncTokenToBackend() async {
    final token = await _fcm.getToken();
    if (token == null) return;
    await _sendTokenToBackend(token);
  }

  Future<void> showChatNotification({
    required int chatRoomId,
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      chatRoomId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: 'chat:$chatRoomId',
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'chat') {
      final roomId = int.tryParse(data['chatRoomId'] ?? '');
      if (roomId == null) return;

      if (Get.isRegistered<SignalRService>() &&
          Get.find<SignalRService>().activeChatRoomId == roomId) {
        return;
      }

      final title = message.notification?.title ??
          data['senderName'] ??
          'Tin nhắn mới';
      final body = message.notification?.body ??
          data['content'] ??
          'Bạn có tin nhắn mới';

      showChatNotification(
        chatRoomId: roomId,
        title: title,
        body: body,
      );
      return;
    }

    if (message.notification != null) {
      _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );

      if (Get.isRegistered<NotificationController>()) {
        Get.find<NotificationController>().fetchNotifications();
      }
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    if (data['type'] == 'chat') {
      final roomId = int.tryParse(data['chatRoomId']?.toString() ?? '');
      if (roomId != null) {
        _openChatRoom(roomId);
      }
      return;
    }

    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().fetchNotifications();
    }
    Get.toNamed(AppRoutes.notifications);
  }

  void _openChatRoom(int roomId) {
    // Đảm bảo việc điều hướng chỉ xảy ra sau khi frame đầu tiên đã được build,
    // tránh lỗi "setState during build" khi mở app từ notification.
    scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
      Get.toNamed(AppRoutes.chatRoom, arguments: {'roomId': roomId});
    });
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final apiClient = Get.find<ApiClient>();
      await apiClient.put(
        '${ApiConstants.users}/fcm-token',
        data: {'fcmToken': token},
      );
    } catch (e) {
      if (e is DioException) {
        final apiError = Get.find<ApiClient>().parseError(e);
        print('❌ Lỗi gửi FCM Token: ${apiError.message}');
      }
    }
  }
}
