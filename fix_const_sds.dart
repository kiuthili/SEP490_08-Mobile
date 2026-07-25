import 'dart:io';

void main() {
  final file = File('lib/screens/customer/social_detail_screens.dart');
  var text = file.readAsStringSync();
  
  // Fix const_eval_extension_method errors by removing 'const ' before 'Text('
  text = text.replaceAll("const Text('sc_sds_", "Text('sc_sds_");
  
  // Specific lines based on flutter analyze
  // line 368: Text('Rời nhóm') -> Text('sc_sds_leave_group'.tr)
  text = text.replaceAll("const Text('sc_sds_leave_group'.tr)", "Text('sc_sds_leave_group'.tr)");
  
  // line 557: Text('NHÓM TOUR')
  text = text.replaceAll("const Text('sc_sds_tour_group_caps'.tr", "Text('sc_sds_tour_group_caps'.tr");

  // line 713: Text('Đang tải thông tin lịch...')
  text = text.replaceAll("const Text('sc_sds_loading_schedule'.tr", "Text('sc_sds_loading_schedule'.tr");

  // line 742: Text('Thử lại')
  text = text.replaceAll("const Text('sc_sds_retry'.tr", "Text('sc_sds_retry'.tr");

  // line 1010: Text('KHOẢNH KHẮC')
  text = text.replaceAll("const Text('sc_sds_moment_caps'.tr", "Text('sc_sds_moment_caps'.tr");

  // line 1983: Text('Bạn bè')
  text = text.replaceAll("const Text('sc_sds_friends'.tr", "Text('sc_sds_friends'.tr");

  // line 2011: Text('Bài viết')
  text = text.replaceAll("const Text('sc_sds_posts'.tr", "Text('sc_sds_posts'.tr");

  // line 2263: Text('Chưa cập nhật')
  text = text.replaceAll("const Text('sc_sds_not_updated'.tr", "Text('sc_sds_not_updated'.tr");

  // line 2364: Text('Hồ sơ')
  text = text.replaceAll("const Text('sc_sds_profile'.tr", "Text('sc_sds_profile'.tr");

  // line 2838: Text('Bài viết')
  text = text.replaceAll("const Text('sc_sds_posts'.tr", "Text('sc_sds_posts'.tr");

  // Fix unused elements issue
  // Wait, I might have messed up a variable or method call when replacing.
  // Let's not touch the unused methods for now unless they cause a real compile error. 
  // It's just a warning.
  // Actually, I should remove 'const' from `const [ ... ]` arrays that contain Text widgets with .tr
  text = text.replaceAll("const [\n                    Icon(Icons.logout_rounded", "[\n                    Icon(Icons.logout_rounded");
  
  // line 1983 is inside a TabBar probably
  text = text.replaceAll("const [\n                      Tab(text: 'sc_sds_posts'.tr),", "[\n                      Tab(text: 'sc_sds_posts'.tr),");
  text = text.replaceAll("const [\n                      Tab(text: 'sc_sds_friends'.tr),", "[\n                      Tab(text: 'sc_sds_friends'.tr),");

  file.writeAsStringSync(text);
  print('Done fixing const in social_detail_screens.dart.');
}
