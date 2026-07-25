import 'dart:io';

void main() {
  final tmFile = File('lib/models/tour_model.dart');
  var tmText = tmFile.readAsStringSync();
  if (!tmText.contains("package:get/get.dart")) {
    tmText = "import 'package:get/get.dart';\n" + tmText;
    tmFile.writeAsStringSync(tmText);
  }
  
  final fcFile = File('lib/controllers/feature_controllers.dart');
  var fcText = fcFile.readAsStringSync();
  if (!fcText.contains("package:get/get.dart")) {
    fcText = "import 'package:get/get.dart';\n" + fcText;
    fcFile.writeAsStringSync(fcText);
  }
  print('Done adding GetX imports.');
}
