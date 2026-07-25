import 'dart:io';

void main() {
  final keys = {
    'sc_nm_title': 'New message',
    'sc_nm_search_hint': 'Search friends by name or email...',
    'sc_nm_loading': 'Loading friends list...',
    'sc_nm_empty_friends_title': 'No friends yet',
    'sc_nm_empty_friends_desc': 'Add friends first to send direct messages',
    'sc_nm_empty_search_title': 'No friends found',
    'sc_nm_empty_search_desc': 'Try searching with different keywords',
    'sc_nm_stayhub_friend': 'Friend on StayHub',
  };

  final keysVi = {
    'sc_nm_title': 'Tin nhắn mới',
    'sc_nm_search_hint': 'Tìm kiếm bạn bè theo tên hoặc email...',
    'sc_nm_loading': 'Đang tải danh sách bạn bè...',
    'sc_nm_empty_friends_title': 'Chưa có bạn bè',
    'sc_nm_empty_friends_desc': 'Kết bạn trước để gửi tin nhắn riêng',
    'sc_nm_empty_search_title': 'Không tìm thấy bạn bè',
    'sc_nm_empty_search_desc': 'Thử tìm kiếm với từ khóa khác',
    'sc_nm_stayhub_friend': 'Bạn bè trên StayHub',
  };

  final transFile = File('lib/utils/app_translations.dart');
  var trans = transFile.readAsStringSync();
  
  final enStr = keys.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Log out'", "          'pt_logout': 'Log out',\n$enStr");

  final viStr = keysVi.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Đăng xuất'", "          'pt_logout': 'Đăng xuất',\n$viStr");
  
  transFile.writeAsStringSync(trans);
  
  final panelFile = File('lib/screens/customer/new_message_screen.dart');
  var panelText = panelFile.readAsStringSync();
  
  final replaceMap = {
    "'Tin nhắn mới'": "'sc_nm_title'.tr",
    "'Tìm kiếm bạn bè theo tên hoặc email...'": "'sc_nm_search_hint'.tr",
    "'Đang tải danh sách bạn bè...'": "'sc_nm_loading'.tr",
    "'Chưa có bạn bè'": "'sc_nm_empty_friends_title'.tr",
    "'Kết bạn trước để gửi tin nhắn riêng'": "'sc_nm_empty_friends_desc'.tr",
    "'Không tìm thấy bạn bè'": "'sc_nm_empty_search_title'.tr",
    "'Thử tìm kiếm với từ khóa khác'": "'sc_nm_empty_search_desc'.tr",
    "'Bạn bè trên StayHub'": "'sc_nm_stayhub_friend'.tr",
  };
  
  for (final entry in replaceMap.entries) {
    panelText = panelText.replaceAll(entry.key, entry.value);
  }

  // Remove `const` that might cause `const_eval_extension_method`
  panelText = panelText.replaceAll("const LoadingWidget(", "LoadingWidget(");
  panelText = panelText.replaceAll("const EmptyStateWidget(", "EmptyStateWidget(");

  panelFile.writeAsStringSync(panelText);
  print('Done translating new_message_screen.dart.');
}
