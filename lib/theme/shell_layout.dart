import 'package:flutter/material.dart';

/// Khoảng trống phía dưới nội dung tab khi dùng [IosBottomNav] nổi.
class ShellLayout {
  ShellLayout._();

  static double bottomInset(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return 88 + (safe > 0 ? safe : 16);
  }

  static EdgeInsets listPadding(BuildContext context) {
    return EdgeInsets.only(bottom: bottomInset(context));
  }
}
