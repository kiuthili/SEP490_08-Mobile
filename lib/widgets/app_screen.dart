import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/platform_ui.dart';
import 'page_scaffold.dart';

/// Scaffold chuẩn cho màn push — nền gradient + AppBar trong suốt.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.bottomBar,
    this.floatingActionButton,
    this.centerTitle = true,
    this.leading,
    this.extendBody = false,
  });

  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool centerTitle;
  final Widget? leading;
  final bool extendBody;

  static EdgeInsets scrollPadding(BuildContext context) {
    return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  }

  @override
  Widget build(BuildContext context) {
    final hasBar =
        title != null || (actions != null && actions!.isNotEmpty) || bottom != null;

    return PageScaffold(
      extendBody: extendBody,
      appBar: hasBar
          ? AppBar(
              title: title != null
                  ? Text(
                      title!,
                      style: AppTextStyles.textTheme.titleLarge,
                    )
                  : null,
              centerTitle: centerTitle,
              actions: actions,
              bottom: bottom,
              leading: leading,
            )
          : null,
      bottomNavigationBar:
          bottomBar != null ? IosStickyBottomBar(child: bottomBar!) : null,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

/// Thanh CTA / action dính dưới — glass blur.
class IosStickyBottomBar extends StatelessWidget {
  const IosStickyBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    final bar = Container(
      padding: const EdgeInsets.all(16),
      decoration: useGlassBlur
          ? AppDecorations.glass(opacity: 0.9, radius: AppRadius.card)
          : AppDecorations.card(color: AppColors.surface),
      child: child,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom > 0 ? bottom : 16),
      child: useGlassBlur
          ? ClipRRect(
              borderRadius: AppRadius.card,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: bar,
              ),
            )
          : bar,
    );
  }
}
