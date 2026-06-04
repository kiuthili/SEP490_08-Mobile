/// Parse tour id từ Get.arguments (int, num, String, hoặc Map).
int? parseTourId(dynamic arguments) {
  if (arguments == null) return null;
  if (arguments is int) return arguments;
  if (arguments is num) return arguments.toInt();
  if (arguments is String) return int.tryParse(arguments);
  if (arguments is Map) {
    final id = arguments['id'] ?? arguments['tourId'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    if (id is String) return int.tryParse(id);
  }
  return null;
}
