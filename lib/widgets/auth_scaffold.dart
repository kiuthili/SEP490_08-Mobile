import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'stayhub_logo.dart';

class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.child,
    this.footer,
    this.showBack = false,
    this.scrollable = true,
    this.heroInitiallyExpanded = true,
  });

  final String title;
  final String subtitle;
  final String heroTitle;
  final String heroSubtitle;
  final Widget child;
  final Widget? footer;
  final bool showBack;
  final bool scrollable;
  final bool heroInitiallyExpanded;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold> {
  late bool _heroExpanded;

  @override
  void initState() {
    super.initState();
    _heroExpanded = widget.heroInitiallyExpanded;
  }

  void _toggleHero() {
    setState(() => _heroExpanded = !_heroExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              24,
              topInset + 20,
              24,
              _heroExpanded ? 36 : 28,
            ),
            decoration: const BoxDecoration(
              gradient: AppColors.authHeroGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.showBack)
                      _GlassIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: Get.back,
                      ),
                    if (widget.showBack) const SizedBox(width: 12),
                    const StayHubLogo(theme: StayHubLogoTheme.light),
                    const Spacer(),
                    _GlassIconButton(
                      icon: _heroExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      onTap: _toggleHero,
                      tooltip: _heroExpanded
                          ? 'Thu gọn phần giới thiệu'
                          : 'Mở rộng phần giới thiệu',
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _heroExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 28),
                            Text(
                              widget.heroTitle,
                              style: AppTextStyles.textTheme.headlineMedium
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.heroSubtitle,
                              style:
                                  AppTextStyles.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.scrollable
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: _FormCard(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      footer: widget.footer,
                      child: widget.child,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: _FormCard(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      footer: widget.footer,
                      child: widget.child,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.15),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -28),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: AppDecorations.card(),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: AppTextStyles.textTheme.headlineMedium?.copyWith(
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: AppTextStyles.textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                child,
                if (footer != null) ...[
                  const SizedBox(height: 20),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
