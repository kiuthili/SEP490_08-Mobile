import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../constants/api_constants.dart';
import '../models/feature_models.dart';
import 'storage_service.dart';

class SignalRService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();

  HubConnection? _chatConnection;
  HubConnection? _friendshipConnection;
  HubConnection? _trackingConnection;
  HubConnection? _publicTrackingConnection;
  HubConnection? _notificationConnection;
  HubConnection? _globalChatConnection;
  String? _chatToken;
  String? _friendshipToken;
  String? _notificationToken;
  String? _globalChatToken;
  void Function(ChatMessageModel msg)? _messageHandler;
  void Function(ChatMessageModel msg)? _globalChatHandler;
  void Function()? _friendRequestHandler;
  void Function(int responderId, String status)? _friendResponseHandler;
  void Function(int userId)? _friendshipDeletedHandler;
  void Function()? _friendshipReconnectedHandler;
  void Function(Map<String, dynamic> notification)? _notificationHandler;
  void Function()? _notificationReconnectedHandler;
  Future<HubConnection>? _chatConnecting;
  Future<HubConnection>? _friendshipConnecting;
  Future<HubConnection>? _notificationConnecting;
  Future<HubConnection>? _globalChatConnecting;

  int? activeChatRoomId;

  String? get _token => _storage.accessToken;

  // ===========================================================================
  // CHAT (giữ nguyên, không đổi)
  // ===========================================================================

  Future<HubConnection> _connectChat() async {
    final token = _token;
    final current = _chatConnection;
    if (current?.state == HubConnectionState.Connected && _chatToken == token) {
      return current!;
    }

    final pending = _chatConnecting;
    if (pending != null) {
      return pending;
    }

    if (token == null || token.isEmpty) {
      throw StateError('Bạn cần đăng nhập để dùng chat');
    }

    final connecting = _establishChatConnection(token);
    _chatConnecting = connecting;
    try {
      return await connecting;
    } finally {
      if (identical(_chatConnecting, connecting)) {
        _chatConnecting = null;
      }
    }
  }

  Future<HubConnection> _establishChatConnection(String token) async {
    final oldConnection = _chatConnection;
    _chatConnection = null;
    if (oldConnection != null) {
      try {
        await oldConnection.stop();
      } catch (_) {
        // The stale connection may already be stopped by automatic reconnect.
      }
    }

    _chatToken = token;
    final connection = HubConnectionBuilder()
        .withUrl(
      ApiConstants.chatHubUrl,
      options: _connectionOptions(
        accessTokenFactory: () async => _chatToken ?? '',
      ),
    )
        .withAutomaticReconnect()
        .build();
    _chatConnection = connection;
    _bindMessageHandler();
    await connection.start();
    await _waitUntilConnected(connection);
    return connection;
  }

  Future<void> _waitUntilConnected(HubConnection connection) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (connection.state == HubConnectionState.Connected) return;
      await Future<void>.delayed(const Duration(milliseconds: 125));
    }
    throw StateError('Không thể thiết lập kết nối');
  }

  Future<void> joinChatRoom(int roomId) async {
    try {
      final conn = await _connectChat();
      await _waitUntilConnected(conn);
      await conn.invoke('JoinRoom', args: [roomId]);
    } catch (_) {
      await disconnectChat(keepHandler: true);
      final conn = await _connectChat();
      await _waitUntilConnected(conn);
      await conn.invoke('JoinRoom', args: [roomId]);
    }
  }

  Future<void> leaveChatRoom(int roomId) async {
    if (_chatConnection?.state == HubConnectionState.Connected) {
      await _chatConnection!.invoke('LeaveRoom', args: [roomId]);
    }
  }

  void onReceiveMessage(void Function(ChatMessageModel msg) handler) {
    _messageHandler = handler;
    _bindMessageHandler();
  }

  void _bindMessageHandler() {
    final handler = _messageHandler;
    if (handler == null || _chatConnection == null) return;
    _chatConnection?.off('ReceiveMessage');
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
    final text = content.trim();
    if (text.isEmpty) return;
    try {
      final conn = await _connectChat();
      await _waitUntilConnected(conn);
      await conn.invoke('SendMessage', args: [roomId, text]);
    } catch (_) {
      await disconnectChat(keepHandler: true);
      final conn = await _connectChat();
      await _waitUntilConnected(conn);
      await conn.invoke('JoinRoom', args: [roomId]);
      await conn.invoke('SendMessage', args: [roomId, text]);
    }
  }

  Future<void> disconnectChat({bool keepHandler = false}) async {
    final pending = _chatConnecting;
    _chatConnecting = null;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Connection setup already failed; continue clearing local state.
      }
    }
    await _chatConnection?.stop();
    _chatConnection = null;
    _chatToken = null;
    if (!keepHandler) _messageHandler = null;
  }

  // ===========================================================================
  // FRIENDSHIP (giữ nguyên, không đổi)
  // ===========================================================================

  Future<void> connectFriendship({
    required void Function() onFriendRequest,
    required void Function(int responderId, String status) onRequestResponded,
    required void Function(int userId) onFriendshipDeleted,
    required void Function() onReconnected,
  }) async {
    _friendRequestHandler = onFriendRequest;
    _friendResponseHandler = onRequestResponded;
    _friendshipDeletedHandler = onFriendshipDeleted;
    _friendshipReconnectedHandler = onReconnected;
    await _connectFriendship();
  }

  Future<HubConnection> _connectFriendship() async {
    final token = _token;
    final current = _friendshipConnection;
    if (current?.state == HubConnectionState.Connected &&
        _friendshipToken == token) {
      _bindFriendshipHandlers();
      return current!;
    }

    final pending = _friendshipConnecting;
    if (pending != null) return pending;
    if (token == null || token.isEmpty) {
      throw StateError('Bạn cần đăng nhập để nhận cập nhật bạn bè');
    }

    final connecting = _establishFriendshipConnection(token);
    _friendshipConnecting = connecting;
    try {
      return await connecting;
    } finally {
      if (identical(_friendshipConnecting, connecting)) {
        _friendshipConnecting = null;
      }
    }
  }

  Future<HubConnection> _establishFriendshipConnection(String token) async {
    final oldConnection = _friendshipConnection;
    _friendshipConnection = null;
    if (oldConnection != null) {
      try {
        await oldConnection.stop();
      } catch (_) {}
    }

    _friendshipToken = token;
    final connection = HubConnectionBuilder()
        .withUrl(
      ApiConstants.friendshipHubUrl,
      options: _connectionOptions(
        accessTokenFactory: () async => _friendshipToken ?? '',
      ),
    )
        .withAutomaticReconnect()
        .build();
    _friendshipConnection = connection;
    _bindFriendshipHandlers();
    connection.onreconnected(
          ({connectionId}) {
        _friendshipReconnectedHandler?.call();
      },
    );
    await connection.start();
    await _waitUntilConnected(connection);
    return connection;
  }

  void _bindFriendshipHandlers() {
    final connection = _friendshipConnection;
    if (connection == null) return;

    connection.off('ReceiveFriendRequest');
    connection.on('ReceiveFriendRequest', (_) {
      _friendRequestHandler?.call();
    });

    connection.off('FriendRequestResponded');
    connection.on('FriendRequestResponded', (args) {
      if (args == null || args.length < 2) return;
      final responderId = _readInt(args[0]);
      final status = args[1]?.toString() ?? '';
      if (responderId != null) {
        _friendResponseHandler?.call(responderId, status);
      }
    });

    connection.off('FriendshipDeleted');
    connection.on('FriendshipDeleted', (args) {
      if (args == null || args.isEmpty) return;
      final userId = _readInt(args[0]);
      if (userId != null) _friendshipDeletedHandler?.call(userId);
    });
  }

  Future<void> disconnectFriendship({bool keepHandlers = false}) async {
    final pending = _friendshipConnecting;
    _friendshipConnecting = null;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    await _friendshipConnection?.stop();
    _friendshipConnection = null;
    _friendshipToken = null;
    if (!keepHandlers) {
      _friendRequestHandler = null;
      _friendResponseHandler = null;
      _friendshipDeletedHandler = null;
      _friendshipReconnectedHandler = null;
    }
  }

  // ===========================================================================
  // NOTIFICATION (mới thêm — theo đúng pattern của Friendship)
  // ===========================================================================

  /// Kết nối NotificationHub để nhận thông báo realtime.
  /// Gọi sau khi login thành công, ví dụ trong AuthController hoặc HomeController.
  Future<void> connectNotification({
    required void Function(Map<String, dynamic> notification) onNotification,
    void Function()? onReconnected,
  }) async {
    _notificationHandler = onNotification;
    _notificationReconnectedHandler = onReconnected;
    await _connectNotification();
  }

  Future<HubConnection> _connectNotification() async {
    final token = _token;
    final current = _notificationConnection;
    if (current?.state == HubConnectionState.Connected &&
        _notificationToken == token) {
      _bindNotificationHandlers();
      return current!;
    }

    final pending = _notificationConnecting;
    if (pending != null) return pending;
    if (token == null || token.isEmpty) {
      throw StateError('Bạn cần đăng nhập để nhận thông báo');
    }

    final connecting = _establishNotificationConnection(token);
    _notificationConnecting = connecting;
    try {
      return await connecting;
    } finally {
      if (identical(_notificationConnecting, connecting)) {
        _notificationConnecting = null;
      }
    }
  }

  Future<HubConnection> _establishNotificationConnection(String token) async {
    final oldConnection = _notificationConnection;
    _notificationConnection = null;
    if (oldConnection != null) {
      try {
        await oldConnection.stop();
      } catch (_) {}
    }

    _notificationToken = token;
    final connection = HubConnectionBuilder()
        .withUrl(
      ApiConstants.notificationHubUrl,
      options: _connectionOptions(
        accessTokenFactory: () async => _notificationToken ?? '',
      ),
    )
        .withAutomaticReconnect()
        .build();
    _notificationConnection = connection;
    _bindNotificationHandlers();
    connection.onreconnected(
          ({connectionId}) {
        _notificationReconnectedHandler?.call();
      },
    );
    await connection.start();
    await _waitUntilConnected(connection);
    return connection;
  }

  void _bindNotificationHandlers() {
    final connection = _notificationConnection;
    final handler = _notificationHandler;
    if (connection == null || handler == null) return;

    connection.off('ReceiveNewNotification');
    connection.on('ReceiveNewNotification', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      if (raw is Map<String, dynamic>) {
        handler(raw);
      } else if (raw is Map) {
        handler(Map<String, dynamic>.from(raw));
      }
    });
  }

  Future<void> disconnectNotification({bool keepHandlers = false}) async {
    final pending = _notificationConnecting;
    _notificationConnecting = null;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    await _notificationConnection?.stop();
    _notificationConnection = null;
    _notificationToken = null;
    if (!keepHandlers) {
      _notificationHandler = null;
      _notificationReconnectedHandler = null;
    }
  }

  // ===========================================================================
  // GLOBAL CHAT (nhận tin nhắn khi không ở trong phòng chat)
  // ===========================================================================

  Future<void> connectGlobalChat({
    required void Function(ChatMessageModel msg) onGlobalMessage,
    void Function()? onReconnected,
  }) async {
    _globalChatHandler = onGlobalMessage;
    await _connectGlobalChat(onReconnected: onReconnected);
  }

  Future<HubConnection> _connectGlobalChat({void Function()? onReconnected}) async {
    final token = _token;
    final current = _globalChatConnection;
    if (current?.state == HubConnectionState.Connected &&
        _globalChatToken == token) {
      _bindGlobalChatHandlers();
      return current!;
    }

    final pending = _globalChatConnecting;
    if (pending != null) return pending;
    if (token == null || token.isEmpty) {
      throw StateError('Bạn cần đăng nhập để nhận tin nhắn');
    }

    final connecting = _establishGlobalChatConnection(token, onReconnected);
    _globalChatConnecting = connecting;
    try {
      return await connecting;
    } finally {
      if (identical(_globalChatConnecting, connecting)) {
        _globalChatConnecting = null;
      }
    }
  }

  Future<HubConnection> _establishGlobalChatConnection(
    String token,
    void Function()? onReconnected,
  ) async {
    final oldConnection = _globalChatConnection;
    _globalChatConnection = null;
    if (oldConnection != null) {
      try {
        await oldConnection.stop();
      } catch (_) {}
    }

    _globalChatToken = token;
    final connection = HubConnectionBuilder()
        .withUrl(
      ApiConstants.globalChatHubUrl,
      options: _connectionOptions(
        accessTokenFactory: () async => _globalChatToken ?? '',
      ),
    )
        .withAutomaticReconnect()
        .build();
    _globalChatConnection = connection;
    _bindGlobalChatHandlers();
    connection.onreconnected(({connectionId}) {
      onReconnected?.call();
    });
    await connection.start();
    await _waitUntilConnected(connection);
    return connection;
  }

  void _bindGlobalChatHandlers() {
    final connection = _globalChatConnection;
    final handler = _globalChatHandler;
    if (connection == null || handler == null) return;

    connection.off('ReceiveGlobalNotification');
    connection.on('ReceiveGlobalNotification', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      if (raw is Map<String, dynamic>) {
        handler(ChatMessageModel.fromJson(raw));
      } else if (raw is Map) {
        handler(ChatMessageModel.fromJson(Map<String, dynamic>.from(raw)));
      }
    });
  }

  Future<void> disconnectGlobalChat({bool keepHandler = false}) async {
    final pending = _globalChatConnecting;
    _globalChatConnecting = null;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    await _globalChatConnection?.stop();
    _globalChatConnection = null;
    _globalChatToken = null;
    activeChatRoomId = null;
    if (!keepHandler) _globalChatHandler = null;
  }

  void setActiveChatRoom(int? roomId) {
    activeChatRoomId = roomId;
  }

  // ===========================================================================
  // TRACKING (giữ nguyên, không đổi)
  // ===========================================================================

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<HubConnection> connectTracking({
    required void Function(LiveLocationModel loc) onLocationUpdate,
  }) async {
    await _trackingConnection?.stop();
    _trackingConnection = HubConnectionBuilder()
        .withUrl(
      ApiConstants.trackingHubUrl,
      options: _connectionOptions(
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
        .withUrl(ApiConstants.trackingHubUrl, options: _connectionOptions())
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
    disconnectFriendship();
    disconnectNotification();
    disconnectGlobalChat();
    disconnectTracking();
    disconnectPublicTracking();
    super.onClose();
  }

  HttpConnectionOptions _connectionOptions({
    AccessTokenFactory? accessTokenFactory,
  }) {
    final localDev = _isLocalDevBaseUrl(ApiConstants.baseUrl);
    return HttpConnectionOptions(
      accessTokenFactory: accessTokenFactory,
      httpClient: localDev
          ? WebSupportingHttpClient(
        null,
        httpClientCreateCallback: (_) {
          HttpOverrides.global = _SignalRLocalDevHttpOverrides();
        },
      )
          : null,
      transport: localDev ? HttpTransportType.WebSockets : null,
      requestTimeout: 30000,
    );
  }

  bool _isLocalDevBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return true;
    }
    if (host.startsWith('127.') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.')) {
      return true;
    }
    final parts = host.split('.');
    if (parts.length != 4 || parts.first != '172') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }
}

class _SignalRLocalDevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, host, __) => _isLocalDevHost(host);
  }

  bool _isLocalDevHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' ||
        normalized == '::1' ||
        normalized == '10.0.2.2' ||
        normalized == '127.0.0.1') {
      return true;
    }
    if (normalized.startsWith('127.') ||
        normalized.startsWith('10.') ||
        normalized.startsWith('192.168.')) {
      return true;
    }
    final parts = normalized.split('.');
    if (parts.length != 4 || parts.first != '172') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }
}