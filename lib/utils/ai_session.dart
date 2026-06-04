import 'dart:math';
import 'package:get_storage/get_storage.dart';

const _key = 'ai_session_id';

/// Session ID cho AI tour-assistant (giống web localStorage).
String getOrCreateAiSessionId() {
  final box = GetStorage();
  final existing = box.read<String>(_key);
  if (existing != null && existing.isNotEmpty) return existing;
  final id =
      'mob-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
  box.write(_key, id);
  return id;
}
