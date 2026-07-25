import 'dart:io';

void main() {
  final file = File('lib/screens/customer/social_detail_screens.dart');
  var text = file.readAsStringSync();
  
  // Line 361
  text = text.replaceAll("itemBuilder: (_) => const [", "itemBuilder: (_) => [");
  
  // Line 740
  text = text.replaceAll("child: const Padding(", "child: Padding(");
  
  // Line 1009
  text = text.replaceAll("child: const Text(\n                      'sc_sds_view_location'.tr,", "child: Text(\n                      'sc_sds_view_location'.tr,");
  
  // Line 1983
  text = text.replaceAll("? const Center(child: Text('sc_sds_not_found'.tr))", "? Center(child: Text('sc_sds_not_found'.tr))");

  // Line 2837
  text = text.replaceAll("title: const Text(\n          'sc_sds_posts'.tr,", "title: Text(\n          'sc_sds_posts'.tr,");

  // For the Rows/Columns/Slivers, I need to look closely. Let's just remove "const " globally where it precedes Row, Column, Padding, SliverFillRemaining if it contains .tr
  // But that's risky. Let's just strip 'const ' from these specific ones using regex.
  // We can just find the exact text using regex for these specific strings:
  text = text.replaceAll(RegExp(r"const Row\(\s*mainAxisSize: MainAxisSize\.min,\s*children: \[\n\s*Icon\(Icons\.groups_2_rounded"), "Row(\n                                mainAxisSize: MainAxisSize.min,\n                                children: [\n                                  Icon(Icons.groups_2_rounded");
  
  text = text.replaceAll("const Row(\n        mainAxisAlignment: MainAxisAlignment.center,\n        children: [\n          SizedBox(\n            width: 14,\n            height: 14,", "Row(\n        mainAxisAlignment: MainAxisAlignment.center,\n        children: [\n          SizedBox(\n            width: 14,\n            height: 14,");

  text = text.replaceAll("const SliverFillRemaining(\n                        hasScrollBody: false,\n                        child: Padding(\n                          padding: EdgeInsets.all(60),\n                          child:\n                              LoadingWidget(message: 'sc_sds_loading_posts'.tr),", "SliverFillRemaining(\n                        hasScrollBody: false,\n                        child: Padding(\n                          padding: EdgeInsets.all(60),\n                          child:\n                              LoadingWidget(message: 'sc_sds_loading_posts'.tr),");
  
  text = text.replaceAll("const Row(\n                    mainAxisSize: MainAxisSize.min,\n                    children: [\n                      Icon(Icons.chat_bubble_outline_rounded,\n                          size: 15, color: AppColors.textPrimary),\n                      SizedBox(width: 6),\n                      Text(\n                        'sc_sds_message_action'.tr,", "Row(\n                    mainAxisSize: MainAxisSize.min,\n                    children: [\n                      Icon(Icons.chat_bubble_outline_rounded,\n                          size: 15, color: AppColors.textPrimary),\n                      SizedBox(width: 6),\n                      Text(\n                        'sc_sds_message_action'.tr,");
  
  text = text.replaceAll("const Column(\n        mainAxisAlignment: MainAxisAlignment.center,\n        children: [\n          Icon(Icons.photo_library_outlined,\n            size: 56, color: AppColors.textTertiary),\n        SizedBox(height: 16),\n        Text(\n          'sc_sds_no_posts_yet'.tr,", "Column(\n        mainAxisAlignment: MainAxisAlignment.center,\n        children: [\n          Icon(Icons.photo_library_outlined,\n            size: 56, color: AppColors.textTertiary),\n        SizedBox(height: 16),\n        Text(\n          'sc_sds_no_posts_yet'.tr,");
  
  // Just in case, replace generic const Row/Column that contain .tr
  // Not going to risk regex, I'll run sed.

  file.writeAsStringSync(text);
  print('Done second pass fix const in social_detail_screens.dart.');
}
