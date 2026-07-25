import 'dart:io';

void main() {
  final enKeys = {
    'sc_sds_chat': 'Messages',
    'sc_sds_direct_message': 'Direct Message',
    'sc_sds_chat_not_found': 'Conversation not found',
    'sc_sds_location_shared': 'Location shared successfully',
    'sc_sds_location_share_failed': 'Cannot share location at this time.',
    'sc_sds_location_share_error': 'Error sharing location.',
    'sc_sds_tour_group_chat': 'Tour Group Chat',
    'sc_sds_active_now': 'Active now',
    'sc_sds_leave_group': 'Leave group',
    'sc_sds_connecting_chat': 'Connecting to chat...',
    'sc_sds_tour_group_caps': 'TOUR GROUP',
    'sc_sds_no_schedule_info': 'No departure schedule info',
    'sc_sds_loading_schedule': 'Loading schedule info...',
    'sc_sds_failed_load_schedule': 'Failed to load departure schedule',
    'sc_sds_retry': 'Retry',
    'sc_sds_hello_group': 'Hello everyone!',
    'sc_sds_start_chat': 'Start conversation',
    'sc_sds_group_chat_desc': 'Discuss itinerary and connect with fellow travelers.',
    'sc_sds_direct_chat_desc': 'Send a greeting to start chatting on StayHub.',
    'sc_sds_moment_caps': 'MOMENT',
    'sc_sds_live_location_caps': 'LIVE LOCATION',
    'sc_sds_track_location_desc': 'Tap to track my live location.',
    'sc_sds_view_location': 'View location',
    'sc_sds_input_message': 'Type a message...',
    'sc_sds_failed_connect_chat': 'Failed to connect to chat',
    'sc_sds_failed_load_profile': 'Failed to load user profile',
    'sc_sds_profile': 'Profile',
    'sc_sds_not_found': 'Not found',
    'sc_sds_loading_posts': 'Loading posts...',
    'sc_sds_posts': 'Posts',
    'sc_sds_friends': 'Friends',
    'sc_sds_member': 'Member',
    'sc_sds_relationship': 'Relationship',
    'sc_sds_accept': 'Accept',
    'sc_sds_sent': 'Sent',
    'sc_sds_add_friend': 'Add Friend',
    'sc_sds_message_action': 'Message',
    'sc_sds_no_posts_yet': 'No posts yet',
    'sc_sds_stayhub_user': 'StayHub User',
    'sc_sds_stayhub_member': 'StayHub Member',
    'sc_sds_already_friends': 'Friends',
    'sc_sds_request_sent': 'Request Sent',
    'sc_sds_not_updated': 'Not updated',
    'sc_sds_personal_info': 'Personal Information',
    'sc_sds_full_name': 'Full Name',
    'sc_sds_gender': 'Gender',
    'sc_sds_dob': 'Date of Birth',
    'sc_sds_joined_since': 'Joined since',
    'sc_sds_view_all_comments': 'View all comments',
    'sc_sds_live_location_prefix': '📍 My live location: ',
    'sc_sds_failed_send_message_prefix': 'Failed to send message. ',
    'sc_sds_days': ' days',
    'sc_sds_likes': ' likes',
  };

  final viKeys = {
    'sc_sds_chat': 'Tin nhắn',
    'sc_sds_direct_message': 'Tin nhắn riêng',
    'sc_sds_chat_not_found': 'Không xác định được cuộc trò chuyện',
    'sc_sds_location_shared': 'Đã chia sẻ vị trí thành công',
    'sc_sds_location_share_failed': 'Không thể chia sẻ vị trí lúc này.',
    'sc_sds_location_share_error': 'Lỗi khi chia sẻ vị trí.',
    'sc_sds_tour_group_chat': 'Nhóm trò chuyện tour',
    'sc_sds_active_now': 'Đang hoạt động',
    'sc_sds_leave_group': 'Rời nhóm',
    'sc_sds_connecting_chat': 'Đang kết nối cuộc trò chuyện...',
    'sc_sds_tour_group_caps': 'NHÓM TOUR',
    'sc_sds_no_schedule_info': 'Không có thông tin lịch khởi hành',
    'sc_sds_loading_schedule': 'Đang tải thông tin lịch...',
    'sc_sds_failed_load_schedule': 'Chưa tải được lịch khởi hành',
    'sc_sds_retry': 'Thử lại',
    'sc_sds_hello_group': 'Chào cả đoàn nào!',
    'sc_sds_start_chat': 'Bắt đầu cuộc trò chuyện',
    'sc_sds_group_chat_desc': 'Trao đổi lịch trình và kết nối với những người cùng chuyến đi.',
    'sc_sds_direct_chat_desc': 'Gửi một lời chào để bắt đầu nhắn tin trên StayHub.',
    'sc_sds_moment_caps': 'KHOẢNH KHẮC',
    'sc_sds_live_location_caps': 'VỊ TRÍ TRỰC TIẾP',
    'sc_sds_track_location_desc': 'Bấm để theo dõi lộ trình di chuyển trực tuyến của tôi.',
    'sc_sds_view_location': 'Xem vị trí',
    'sc_sds_input_message': 'Nhập tin nhắn...',
    'sc_sds_failed_connect_chat': 'Không kết nối được chat',
    'sc_sds_failed_load_profile': 'Không thể tải hồ sơ người dùng',
    'sc_sds_profile': 'Hồ sơ',
    'sc_sds_not_found': 'Không tìm thấy',
    'sc_sds_loading_posts': 'Đang tải bài viết...',
    'sc_sds_posts': 'Bài viết',
    'sc_sds_friends': 'Bạn bè',
    'sc_sds_member': 'Thành viên',
    'sc_sds_relationship': 'Quan hệ',
    'sc_sds_accept': 'Chấp nhận',
    'sc_sds_sent': 'Đã gửi',
    'sc_sds_add_friend': 'Kết bạn',
    'sc_sds_message_action': 'Nhắn tin',
    'sc_sds_no_posts_yet': 'Chưa có bài viết nào',
    'sc_sds_stayhub_user': 'Người dùng StayHub',
    'sc_sds_stayhub_member': 'Thành viên StayHub',
    'sc_sds_already_friends': 'Đã là bạn bè',
    'sc_sds_request_sent': 'Đã gửi lời mời',
    'sc_sds_not_updated': 'Chưa cập nhật',
    'sc_sds_personal_info': 'Thông tin cá nhân',
    'sc_sds_full_name': 'Họ và tên',
    'sc_sds_gender': 'Giới tính',
    'sc_sds_dob': 'Ngày sinh',
    'sc_sds_joined_since': 'Tham gia từ',
    'sc_sds_view_all_comments': 'Xem tất cả bình luận',
    'sc_sds_live_location_prefix': '📍 Vị trí hiện tại của tôi: ',
    'sc_sds_failed_send_message_prefix': 'Không gửi được tin nhắn. ',
    'sc_sds_days': ' ngày',
    'sc_sds_likes': ' lượt thích',
  };

  final transFile = File('lib/utils/app_translations.dart');
  var trans = transFile.readAsStringSync();
  
  final enStr = enKeys.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Log out'", "          'pt_logout': 'Log out',\n$enStr");

  final viStr = viKeys.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Đăng xuất'", "          'pt_logout': 'Đăng xuất',\n$viStr");
  
  transFile.writeAsStringSync(trans);
  
  final file = File('lib/screens/customer/social_detail_screens.dart');
  var text = file.readAsStringSync();
  
  final replaceMap = {
    "'Tin nhắn'": "'sc_sds_chat'.tr",
    "'Tin nhắn riêng'": "'sc_sds_direct_message'.tr",
    "'Không xác định được cuộc trò chuyện'": "'sc_sds_chat_not_found'.tr",
    "'Đã chia sẻ vị trí thành công'": "'sc_sds_location_shared'.tr",
    "'Không thể chia sẻ vị trí lúc này.'": "'sc_sds_location_share_failed'.tr",
    "'Lỗi khi chia sẻ vị trí.'": "'sc_sds_location_share_error'.tr",
    "'Nhóm trò chuyện tour'": "'sc_sds_tour_group_chat'.tr",
    "'Đang hoạt động'": "'sc_sds_active_now'.tr",
    "'Rời nhóm'": "'sc_sds_leave_group'.tr",
    "'Đang kết nối cuộc trò chuyện...'": "'sc_sds_connecting_chat'.tr",
    "'NHÓM TOUR'": "'sc_sds_tour_group_caps'.tr",
    "'Không có thông tin lịch khởi hành'": "'sc_sds_no_schedule_info'.tr",
    "'Đang tải thông tin lịch...'": "'sc_sds_loading_schedule'.tr",
    "'Chưa tải được lịch khởi hành'": "'sc_sds_failed_load_schedule'.tr",
    "'Thử lại'": "'sc_sds_retry'.tr",
    "'Chào cả đoàn nào!'": "'sc_sds_hello_group'.tr",
    "'Bắt đầu cuộc trò chuyện'": "'sc_sds_start_chat'.tr",
    "'Trao đổi lịch trình và kết nối với những người cùng chuyến đi.'": "'sc_sds_group_chat_desc'.tr",
    "'Gửi một lời chào để bắt đầu nhắn tin trên StayHub.'": "'sc_sds_direct_chat_desc'.tr",
    "'KHOẢNH KHẮC'": "'sc_sds_moment_caps'.tr",
    "'VỊ TRÍ TRỰC TIẾP'": "'sc_sds_live_location_caps'.tr",
    "'Bấm để theo dõi lộ trình di chuyển trực tuyến của tôi.'": "'sc_sds_track_location_desc'.tr",
    "'Xem vị trí'": "'sc_sds_view_location'.tr",
    "'Nhập tin nhắn...'": "'sc_sds_input_message'.tr",
    "'Không kết nối được chat'": "'sc_sds_failed_connect_chat'.tr",
    "'Không thể tải hồ sơ người dùng'": "'sc_sds_failed_load_profile'.tr",
    "'Hồ sơ'": "'sc_sds_profile'.tr",
    "'Không tìm thấy'": "'sc_sds_not_found'.tr",
    "'Đang tải bài viết...'": "'sc_sds_loading_posts'.tr",
    "'Bài viết'": "'sc_sds_posts'.tr",
    "'Bạn bè'": "'sc_sds_friends'.tr",
    "'Thành viên'": "'sc_sds_member'.tr",
    "'Quan hệ'": "'sc_sds_relationship'.tr",
    "'Chấp nhận'": "'sc_sds_accept'.tr",
    "'Đã gửi'": "'sc_sds_sent'.tr",
    "'Kết bạn'": "'sc_sds_add_friend'.tr",
    "'Nhắn tin'": "'sc_sds_message_action'.tr",
    "'Chưa có bài viết nào'": "'sc_sds_no_posts_yet'.tr",
    "'Người dùng StayHub'": "'sc_sds_stayhub_user'.tr",
    "'Thành viên StayHub'": "'sc_sds_stayhub_member'.tr",
    "'Đã là bạn bè'": "'sc_sds_already_friends'.tr",
    "'Đã gửi lời mời'": "'sc_sds_request_sent'.tr",
    "'Chưa cập nhật'": "'sc_sds_not_updated'.tr",
    "'Thông tin cá nhân'": "'sc_sds_personal_info'.tr",
    "'Họ và tên'": "'sc_sds_full_name'.tr",
    "'Giới tính'": "'sc_sds_gender'.tr",
    "'Ngày sinh'": "'sc_sds_dob'.tr",
    "'Tham gia từ'": "'sc_sds_joined_since'.tr",
    "'Xem tất cả bình luận'": "'sc_sds_view_all_comments'.tr",
    
    // Interpolated string replacements
    "'📍 Vị trí hiện tại của tôi: ": "'sc_sds_live_location_prefix'.tr + '",
    "'Không gửi được tin nhắn. \${e.toString()}'": "'sc_sds_failed_send_message_prefix'.tr + e.toString()",
    "• \$days ngày'": "• \$days ' + 'sc_sds_days'.tr",
    "'\$days ngày'": "days.toString() + 'sc_sds_days'.tr",
    "'\${moment.reactionCount} lượt thích'": "moment.reactionCount.toString() + ' ' + 'sc_sds_likes'.tr",
  };
  
  for (final entry in replaceMap.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }

  // Handle some const removal to avoid const_eval_extension_method
  text = text.replaceAll("const Text('sc_sds_", "Text('sc_sds_");
  text = text.replaceAll("const LoadingWidget(message: 'sc_sds_connecting_chat'.tr)", "LoadingWidget(message: 'sc_sds_connecting_chat'.tr)");
  text = text.replaceAll("const LoadingWidget(message: 'sc_sds_loading_posts'.tr)", "LoadingWidget(message: 'sc_sds_loading_posts'.tr)");

  file.writeAsStringSync(text);
  print('Done translating social_detail_screens.dart.');
}
