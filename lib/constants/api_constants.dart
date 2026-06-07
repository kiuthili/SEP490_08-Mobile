import 'dart:io';

/// API endpoints qua GatewayAPI (YARP reverse proxy).
class ApiConstants {
  ApiConstants._();

  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    // Android emulator reaches the host machine through 10.0.2.2.
    if (Platform.isAndroid) return 'https://192.168.1.174:7010';
    return 'https://localhost:7010';
  }

  /// SignalR hubs qua Gateway — route `social-signalr-route` → `/hubs/*`
  static String get chatHubUrl => '$baseUrl/hubs/chat';
  static String get trackingHubUrl => '$baseUrl/hubs/tracking';

  /// Google OAuth Web Client ID (dùng cho cả Android/iOS)
  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const auth = '/api/auth';
  static const vnpay = '/api/vnpay';
  static const momo = '/api/momo';
  static const categories = '/api/categories';
  static const banners = '/api/banners';
  static const tourismInformation = '/api/tourisminformation';
  static const users = '/api/users';
  static const tours = '/api/tours';
  static const tourSchedules = '/api/TourSchedules';
  static const tourScheduleItineraries = '/api/TourScheduleItineraries';
  static const tourScheduleTickets = '/api/TourScheduleTickets';
  static const wishlists = '/api/wishlists';
  static const reviews = '/api/reviews';
  static const orders = '/api/orders';
  static const tickets = '/api/tickets';
  static const cancellationRequest = '/api/CancellationRequest';
  static const customerVouchers = '/api/customer/vouchers';
  static const notifications = '/api/notifications';
  static const friends = '/api/friends';
  static const moments = '/api/moments';
  static const chat = '/api/chat';
  static const locations = '/api/locations';
  static const aiTourAssistant = '/api/ai/tour-assistant';
}
