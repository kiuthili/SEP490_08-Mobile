import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Nền gradient nhẹ kiểu iOS cho các màn chính.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBody = false,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient:
            isDark ? AppColorsDark.pageGradient : AppColors.pageGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: extendBody,
        appBar: appBar,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        body: body,
      ),
    );
  }
}
