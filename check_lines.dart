import 'dart:io';

void main() {
  final file = File('lib/screens/customer/social_detail_screens.dart');
  final lines = file.readAsLinesSync();
  final targetLines = [368, 557, 713, 742, 1010, 1983, 2011, 2263, 2364, 2838];
  
  for (var target in targetLines) {
    print('--- Around line $target ---');
    for (var i = target - 3; i <= target + 1; i++) {
      if (i >= 0 && i < lines.length) {
        print('$i: ${lines[i - 1]}');
      }
    }
  }
}
