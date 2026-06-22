import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Ô nhập liệu chuẩn StayHub — có label, icon, validation inline, ẩn/hiện mật khẩu.
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLength;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLength,
    this.maxLines = 1,
    this.inputFormatters,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final isMultiline = !widget.obscureText && widget.maxLines > 1;
    Widget? suffix = widget.suffixIcon;
    if (widget.obscureText) {
      suffix = IconButton(
        icon: Icon(
          _obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: AppTextStyles.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          enabled: widget.enabled,
          maxLength: widget.maxLength,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          inputFormatters: widget.inputFormatters,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          textAlignVertical:
              isMultiline ? TextAlignVertical.top : TextAlignVertical.center,
          style: AppTextStyles.textTheme.bodyLarge,
          cursorColor: AppColors.brand,
          decoration: InputDecoration(
            hintText: widget.hint ?? widget.label,
            counterText: '',
            prefixIcon: widget.prefixIcon != null
                ? Align(
                    alignment: isMultiline
                        ? Alignment.topCenter
                        : Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(top: isMultiline ? 16 : 0),
                      child: Icon(widget.prefixIcon, size: 20),
                    ),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              maxWidth: 48,
              minHeight: 48,
            ),
            prefixIconColor: AppColors.textSecondary,
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: const OutlineInputBorder(
              borderRadius: AppRadius.input,
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.input,
              borderSide: BorderSide(color: AppColors.separator),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.input,
              borderSide: BorderSide(color: AppColors.brand, width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.input,
              borderSide: BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.input,
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
