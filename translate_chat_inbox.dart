import 'dart:io';

void main() {
  final keys = {
    'sc_ib_title': 'Messages',
    'sc_ib_new_message': 'New message',
    'sc_ib_loading_chats': 'Loading conversations...',
    'sc_ib_search': 'Search...',
    'sc_ib_tab_all': 'All',
    'sc_ib_tab_direct': 'Direct',
    'sc_ib_tab_group': 'Tour Groups',
    'sc_ib_empty_search_title': 'No conversations found',
    'sc_ib_empty_group_title': 'No tour groups yet',
    'sc_ib_empty_direct_title': 'No messages yet',
    'sc_ib_empty_group_desc': 'After paying for a tour, the itinerary group chat will appear here.',
    'sc_ib_empty_direct_desc': 'Tap the compose icon to chat with friends.',
    'sc_ib_retry': 'Refresh',
    'sc_ib_tour_group_id': 'Tour Group #@id',
    'sc_ib_chat_id': 'Conversation #@id',
    'sc_ib_tour_group_desc': 'Tour schedule group chat',
    'sc_ib_start_chat': 'Start a conversation',
  };

  final keysVi = {
    'sc_ib_title': 'Tin nhắn',
    'sc_ib_new_message': 'Tin nhắn mới',
    'sc_ib_loading_chats': 'Đang tải cuộc trò chuyện...',
    'sc_ib_search': 'Tìm kiếm...',
    'sc_ib_tab_all': 'Tất cả',
    'sc_ib_tab_direct': 'Tin nhắn riêng',
    'sc_ib_tab_group': 'Nhóm tour',
    'sc_ib_empty_search_title': 'Không tìm thấy cuộc trò chuyện',
    'sc_ib_empty_group_title': 'Chưa có nhóm tour',
    'sc_ib_empty_direct_title': 'Chưa có tin nhắn',
    'sc_ib_empty_group_desc': 'Sau khi thanh toán tour, nhóm chat lịch trình sẽ xuất hiện tại đây.',
    'sc_ib_empty_direct_desc': 'Nhấn biểu tượng soạn tin để trò chuyện với bạn bè.',
    'sc_ib_retry': 'Làm mới',
    'sc_ib_tour_group_id': 'Nhóm tour #@id',
    'sc_ib_chat_id': 'Cuộc trò chuyện #@id',
    'sc_ib_tour_group_desc': 'Nhóm trò chuyện theo lịch tour',
    'sc_ib_start_chat': 'Bắt đầu cuộc trò chuyện',
  };

  final transFile = File('lib/utils/app_translations.dart');
  var trans = transFile.readAsStringSync();
  
  final enStr = keys.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Log out'", "          'pt_logout': 'Log out',\n$enStr");

  final viStr = keysVi.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Đăng xuất'", "          'pt_logout': 'Đăng xuất',\n$viStr");
  
  transFile.writeAsStringSync(trans);
  
  final panelFile = File('lib/screens/customer/chat_inbox_screen.dart');
  var panelText = panelFile.readAsStringSync();
  
  final replaceMap = {
    "'Tin nhắn'": "'sc_ib_title'.tr",
    "'Tin nhắn mới'": "'sc_ib_new_message'.tr",
    "'Đang tải cuộc trò chuyện...'": "'sc_ib_loading_chats'.tr",
    "'Tìm kiếm...'": "'sc_ib_search'.tr",
    "'Tất cả'": "'sc_ib_tab_all'.tr",
    "'Tin nhắn riêng'": "'sc_ib_tab_direct'.tr",
    "'Nhóm tour'": "'sc_ib_tab_group'.tr",
    "'Không tìm thấy cuộc trò chuyện'": "'sc_ib_empty_search_title'.tr",
    "'Chưa có nhóm tour'": "'sc_ib_empty_group_title'.tr",
    "'Chưa có tin nhắn'": "'sc_ib_empty_direct_title'.tr",
    "'Sau khi thanh toán tour, nhóm chat lịch trình sẽ xuất hiện tại đây.'": "'sc_ib_empty_group_desc'.tr",
    "'Nhấn biểu tượng soạn tin để trò chuyện với bạn bè.'": "'sc_ib_empty_direct_desc'.tr",
    "'Làm mới'": "'sc_ib_retry'.tr",
    "'Nhóm tour #\${room.scheduleId ?? room.id}'": "'sc_ib_tour_group_id'.trParams({'id': (room.scheduleId ?? room.id).toString()})",
    "'Cuộc trò chuyện #\${room.id}'": "'sc_ib_chat_id'.trParams({'id': room.id.toString()})",
    "'Nhóm trò chuyện theo lịch tour'": "'sc_ib_tour_group_desc'.tr",
    "'Bắt đầu cuộc trò chuyện'": "'sc_ib_start_chat'.tr",
  };
  
  for (final entry in replaceMap.entries) {
    panelText = panelText.replaceAll(entry.key, entry.value);
  }

  // Remove `const` that might cause `const_eval_extension_method`
  panelText = panelText.replaceAll("const LoadingWidget(message: 'sc_ib_loading_chats'.tr)", "LoadingWidget(message: 'sc_ib_loading_chats'.tr)");
  panelText = panelText.replaceAll("const [\\n                    Tab(text: 'sc_ib_tab_all'.tr),", "[\\n                    Tab(text: 'sc_ib_tab_all'.tr),");

  panelFile.writeAsStringSync(panelText);
  print('Done translating chat_inbox_screen.dart.');
}
