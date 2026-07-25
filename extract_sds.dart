import 'dart:io';

void main() {
  final file = File('lib/screens/customer/social_detail_screens.dart');
  final lines = file.readAsLinesSync();
  final viRegex = RegExp(r"'(.*?[^\x00-\x7F].*?)'");
  
  final matches = <String>{};
  for (var line in lines) {
    for (var match in viRegex.allMatches(line)) {
      if (match.group(1) != null) {
        matches.add(match.group(1)!);
      }
    }
  }
  
  var idx = 0;
  for (var m in matches) {
    if (m.contains('\$')) continue; // skip interpolated strings for manual handling
    print("'$m': 'sc_sds_${idx}',");
    idx++;
  }
}
