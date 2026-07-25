import 'dart:io';

void main() {
  final enKeys = {
    'sc_bk_age_range': '@name (@min - @max years old)',
    'sc_bk_age_under': '@name (Under @max years old)',
    'sc_bk_age_over': '@name (@min years and older)',
    'sc_bk_age_range_lc': '@name (@min - @max years old)',
    'sc_bk_age_under_lc': '@name (under @max years old)',
    'sc_bk_age_over_lc': '@name (from @min years old)',
  };

  final viKeys = {
    'sc_bk_age_range': '@name (Từ @min - @max tuổi)',
    'sc_bk_age_under': '@name (Dưới @max tuổi)',
    'sc_bk_age_over': '@name (Từ @min tuổi trở lên)',
    'sc_bk_age_range_lc': '@name (@min - @max tuổi)',
    'sc_bk_age_under_lc': '@name (dưới @max tuổi)',
    'sc_bk_age_over_lc': '@name (từ @min tuổi)',
  };

  final transFile = File('lib/utils/app_translations.dart');
  var trans = transFile.readAsStringSync();
  
  final enStr = enKeys.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Log out'", "          'pt_logout': 'Log out',\n$enStr");

  final viStr = viKeys.entries.map((e) => "          '${e.key}': '${e.value}',").join('\n');
  trans = trans.replaceFirst("          'pt_logout': 'Đăng xuất'", "          'pt_logout': 'Đăng xuất',\n$viStr");
  
  transFile.writeAsStringSync(trans);
  
  // Replace in tour_model.dart
  final tmFile = File('lib/models/tour_model.dart');
  var tmText = tmFile.readAsStringSync();
  tmText = tmText.replaceAll("return '\$name (\$min - \$max tuổi)';", "return 'sc_bk_age_range_lc'.trParams({'name': name, 'min': min.toString(), 'max': max.toString()});");
  tmText = tmText.replaceAll("return '\$name (dưới \$max tuổi)';", "return 'sc_bk_age_under_lc'.trParams({'name': name, 'max': max.toString()});");
  tmText = tmText.replaceAll("return '\$name (từ \$min tuổi)';", "return 'sc_bk_age_over_lc'.trParams({'name': name, 'min': min.toString()});");
  tmFile.writeAsStringSync(tmText);
  
  // Replace in feature_controllers.dart
  final fcFile = File('lib/controllers/feature_controllers.dart');
  var fcText = fcFile.readAsStringSync();
  fcText = fcText.replaceAll("formattedName = '\$name (Từ \$min - \$max tuổi)';", "formattedName = 'sc_bk_age_range'.trParams({'name': name, 'min': min.toString(), 'max': max.toString()});");
  fcText = fcText.replaceAll("formattedName = '\$name (Dưới \$max tuổi)';", "formattedName = 'sc_bk_age_under'.trParams({'name': name, 'max': max.toString()});");
  fcText = fcText.replaceAll("formattedName = '\$name (Từ \$min tuổi trở lên)';", "formattedName = 'sc_bk_age_over'.trParams({'name': name, 'min': min.toString()});");
  fcFile.writeAsStringSync(fcText);
  
  print('Done fixing age translations.');
}
