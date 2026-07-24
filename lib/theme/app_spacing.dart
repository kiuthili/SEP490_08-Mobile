import 'package:flutter/material.dart';

/// Chuẩn hóa các giá trị khoảng cách (padding/margin) trong ứng dụng.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets edgeInsetsAllXs = EdgeInsets.all(xs);
  static const EdgeInsets edgeInsetsAllSm = EdgeInsets.all(sm);
  static const EdgeInsets edgeInsetsAllMd = EdgeInsets.all(md);
  static const EdgeInsets edgeInsetsAllLg = EdgeInsets.all(lg);
  static const EdgeInsets edgeInsetsAllXl = EdgeInsets.all(xl);

  static const EdgeInsets edgeInsetsHmd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets edgeInsetsHsm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets edgeInsetsVmd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets edgeInsetsVsm = EdgeInsets.symmetric(vertical: sm);
}
