import 'dart:io';

void main() {
  final dir = Directory('lib/screens');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  final buttonTypes = [
    'ElevatedButton',
    'FilledButton',
    'OutlinedButton',
    'TextButton',
    'IconButton',
    'InkWell',
    'GestureDetector',
    'CustomButton',
  ];

  print('# Button Audit Report');
  print('');
  print('| Screen Path | Button Widget Type | Current Border Radius | Matches Tour Detail? | Needs Updating? |');
  print('|---|---|---|---|---|');

  int totalScreens = 0;
  int screensWithButtons = 0;

  for (final file in files) {
    totalScreens++;
    final content = file.readAsStringSync();
    
    bool hasButton = false;
    
    for (final type in buttonTypes) {
      if (content.contains(type)) {
        hasButton = true;
        
        String radius = 'Unknown';
        bool matches = false;
        
        // Very basic heuristics
        if (content.contains('BorderRadius.circular(AppRadius.xs)') || content.contains('AppRadius.button')) {
            matches = true;
            radius = 'AppRadius.xs / AppRadius.button';
        }
        
        print('| ${file.path.replaceAll('\\', '/')} | $type | $radius | $matches | ${!matches} |');
      }
    }
    
    if (hasButton) screensWithButtons++;
  }
  
  print('\nTotal screens scanned: $totalScreens');
  print('Screens with buttons: $screensWithButtons');
}
