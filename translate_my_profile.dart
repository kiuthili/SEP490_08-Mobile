import 'dart:io';

void main() {
  final keys = {
    'sc_mp_err_load_moments': 'Cannot load moments data',
    'sc_mp_not_logged_in': 'Not logged in',
    'sc_mp_loading_moments': 'Loading moments...',
    'sc_mp_posts': 'Posts',
    'sc_mp_friends': 'Friends',
    'sc_mp_stayhub_user': 'StayHub User',
    'sc_mp_edit_profile': 'Edit profile',
    'sc_mp_empty_posts_title': 'No posts yet',
    'sc_mp_empty_posts_desc': 'When you share photos, they will appear on your profile.',
    'sc_mp_share_first': 'Share your first photo',
    'sc_mp_likes_count': '@count likes',
    'sc_mp_view_all_comments': 'View all comments',
    'sc_mp_delete_post': 'Delete post',
    'sc_mp_cancel': 'Cancel',
  };

  final keysVi = {
    'sc_mp_err_load_moments': 'Không thể tải dữ liệu khoảnh khắc',
    'sc_mp_not_logged_in': 'Chưa đăng nhập',
    'sc_mp_loading_moments': 'Đang tải khoảnh khắc...',
    'sc_mp_posts': 'Bài viết',
    'sc_mp_friends': 'Bạn bè',
    'sc_mp_stayhub_user': 'StayHub User',
    'sc_mp_edit_profile': 'Chỉnh sửa hồ sơ',
    'sc_mp_empty_posts_title': 'Chưa có bài viết nào',
    'sc_mp_empty_posts_desc': 'Khi bạn chia sẻ ảnh, chúng\\nsẽ hiển thị trên trang cá nhân.',
    'sc_mp_share_first': 'Chia sẻ ảnh đầu tiên',
    'sc_mp_likes_count': '@count lượt thích',
    'sc_mp_view_all_comments': 'Xem tất cả bình luận',
    'sc_mp_delete_post': 'Xóa bài viết',
    'sc_mp_cancel': 'Hủy',
  };

  final transFile = File('lib/utils/app_translations.dart');
  var trans = transFile.readAsStringSync();
  
  final enStr = keys.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Log out'", "          'pt_logout': 'Log out',\n$enStr");

  final viStr = keysVi.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Đăng xuất'", "          'pt_logout': 'Đăng xuất',\n$viStr");
  
  transFile.writeAsStringSync(trans);
  
  final panelFile = File('lib/screens/customer/my_profile_panel.dart');
  var panelText = panelFile.readAsStringSync();
  
  final replaceMap = {
    "'Không thể tải dữ liệu khoảnh khắc'": "'sc_mp_err_load_moments'.tr",
    "'Chưa đăng nhập'": "'sc_mp_not_logged_in'.tr",
    "'Đang tải khoảnh khắc...'": "'sc_mp_loading_moments'.tr",
    "'Bài viết'": "'sc_mp_posts'.tr",
    "'Bạn bè'": "'sc_mp_friends'.tr",
    "'StayHub User'": "'sc_mp_stayhub_user'.tr",
    "'Chỉnh sửa hồ sơ'": "'sc_mp_edit_profile'.tr",
    "'Chưa có bài viết nào'": "'sc_mp_empty_posts_title'.tr",
    "'Khi bạn chia sẻ ảnh, chúng\\nsẽ hiển thị trên trang cá nhân.'": "'sc_mp_empty_posts_desc'.tr",
    "'Chia sẻ ảnh đầu tiên'": "'sc_mp_share_first'.tr",
    "'\${moment.reactionCount} lượt thích'": "'sc_mp_likes_count'.trParams({'count': moment.reactionCount.toString()})",
    "'Xem tất cả bình luận'": "'sc_mp_view_all_comments'.tr",
    "'Xóa bài viết'": "'sc_mp_delete_post'.tr",
    "'Hủy'": "'sc_mp_cancel'.tr",
  };
  
  for (final entry in replaceMap.entries) {
    panelText = panelText.replaceAll(entry.key, entry.value);
  }

  // Remove `const ` for Widgets containing `.tr`
  panelText = panelText.replaceAll("const Center(child: Text('sc_mp_not_logged_in'.tr))", "Center(child: Text('sc_mp_not_logged_in'.tr))");
  panelText = panelText.replaceAll("const Text(\\n          'sc_mp_empty_posts_title'.tr,", "Text(\\n          'sc_mp_empty_posts_title'.tr,");
  panelText = panelText.replaceAll("const Text(\\n          'sc_mp_empty_posts_desc'.tr,", "Text(\\n          'sc_mp_empty_posts_desc'.tr,");
  panelText = panelText.replaceAll("const Text(\\n            'sc_mp_share_first'.tr,", "Text(\\n            'sc_mp_share_first'.tr,");
  panelText = panelText.replaceAll("const Text(\\n          'sc_mp_posts'.tr,", "Text(\\n          'sc_mp_posts'.tr,");
  panelText = panelText.replaceAll("const Text('sc_mp_delete_post'.tr", "Text('sc_mp_delete_post'.tr");
  panelText = panelText.replaceAll("const Text('sc_mp_cancel'.tr", "Text('sc_mp_cancel'.tr");
  panelText = panelText.replaceAll("const Text(\\n                  'sc_mp_edit_profile'.tr", "Text(\\n                  'sc_mp_edit_profile'.tr");
  
  panelFile.writeAsStringSync(panelText);
  print('Done translating my_profile_panel.dart.');
}
