import 'package:get/get.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../constants/api_constants.dart';
import '../models/feature_models.dart';
import 'storage_service.dart';

class SignalRService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();

  HubConnection? _chatConnection;
  HubConnection? _trackingConnection;
  HubConnection? _publicTrackingConnection;

  String? get _token => _storage.accessToken;

  Future<HubConnection> _connectChat() async {
    if (_chatConnection?.state == HubConnectionState.Connected) {
      return _chatConnection!;
    }
    _chatConnection = HubConnectionBuilder()
        .withUrl(
          ApiConstants.chatHubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => _token ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();
    await _chatConnection!.start();
    return _chatConnection!;
  }

  Future<void> joinChatRoom(int roomId) async {
    final conn = await _connectChat();
    await conn.invoke('JoinRoom', args: [roomId]);
  }

  Future<void> leaveChatRoom(int roomId) async {
    if (_chatConnection?.state == HubConnectionState.Connected) {
      await _chatConnection!.invoke('LeaveRoom', args: [roomId]);
    }
  }

  void onReceiveMessage(void Function(ChatMessageModel msg) handler) {
    _chatConnection?.on('ReceiveMessage', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      if (raw is Map<String, dynamic>) {
        handler(ChatMessageModel.fromJson(raw));
      } else if (raw is Map) {
        handler(ChatMessageModel.fromJson(Map<String, dynamic>.from(raw)));
      }
    });
  }

  Future<void> sendChatMessage(int roomId, String content) async {
    final conn = await _connectChat();
    await conn.invoke('SendMessage', args: [roomId, content.trim()]);
  }

  Future<void> disconnectChat() async {
    await _chatConnection?.stop();
    _chatConnection = null;
  }

  Future<HubConnection> connectTracking({
    required void Function(LiveLocationModel loc) onLocationUpdate,
  }) async {
    await _trackingConnection?.stop();
    _trackingConnection = HubConnectionBuilder()
        .withUrl(
          ApiConstants.trackingHubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => _token ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    _trackingConnection!.on('ReceiveTourLocationUpdate', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      if (raw is Map<String, dynamic>) {
        onLocationUpdate(LiveLocationModel.fromJson(raw));
      } else if (raw is Map) {
        onLocationUpdate(
          LiveLocationModel.fromJson(Map<String, dynamic>.from(raw)),
        );
      }
    });

    await _trackingConnection!.start();
    return _trackingConnection!;
  }

  Future<void> joinTourTrackingGroup(int scheduleId) async {
    if (_trackingConnection?.state == HubConnectionState.Connected) {
      await _trackingConnection!.invoke(
        'JoinTourTrackingGroup',
        args: [scheduleId],
      );
    }
  }

  Future<void> disconnectTracking() async {
    await _trackingConnection?.stop();
    _trackingConnection = null;
  }

  /// Hub tracking công khai — không gửi JWT (giống web /track/:token).
  Future<void> connectPublicTracking({
    required String token,
    required void Function(double lat, double lng) onLocationUpdate,
  }) async {
    await _publicTrackingConnection?.stop();
    _publicTrackingConnection = HubConnectionBuilder()
        .withUrl(ApiConstants.trackingHubUrl)
        .withAutomaticReconnect()
        .build();

    _publicTrackingConnection!.on('ReceivePublicLocation', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      Map<String, dynamic>? map;
      if (raw is Map<String, dynamic>) {
        map = raw;
      } else if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      }
      if (map == null) return;
      final lat = (map['lat'] as num?)?.toDouble() ??
          (map['latitude'] as num?)?.toDouble();
      final lng = (map['lng'] as num?)?.toDouble() ??
          (map['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) onLocationUpdate(lat, lng);
    });

    await _publicTrackingConnection!.start();
    await _publicTrackingConnection!.invoke('JoinTrackingGroup', args: [token]);
  }

  Future<void> disconnectPublicTracking() async {
    await _publicTrackingConnection?.stop();
    _publicTrackingConnection = null;
  }

  @override
  void onClose() {
    disconnectChat();
    disconnectTracking();
    disconnectPublicTracking();
    super.onClose();
  }
}
