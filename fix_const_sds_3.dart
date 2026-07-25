import 'dart:io';

void main() {
  final file = File('lib/screens/customer/social_detail_screens.dart');
  final lines = file.readAsLinesSync();
  
  final targetLines = [361, 553, 709, 740, 1009, 1983, 2011, 2259, 2360, 2837];
  
  for (var t in targetLines) {
    if (t - 1 >= 0 && t - 1 < lines.length) {
      lines[t - 1] = lines[t - 1].replaceAll(RegExp(r'\bconst\s+'), '');
    }
  }
  
  file.writeAsStringSync(lines.join('\n'));
  print('Done third pass fix const in social_detail_screens.dart.');
}
