import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final bool compact;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact ? 44.0 : 52.0;
    final disabled = isLoading || onPressed == null;

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: disabled ? null : onPressed,
          child: _label(AppColors.brand),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: AppRadius.button,
          child: Ink(
            decoration: BoxDecoration(
              gradient: disabled ? null : AppColors.brandGradient,
              color: disabled
                  ? AppColors.brand.withValues(alpha: 0.4)
                  : null,
              borderRadius: AppRadius.button,
              boxShadow: disabled ? null : AppShadows.soft,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : _label(Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(Color color) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: color,
        letterSpacing: -0.2,
      ),
    );
  }
}
