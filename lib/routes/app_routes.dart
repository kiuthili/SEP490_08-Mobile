class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String tourDetail = '/tour-detail';
  static const String booking = '/booking';
  static const String orders = '/orders';
  static const String orderDetail = '/order-detail';
  static const String notifications = '/notifications';
  static const String wishlist = '/wishlist';
  static const String vouchers = '/vouchers';
  static const String editProfile = '/edit-profile';
  static const String changePassword = '/change-password';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String socialMap = '/social-map';
  static const String shareMoment = '/share-moment';
  static const String qrScan = '/qr-scan';
  static const String chatInbox = '/chat-inbox';
  static const String chatRoom = '/chat-room';
  static const String newMessage = '/new-message';
  static const String momentDetail = '/moment-detail';
  static const String userProfile = '/user-profile';
  static const String payment = '/payment';
  static const String myTickets = '/my-tickets';
  static const String myReviews = '/my-reviews';
  static const String requestCancellation = '/request-cancellation/:orderId';
  static String requestCancellationFor(int orderId) =>
      '/request-cancellation/$orderId';
  static const String aiRecommendations = '/ai-recommendations';
  static const String aiQuestionnaire = '/ai-assistant';
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String bookingTerms = '/booking-terms';
  static const String publicTrack = '/track/:token';
  static const String userStudy = '/user-study';
  static const String tourSearch = '/tour-search';
  static const String sectionTours = '/tours/section';
  static const String searchResult = '/search-result';
  static const String footprint = '/footprint';
}
