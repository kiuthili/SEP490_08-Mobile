import 'dart:io';

void main() {
  final file = File('lib/screens/customer/booking_screen.dart');
  final lines = file.readAsLinesSync();
  
  final targetLines = [311, 329, 379, 414, 717, 786, 825, 900, 916, 963, 971, 1056, 1377, 1653, 1675, 1679, 1698, 1763];
  
  for (var t in targetLines) {
    for (var i = t - 3; i <= t; i++) {
      if (i >= 0 && i < lines.length) {
        lines[i] = lines[i].replaceAll(RegExp(r'\bconst\s+'), '');
      }
    }
  }
  
  file.writeAsStringSync(lines.join('\n'));
  print('Done fixing const in booking_screen.dart.');
}
