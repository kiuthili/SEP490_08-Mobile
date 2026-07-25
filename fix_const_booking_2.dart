import 'dart:io';

void main() {
  final file = File('lib/screens/customer/booking_screen.dart');
  final lines = file.readAsLinesSync();
  
  final targetLines = [717, 1377, 1675, 1679];
  
  for (var t in targetLines) {
    for (var i = t - 3; i <= t; i++) {
      if (i >= 0 && i < lines.length) {
        lines[i] = lines[i].replaceAll(RegExp(r'\bconst\s+'), '');
      }
    }
  }
  
  file.writeAsStringSync(lines.join('\n'));
  print('Done second pass fixing const in booking_screen.dart.');
}
