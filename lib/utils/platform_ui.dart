import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Glass blur gây treo trên một số bản Linux/desktop — chỉ bật trên mobile.
bool get useGlassBlur {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS || Platform.isAndroid;
  } catch (_) {
    return false;
  }
}

/// Desktop dùng GestureDetector thay InkWell cho hàng danh sách (nhẹ hơn).
bool get useSimpleTap => !useGlassBlur;
