import 'dart:io';

void main() {
  final dir = Directory('lib/screens');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    String content = file.readAsStringSync();
    String original = content;

    // 1. Remove explicit shapes from ElevatedButton, FilledButton, OutlinedButton, TextButton
    // We match shape: RoundedRectangleBorder(...)
    final shapeRegex1 = RegExp(r'shape:\s*RoundedRectangleBorder\([^)]*\),?');
    final shapeRegex2 = RegExp(r'shape:\s*const\s*RoundedRectangleBorder\([^)]*\),?');
    
    // For specific radius variables like AppRadius.xs
    final shapeRegex3 = RegExp(r'shape:\s*[^,]*AppRadius\.(xs|sm|md|lg|button)[^,]*,?');

    content = content.replaceAll(shapeRegex1, '');
    content = content.replaceAll(shapeRegex2, '');
    content = content.replaceAll(shapeRegex3, '');

    // 2. Inject AppRadius.button into InkWell
    // Replace InkWell( with InkWell(borderRadius: AppRadius.button, 
    content = content.replaceAll('InkWell(', 'InkWell(borderRadius: AppRadius.button, ');

    // Now we might have duplicate borderRadius in InkWell, e.g. 
    // InkWell(borderRadius: AppRadius.button, borderRadius: BorderRadius.circular(10))
    // Or InkWell(borderRadius: AppRadius.button, ... borderRadius: AppRadius.xs)
    // We will clean up the old borderRadius: ... by removing it.
    // We want to remove the SECOND borderRadius if it exists.
    // Since regex across multiple lines is tricky, we'll do this:
    // First, temporarily change our injected one to a unique string:
    content = content.replaceAll('InkWell(borderRadius: AppRadius.button, ', '@@@INKWELL@@@');
    
    // Now any remaining borderRadius inside InkWell needs to be removed.
    // Actually, this is getting complicated because borderRadius could be anywhere.
    // Let's do something simpler: replace known borderRadius patterns in the file
    content = content.replaceAll(RegExp(r'borderRadius:\s*BorderRadius\.circular\([^)]*\),?'), '');
    content = content.replaceAll(RegExp(r'borderRadius:\s*AppRadius\.(xs|sm|md|lg|button|pill),?'), '');

    // Restore the injected InkWell
    content = content.replaceAll('@@@INKWELL@@@', 'InkWell(borderRadius: AppRadius.button, ');

    // 3. Make sure AppRadius is imported if we injected AppRadius.button
    if (content.contains('AppRadius.button') && !content.contains('app_radius.dart')) {
       // Find the last import and insert after it
       final importIndex = content.lastIndexOf(RegExp(r'import\s+[^;]+;'));
       if (importIndex != -1) {
          final insertIndex = content.indexOf('\n', importIndex) + 1;
          content = content.substring(0, insertIndex) + "import 'package:stayhub_mobile/theme/app_radius.dart';\n" + content.substring(insertIndex);
       }
    }

    if (content != original) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
