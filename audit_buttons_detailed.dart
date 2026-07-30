import 'dart:io';

void main() {
  final dir = Directory('lib/screens');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  print('# Button Audit Report');
  print('');
  print('| Screen Path | Button Widget Type | Current Border Radius | Matches Tour Detail? | Needs Updating? |');
  print('|---|---|---|---|---|');

  int totalScreens = 0;
  int screensWithButtons = 0;
  int screensNeedingUpdate = 0;

  for (final file in files) {
    totalScreens++;
    final content = file.readAsStringSync();
    
    bool hasButton = false;
    bool needsUpdateForThisScreen = false;
    
    // Check specific widgets
    final widgets = [
      'ElevatedButton', 'FilledButton', 'OutlinedButton', 'TextButton', 
      'IconButton', 'InkWell', 'CustomButton'
    ];
    
    for (final widget in widgets) {
      if (content.contains(widget)) {
        hasButton = true;
        
        bool matches = true;
        String radius = 'AppRadius.button (Theme)';
        
        // If it's a standard button, check if it overrides shape
        if (['ElevatedButton', 'FilledButton', 'OutlinedButton', 'TextButton'].contains(widget)) {
          if (content.contains(RegExp(widget + r'\.styleFrom\([^)]*shape:'))) {
             if (content.contains(RegExp(widget + r'\.styleFrom\([^)]*shape:[^)]*AppRadius\.button'))) {
                radius = 'AppRadius.button (Explicit)';
             } else if (content.contains(RegExp(widget + r'\.styleFrom\([^)]*shape:[^)]*AppRadius\.xs'))) {
                radius = 'AppRadius.xs (Explicit)';
             } else {
                radius = 'Custom Override';
                matches = false;
             }
          }
        } else if (widget == 'IconButton') {
           if (content.contains(RegExp(r'IconButton\.styleFrom\([^)]*shape:'))) {
               if (!content.contains(RegExp(r'IconButton\.styleFrom\([^)]*shape:[^)]*AppRadius\.button')) &&
                   !content.contains(RegExp(r'IconButton\.styleFrom\([^)]*shape:[^)]*AppRadius\.xs'))) {
                   radius = 'Custom Override';
                   matches = false;
               } else {
                   radius = 'AppRadius.button';
               }
           } else {
               // IconButton has a circular default shape. If no shape is provided, it's NOT matching Tour Detail (which is xs)
               radius = 'Default Circular';
               matches = false;
           }
        } else if (widget == 'InkWell') {
           // InkWell usually needs borderRadius
           if (content.contains(RegExp(r'InkWell\([^)]*borderRadius:\s*AppRadius\.button'))) {
               radius = 'AppRadius.button';
           } else if (content.contains(RegExp(r'InkWell\([^)]*borderRadius:\s*BorderRadius\.circular\(AppRadius\.xs\)'))) {
               radius = 'AppRadius.xs';
           } else if (content.contains(RegExp(r'InkWell\([^)]*borderRadius:'))) {
               radius = 'Custom Override';
               matches = false;
           } else {
               radius = 'None (Square)';
               matches = false;
           }
        } else if (widget == 'CustomButton') {
           radius = 'AppRadius.button';
           matches = true;
        }

        if (!matches) needsUpdateForThisScreen = true;
        
        print('| ${file.path.replaceAll('\\', '/')} | $widget | $radius | $matches | ${!matches} |');
      }
    }
    
    // Check GestureDetector separately if it acts as a button (has onTap)
    if (content.contains(RegExp(r'GestureDetector\([^)]*onTap:'))) {
        hasButton = true;
        // Hard to parse perfectly, but let's assume if it doesn't wrap a ClipRRect with AppRadius.button, it might need updating
        // We'll mark it as manual review
        print('| ${file.path.replaceAll('\\', '/')} | GestureDetector (with onTap) | Unknown | Unknown | Manual Review |');
        needsUpdateForThisScreen = true; // Force manual review
    }

    if (hasButton) screensWithButtons++;
    if (needsUpdateForThisScreen) screensNeedingUpdate++;
  }
  
  print('\nTotal screens scanned: $totalScreens');
  print('Total screens containing buttons: $screensWithButtons');
  print('Total screens to update (approx): $screensNeedingUpdate');
}
